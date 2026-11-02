# Port-forward for Argo CD
resource "null_resource" "argocd_port_forward" {
  triggers = {
    helm_id = helm_release.argocd.id
  }

  provisioner "local-exec" {
    # Launches kubectl port-forward in the background
    # Works on Linux, macOS, and Git Bash / WSL on Windows
    command = "kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &"
  }

  depends_on = [helm_release.argocd]
}

# Port-forward for Grafana (kube-prometheus-stack)
resource "null_resource" "grafana_port_forward" {
  triggers = {
    helm_id = helm_release.kube_prometheus_stack.id
  }

  provisioner "local-exec" {
    # Grafana service name typically matches the Helm release name + '-grafana'
    command = "kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 > /dev/null 2>&1 &"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
