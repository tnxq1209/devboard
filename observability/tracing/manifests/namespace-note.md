# Tracing deployment

All resources are deployed into the existing `monitoring` namespace.
Tempo stores traces on a 5Gi gp3 PVC. The Collector is a single-replica
Deployment and receives OTLP over gRPC (4317) and HTTP (4318).
