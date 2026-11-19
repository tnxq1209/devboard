# DevBoard Grafana dashboards

This package adds three Grafana dashboards as ConfigMaps:

- DevBoard / Backend
- DevBoard / AI Service
- DevBoard / Kubernetes Infrastructure

The ConfigMaps are placed in the `monitoring` namespace and use the kube-prometheus-stack Grafana dashboard sidecar label `grafana_dashboard: "1"`. The dashboards use the Prometheus datasource UID `prometheus`, which is the standard datasource provisioned by kube-prometheus-stack.

## GitOps integration

The updated `gitops/root/devboard-root.yml` changes the observability ApplicationSet source path from `observability/metrics/servicemonitors` to `observability/metrics`, so ArgoCD discovers both the ServiceMonitor resources and dashboard ConfigMaps.

Keep the existing ServiceMonitor YAML files in `observability/metrics/servicemonitors/`. The ServiceMonitors should remain in namespace `monitoring` and select Services in namespace `devboard`.

## Important

The Grafana dashboard sidecar must be enabled and configured to watch ConfigMaps with label `grafana_dashboard: "1"`. kube-prometheus-stack enables dashboard sidecar provisioning by default. If the dashboards do not appear after sync, inspect the Grafana sidecar settings and logs before changing Terraform.

The infrastructure dashboard relies on `node-exporter` and `kube-state-metrics`, which are installed by kube-prometheus-stack. The application dashboards rely on the custom metrics already exposed by DevBoard backend and AI service.
