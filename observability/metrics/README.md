# DevBoard application metrics

These ServiceMonitor resources tell the Prometheus Operator installed by
`kube-prometheus-stack` to scrape the DevBoard backend and AI service.

## Resource placement

- ServiceMonitor CRs are created in `monitoring`, alongside the Prometheus
  installation. This works with the chart's default namespace-scoped discovery.
- Their `namespaceSelector` points to Services in `devboard`.
- Both ServiceMonitors carry `release: kube-prometheus-stack`, matching the
  Helm release-name selector used by the current installation.

## Service requirements

The corresponding Services in `k8s/` have:

- a `http` named port;
- a Service label matching the ServiceMonitor selector;
- `/metrics` exposed by the selected application container.

## GitOps

The root ApplicationSet adds an `observability` generated Application whose
source is `observability/metrics/servicemonitors`. The ServiceMonitor manifests
explicitly set `metadata.namespace: monitoring`; the ApplicationSet's
`destination.namespace: devboard` is only the default namespace for resources
that do not declare one.

Terraform remains the owner of the `kube-prometheus-stack` Helm release. No
Helm values or Terraform resources are changed by this package.
