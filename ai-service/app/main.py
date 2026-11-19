"""DevBoard AI service — context-aware AI over Server-Sent Events."""

import json
import logging
import os
import time
from typing import Iterable

import httpx
from flask import Flask, Response, jsonify, request, stream_with_context
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
    Gauge,
    GCCollector,
    Histogram,
    PlatformCollector,
    ProcessCollector,
    generate_latest,
)

from .model import MODEL_NAME, check_model_runner, stream_chat

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [ai-service] %(levelname)s %(message)s",
)
log = logging.getLogger("ai-service")

app = Flask(__name__)

# The Go backend exposes GET /tasks?project_id=N -> {"tasks": [...]}.
TASK_SERVICE_URL = os.environ.get("TASK_SERVICE_URL", "http://backend:8080").rstrip("/")

# Use an explicit registry so the endpoint exposes both application metrics and
# Python process/runtime metrics. The default registry is intentionally not used.
registry = CollectorRegistry()
ProcessCollector(registry=registry)
PlatformCollector(registry=registry)
GCCollector(registry=registry)

http_requests_total = Counter(
    "ai_service_http_requests_total",
    "Total HTTP requests handled by the AI service (excluding metrics scrapes).",
    ["method", "route", "status"],
    registry=registry,
)
http_requests_in_flight = Gauge(
    "ai_service_http_requests_in_flight",
    "Current number of HTTP requests being handled by the AI service.",
    registry=registry,
)
http_request_duration = Histogram(
    "ai_service_http_request_duration_seconds",
    "Time spent handling an HTTP request, including streamed response delivery.",
    ["method", "route"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60, 120, 300),
    registry=registry,
)
ai_generations_total = Counter(
    "ai_service_generations_total",
    "Total AI generations completed, labelled by operation and outcome.",
    ["operation", "outcome"],
    registry=registry,
)
ai_generation_duration = Histogram(
    "ai_service_generation_duration_seconds",
    "Time spent receiving a complete streamed response from the model runner.",
    ["operation"],
    buckets=(1, 2.5, 5, 10, 20, 30, 60, 120, 180, 300),
    registry=registry,
)
ai_generation_errors_total = Counter(
    "ai_service_generation_errors_total",
    "AI generation failures, grouped by operation and bounded failure reason.",
    ["operation", "reason"],
    registry=registry,
)


class PrometheusWSGIMiddleware:
    """Observe the full WSGI response lifetime, including SSE body streaming."""

    def __init__(self, wsgi_app):
        self.wsgi_app = wsgi_app

    def __call__(self, environ, start_response):
        # Avoid measuring the scrape that is collecting these metrics.
        if environ.get("PATH_INFO") == "/metrics":
            return self.wsgi_app(environ, start_response)

        started = time.perf_counter()
        status_code = "500"
        http_requests_in_flight.inc()

        def capture_status(status, headers, exc_info=None):
            nonlocal status_code
            status_code = status.split(" ", 1)[0]
            return start_response(status, headers, exc_info)

        try:
            response_iterable = self.wsgi_app(environ, capture_status)
        except Exception:
            http_requests_in_flight.dec()
            raise

        def observe_response():
            try:
                yield from response_iterable
            finally:
                route = environ.get("devboard.route", "unmatched")
                method = environ.get("REQUEST_METHOD", "GET")
                http_requests_total.labels(method, route, status_code).inc()
                http_request_duration.labels(method, route).observe(
                    time.perf_counter() - started
                )
                http_requests_in_flight.dec()
                close = getattr(response_iterable, "close", None)
                if close is not None:
                    close()

        return observe_response()


app.wsgi_app = PrometheusWSGIMiddleware(app.wsgi_app)


@app.before_request
def capture_route_for_metrics():
    # Use Flask's route template, never the raw URL (which may contain IDs).
    request.environ["devboard.route"] = (
        request.url_rule.rule if request.url_rule is not None else "unmatched"
    )


def _fetch_tasks(project_id: str) -> list[dict]:
    url = f"{TASK_SERVICE_URL}/tasks?project_id={project_id}"
    try:
        with httpx.Client(timeout=10.0) as client:
            r = client.get(url)
    except Exception as err:  # noqa: BLE001
        log.warning("could not reach backend for tasks: %s", err)
        return []
    if r.status_code != 200:
        log.warning("backend returned %s for tasks", r.status_code)
        return []
    return (r.json() or {}).get("tasks", [])


def _format_tasks_for_prompt(tasks: list[dict]) -> str:
    if not tasks:
        return "(no tasks)"
    lines = []
    for t in tasks:
        lines.append(
            f"- #{t.get('id')} [{t.get('status')}/{t.get('priority')}] {t.get('title')}"
        )
    return "\n".join(lines)


def _observe_generation(generator: Iterable[str], operation: str) -> Iterable[str]:
    """Measure model streaming duration and record upstream/stream failures."""
    started = time.perf_counter()
    outcome = "success"
    failure_reason = None
    try:
        for chunk in generator:
            if chunk.startswith("[model-error"):
                outcome = "error"
                failure_reason = "upstream_error"
            yield chunk
    except GeneratorExit:
        outcome = "cancelled"
        failure_reason = "client_disconnect"
        raise
    except Exception:
        outcome = "error"
        failure_reason = "exception"
        raise
    finally:
        ai_generation_duration.labels(operation).observe(time.perf_counter() - started)
        ai_generations_total.labels(operation, outcome).inc()
        if failure_reason is not None:
            ai_generation_errors_total.labels(operation, failure_reason).inc()


def _sse(generator: Iterable[str], operation: str):
    """Frame generated text as Server-Sent Events and observe full generation."""
    def stream():
        try:
            for chunk in _observe_generation(generator, operation):
                payload = json.dumps({"text": chunk})
                yield f"data: {payload}\n\n"
        except Exception as err:  # noqa: BLE001
            log.exception("stream error: %s", err)
            yield f"data: {json.dumps({'error': str(err)})}\n\n"
        finally:
            yield "data: [DONE]\n\n"

    return Response(
        stream_with_context(stream()),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


# --- routes ---------------------------------------------------------------

@app.get("/health")
def health():
    return jsonify({"status": "ok", "service": "ai-service", "model": MODEL_NAME})


@app.get("/metrics")
def metrics():
    return generate_latest(registry), 200, {"Content-Type": CONTENT_TYPE_LATEST}


@app.get("/model/check")
def model_check():
    return jsonify(check_model_runner())


@app.post("/summarise")
def summarise():
    body = request.get_json(silent=True) or {}
    project_id = body.get("project_id")
    if not project_id:
        return jsonify({"error": "project_id is required"}), 400

    tasks = _fetch_tasks(project_id)
    prompt = (
        "You are an engineering manager assistant. Summarise the current state of "
        "this project in 4-6 sentences. Call out blockers, in-progress work, and "
        "anything overdue. Be specific — reference task IDs when useful.\n\n"
        f"Tasks:\n{_format_tasks_for_prompt(tasks)}"
    )
    messages = [
        {"role": "system", "content": "You are a concise, accurate engineering assistant."},
        {"role": "user", "content": prompt},
    ]
    return _sse(stream_chat(messages), "summarise")


@app.post("/ask")
def ask():
    body = request.get_json(silent=True) or {}
    project_id = body.get("project_id")
    question = (body.get("question") or "").strip()
    if not project_id or not question:
        return jsonify({"error": "project_id and question are required"}), 400

    tasks = _fetch_tasks(project_id)
    prompt = (
        "You are answering questions about an engineering project. Use only "
        "the task list below as context. If the answer isn't in the tasks, "
        "say so plainly.\n\n"
        f"Tasks:\n{_format_tasks_for_prompt(tasks)}\n\n"
        f"Question: {question}"
    )
    messages = [
        {"role": "system", "content": "You are a concise, accurate engineering assistant."},
        {"role": "user", "content": prompt},
    ]
    return _sse(stream_chat(messages), "ask")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "3005")))
