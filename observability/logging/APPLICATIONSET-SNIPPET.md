Add this element under `spec.generators[0].list.elements` in `gitops/root/devboard-root.yml`:

```yaml
          - app: observability-logging
            path: observability/logging
```

The existing ApplicationSet destination namespace is `devboard`, but the datasource ConfigMap explicitly declares `namespace: monitoring`. That is valid because the namespace is specified in the manifest. The Loki and Alloy releases are installed by Terraform, not by this ApplicationSet.
