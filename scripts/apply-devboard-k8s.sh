#!/usr/bin/env bash
#
# DevBoard Kubernetes bootstrap
# Run from anywhere: ./scripts/apply-devboard-k8s.sh
#
# Prerequisites:
# - kubectl configured for the target EKS cluster
# - Argo CD already installed
# - Envoy Gateway controller installed before Gateway API resources are synced
# - ESO IAM/IRSA and AWS Secrets Manager entries configured
#
# IMPORTANT:
# devboard-raw owns the k8s/ directory. This script creates prerequisites and
# registers Argo CD Applications; Argo CD applies k8s/ resources. It deliberately
# does not kubectl-apply those same application manifests a second time.

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECTL="${KUBECTL:-kubectl}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-300s}"
APP_WAIT_TIMEOUT="${APP_WAIT_TIMEOUT:-600s}"

log() { printf '\n[DevBoard] %s\n' "$*"; }
die() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }
apply() { "$KUBECTL" apply -f "$1"; }

command -v "$KUBECTL" >/dev/null 2>&1 || die "kubectl not found."
[[ -d "$ROOT_DIR/gitops" && -d "$ROOT_DIR/k8s" ]] || die "Expected gitops/ and k8s/ beside this script."

log "Checking cluster connectivity"
"$KUBECTL" cluster-info >/dev/null

log "1/7 - Creating application namespaces"
apply "$ROOT_DIR/k8s/namespace.yml"
apply "$ROOT_DIR/gitops/cert-manager/namespace.yaml"
apply "$ROOT_DIR/gitops/ollama/ollama-namespace.yaml"

log "2/7 - Applying verifier RBAC"
apply "$ROOT_DIR/gitops/verifier_rbac/"

log "3/7 - Installing cert-manager resources"
apply "$ROOT_DIR/gitops/cert-manager/cert-manager.yaml"
log "Waiting for cert-manager CRDs"
"$KUBECTL" wait --for=condition=Established \
  crd/certificates.cert-manager.io \
  crd/clusterissuers.cert-manager.io \
  --timeout="$APP_WAIT_TIMEOUT"
apply "$ROOT_DIR/gitops/cert-manager/clusterissuer.yaml"

log "4/7 - Installing External Secrets Operator through Argo CD"
apply "$ROOT_DIR/gitops/argocd/external-secrets.yaml"
log "Waiting for ESO CRDs"
"$KUBECTL" wait --for=condition=Established \
  crd/clustersecretstores.external-secrets.io \
  crd/externalsecrets.external-secrets.io \
  --timeout="$APP_WAIT_TIMEOUT"

log "Applying ClusterSecretStore and waiting for readiness"
apply "$ROOT_DIR/k8s/external-secrets/cluster-secret-store.yaml"
"$KUBECTL" wait \
  --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True \
  clustersecretstore/aws-secrets-manager --timeout="$WAIT_TIMEOUT"

log "Applying ExternalSecrets"
apply "$ROOT_DIR/k8s/external-secrets/postgres-external-secret.yaml"
apply "$ROOT_DIR/k8s/external-secrets/cloudflare-external-secret.yaml"

log "Waiting for application and Cloudflare credentials to synchronize"
"$KUBECTL" wait \
  --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True \
  externalsecret/postgres-credentials -n devboard --timeout="$WAIT_TIMEOUT"
"$KUBECTL" wait \
  --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True \
  externalsecret/cloudflare-api-token -n external-dns --timeout="$WAIT_TIMEOUT"
"$KUBECTL" wait \
  --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True \
  externalsecret/cloudflare-api-token -n cert-manager --timeout="$WAIT_TIMEOUT"

log "5/7 - Registering observability and Ollama Applications"
apply "$ROOT_DIR/gitops/argocd/observability.yaml"
apply "$ROOT_DIR/gitops/argocd/ollama.yaml"

log "6/7 - Applying Ollama workload manifests"
apply "$ROOT_DIR/gitops/ollama/ollama-pvc.yaml"
apply "$ROOT_DIR/gitops/ollama/ollama-service.yaml"
apply "$ROOT_DIR/gitops/ollama/ollama-deployment.yaml"

log "7/7 - Registering ExternalDNS and DevBoard Applications"
apply "$ROOT_DIR/gitops/argocd/external-dns.yaml"
apply "$ROOT_DIR/gitops/argocd/devboard-raw.yaml"

log "Bootstrap complete"
cat <<'EOF'

Argo CD now reconciles the registered Applications.
The devboard-raw Application owns k8s/, so its resources are intentionally
not applied directly by this script.

Check Argo CD Application health/sync status before exposing traffic.
EOF
