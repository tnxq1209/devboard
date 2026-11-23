# DevBoard Loki dashboard

Place `devboard-logging-dashboard.yaml` under `observability/logging/dashboards/`
and include that directory in the existing `observability-logging` Argo CD Application.

The ConfigMap uses the existing `grafana_dashboard: "1"` sidecar label and a unique
data key (`devboard-logs.json`). It expects the Loki datasource UID `loki`.

Panels: all DevBoard logs, backend logs, AI service logs, frontend logs, common
error terms, total log volume, and log volume by pod.

The workload panels use pod-name regexes. If your actual pod names differ, adjust
the matching expressions in the dashboard JSON.
