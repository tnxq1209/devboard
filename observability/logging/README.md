# DevBoard logging

This directory contains the logging configuration for the DevBoard EKS cluster.

## Ownership

- Terraform (`terraform/eks.tf`) installs the Loki and Alloy Helm releases through the existing `eks_blueprints_addons.helm_releases` map.
- These values files are the source of truth for those Helm releases.
- ArgoCD applies `grafana-loki-datasource.yaml` so the existing Grafana instance discovers Loki as a data source.

Do not also create ArgoCD Helm Applications for Loki or Alloy; that would give two controllers ownership of the same releases.

## Components

- Loki: monolithic deployment, one replica, filesystem storage on a 5 GiB `gp3` PVC, seven-day retention.
- Alloy: DaemonSet, reads Kubernetes Pod logs through the Kubernetes API, and forwards them to Loki.
- Grafana: uses the existing Grafana instance and an automatically provisioned Loki data source.

Loki is internal-only. No AWS LoadBalancer is created for Loki or Alloy.

## Deployment order

1. Add the Loki and Alloy entries from `terraform/helm-releases-snippet.tf` to the existing `helm_releases` map in `terraform/eks.tf`.
2. Add the variables from `terraform/variables-snippet.tf` to `terraform/variables.tf` (or the existing variables file).
3. Add `grafana-loki-datasource.yaml` to the ArgoCD-managed path and add the `observability-logging` ApplicationSet entry described in `APPLICATIONSET-SNIPPET.md`.
4. Review the Terraform plan before applying. Confirm it only adds the two expected Helm releases and does not replace the EKS cluster, node group, kube-prometheus-stack, Envoy Gateway, or ArgoCD.
5. Sync the ArgoCD application after Loki is installed.

## Notes

- The Loki filesystem PVC is retained by Kubernetes storage provisioning; keep it when upgrading the release.
- Filesystem storage on a single PVC is appropriate for this small development cluster, not a highly available production logging service.
- Seven-day retention is configured to limit storage growth. Retention deletion is asynchronous and handled by Loki's compactor.
- Alloy is configured to collect logs from Pods across namespaces. Review access and retention requirements before using this configuration for sensitive workloads.
