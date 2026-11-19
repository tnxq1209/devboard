# DevBoard metrics — application instrumentation (step 1)

This step instruments the Go backend and Flask AI service. It does not install or
change Prometheus, Grafana, Kubernetes resources, or ArgoCD yet.

## Go backend metrics

The existing `/metrics` endpoint continues to use the Prometheus default
registry, which includes the Go runtime and process collectors supplied by
`client_golang`.

| Metric | Type | Labels / meaning |
|---|---|---|
| `devboard_http_requests_total` | Counter | `method`, normalized Gin `route`, `status` |
| `devboard_http_request_duration_seconds` | Histogram | `method`, normalized Gin `route` |
| `devboard_http_requests_in_flight` | Gauge | Requests currently being handled |
| `devboard_db_connections_open` | Gauge | Open PostgreSQL pool connections |
| `devboard_db_connections_in_use` | Gauge | In-use PostgreSQL pool connections |
| `devboard_db_connections_idle` | Gauge | Idle PostgreSQL pool connections |
| `go_*`, `process_*` | Various | Go runtime and process metrics |

Prometheus scrape requests to `/metrics` are excluded from the application HTTP
request counter and histogram. Gin route templates are used for labels to avoid
high-cardinality URL IDs.

## Python AI service metrics

The Flask `/metrics` endpoint uses its explicit registry and now registers
`ProcessCollector`, `PlatformCollector`, and `GCCollector` as well as application
metrics.

| Metric | Type | Labels / meaning |
|---|---|---|
| `ai_service_http_requests_total` | Counter | `method`, normalized Flask `route`, `status` |
| `ai_service_http_requests_in_flight` | Gauge | Requests currently being handled, including active SSE streams |
| `ai_service_http_request_duration_seconds` | Histogram | `method`, normalized Flask `route`; measures the full WSGI response lifetime, including SSE streaming |
| `ai_service_generations_total` | Counter | `operation` (`ask`/`summarise`), `outcome` (`success`/`error`/`cancelled`) |
| `ai_service_generation_duration_seconds` | Histogram | `operation`; full model streaming duration |
| `ai_service_generation_errors_total` | Counter | `operation`, bounded `reason` (`upstream_error`, `exception`, `client_disconnect`) |
| `process_*`, `python_*` | Various | Python process, platform and GC metrics |

Metrics scrapes are excluded from HTTP application metrics. Flask route templates
are used instead of raw paths. AI generation metrics distinguish an HTTP 200 SSE
response from a model failure that occurs after streaming has started.

## Apply these files

Copy the contents of `backend/` into the repository's `backend/` directory and
the contents of `ai-service/` into the repository's `ai-service/` directory.
Do not replace the Dockerfiles or Kubernetes manifests in this step.

The Go module file promotes the already-imported `github.com/prometheus/client_golang`
dependency from indirect to direct. No new Go or Python dependency is introduced.

After applying, rebuild and publish both application images through the existing
GitHub Actions workflow. The current EKS pods will not receive these changes
until the updated images are deployed.

## Next step

Create named HTTP Service ports and ServiceMonitors under `observability/metrics/`
so the existing Prometheus Operator discovers and scrapes both application
`/metrics` endpoints. This step intentionally does not create those resources.
