# DevBoard tracing — Tempo + OpenTelemetry Collector (Step 2)

## Resources

Deploy all files from `manifests/` and `grafana/` through the existing Argo CD
ApplicationSet. All resources use the existing `monitoring` namespace.

- Tempo: single-replica StatefulSet, internal ClusterIP service, 5Gi gp3 PVC.
- OpenTelemetry Collector: one replica, OTLP/gRPC + OTLP/HTTP receivers,
  Kubernetes metadata enrichment, memory limiter, batch processor.
- Grafana datasource: Tempo, UID `tempo`, with Loki trace-to-logs correlation.

## Argo CD wiring

Add an ApplicationSet element:
```yaml
- app: observability-tracing
  path: observability/tracing
```

The generated Application destination namespace is `devboard`, but every
resource in this folder explicitly declares `namespace: monitoring`; the
ClusterRole and ClusterRoleBinding are cluster-scoped.

Keep the existing `observability` and `observability-logging` entries intact.

## Rollout

1. Commit this folder to `master`.
2. Add the ApplicationSet element above and commit it.
3. Wait for `observability-tracing` to become Synced and Healthy.
4. Verify `tempo` and `otel-collector` pods and Services in `monitoring`.
5. Build and deploy the instrumented app images from Step 1.
6. Generate an AI request, then open Grafana Explore with Tempo.

## Important

The app image changes from Step 1 are not deployed by this folder. Deploying
this Collector first makes the configured OTLP endpoint available.

The chart/image versions are pinned for reproducibility. Review/update them
deliberately rather than using `latest`.

The Tempo datasource's Loki correlation expects your Loki datasource UID to be
`loki`. If your current Grafana Loki datasource uses another UID, update
`tracesToLogsV2.datasourceUid` to match it before syncing.
