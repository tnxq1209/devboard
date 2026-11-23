#!/usr/bin/env bash
set -Eeuo pipefail

# Override these with environment variables if needed.
AWS_REGION="${AWS_REGION:-ap-south-1}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-test-eks}"

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_SERVICE="${ARGOCD_SERVICE:-argocd-server}"
ARGOCD_LOCAL_PORT="${ARGOCD_LOCAL_PORT:-8080}"
ARGOCD_SERVICE_PORT="${ARGOCD_SERVICE_PORT:-80}"
ARGOCD_SECRET="${ARGOCD_SECRET:-argocd-initial-admin-secret}"
ARGOCD_PASSWORD_KEY="${ARGOCD_PASSWORD_KEY:-password}"

GRAFANA_NAMESPACE="${GRAFANA_NAMESPACE:-monitoring}"
GRAFANA_SERVICE="${GRAFANA_SERVICE:-kube-prometheus-stack-grafana}"
GRAFANA_LOCAL_PORT="${GRAFANA_LOCAL_PORT:-3000}"
GRAFANA_SERVICE_PORT="${GRAFANA_SERVICE_PORT:-80}"
GRAFANA_SECRET="${GRAFANA_SECRET:-kube-prometheus-stack-grafana}"
GRAFANA_USER_KEY="${GRAFANA_USER_KEY:-admin-user}"
GRAFANA_PASSWORD_KEY="${GRAFANA_PASSWORD_KEY:-admin-password}"

for cmd in aws kubectl base64; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but was not found in PATH." >&2
    exit 1
  fi
done

LOG_DIR="$(mktemp -d -t eks-dashboard-forward.XXXXXX)"
ARGOCD_PID=""
GRAFANA_PID=""

cleanup() {
  echo
  echo "Stopping port-forward processes..."
  [[ -n "$ARGOCD_PID" ]] && kill "$ARGOCD_PID" 2>/dev/null || true
  [[ -n "$GRAFANA_PID" ]] && kill "$GRAFANA_PID" 2>/dev/null || true
  [[ -n "$ARGOCD_PID" ]] && wait "$ARGOCD_PID" 2>/dev/null || true
  [[ -n "$GRAFANA_PID" ]] && wait "$GRAFANA_PID" 2>/dev/null || true
  echo "Port-forwards stopped."
  echo "Logs were saved in: $LOG_DIR"
}
trap cleanup EXIT INT TERM

# Read a Kubernetes Secret field without writing credentials to the log files.
read_secret_key() {
  local namespace="$1"
  local secret="$2"
  local key="$3"
  local encoded

  if ! encoded="$(kubectl -n "$namespace" get secret "$secret" \
      -o "jsonpath={.data.${key}}" 2>/dev/null)" || [[ -z "$encoded" ]]; then
    return 1
  fi

  printf '%s' "$encoded" | base64 --decode
}

echo "Updating kubeconfig for EKS cluster '$EKS_CLUSTER_NAME' in '$AWS_REGION'..."
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER_NAME"

echo
echo "Checking Kubernetes access..."
kubectl cluster-info >/dev/null

echo "Retrieving dashboard credentials..."
ARGOCD_PASSWORD=""
GRAFANA_USER=""
GRAFANA_PASSWORD=""

if ARGOCD_PASSWORD="$(read_secret_key "$ARGOCD_NAMESPACE" "$ARGOCD_SECRET" "$ARGOCD_PASSWORD_KEY")"; then
  :
else
  echo "Warning: Could not read Argo CD password from secret '$ARGOCD_SECRET'." >&2
  echo "The initial admin secret may have been deleted after the password was changed." >&2
fi

if GRAFANA_USER="$(read_secret_key "$GRAFANA_NAMESPACE" "$GRAFANA_SECRET" "$GRAFANA_USER_KEY")"; then
  :
else
  echo "Warning: Could not read Grafana username from secret '$GRAFANA_SECRET'." >&2
fi

if GRAFANA_PASSWORD="$(read_secret_key "$GRAFANA_NAMESPACE" "$GRAFANA_SECRET" "$GRAFANA_PASSWORD_KEY")"; then
  :
else
  echo "Warning: Could not read Grafana password from secret '$GRAFANA_SECRET'." >&2
fi

echo "Starting Argo CD port-forward..."
kubectl -n "$ARGOCD_NAMESPACE" port-forward \
  --address 127.0.0.1 \
  "svc/$ARGOCD_SERVICE" \
  "$ARGOCD_LOCAL_PORT:$ARGOCD_SERVICE_PORT" \
  >"$LOG_DIR/argocd.log" 2>&1 &
ARGOCD_PID=$!

echo "Starting Grafana port-forward..."
kubectl -n "$GRAFANA_NAMESPACE" port-forward \
  --address 127.0.0.1 \
  "svc/$GRAFANA_SERVICE" \
  "$GRAFANA_LOCAL_PORT:$GRAFANA_SERVICE_PORT" \
  >"$LOG_DIR/grafana.log" 2>&1 &
GRAFANA_PID=$!

# Give kubectl a moment to detect missing services, unavailable endpoints,
# or local port conflicts before reporting success.
sleep 3

if ! kill -0 "$ARGOCD_PID" 2>/dev/null; then
  echo "Error: Argo CD port-forward failed. Log:" >&2
  cat "$LOG_DIR/argocd.log" >&2
  exit 1
fi

if ! kill -0 "$GRAFANA_PID" 2>/dev/null; then
  echo "Error: Grafana port-forward failed. Log:" >&2
  cat "$LOG_DIR/grafana.log" >&2
  exit 1
fi

echo
echo "========================================"
echo "          DASHBOARD ACCESS"
echo "========================================"
echo
echo "Argo CD"
echo "  URL:      http://localhost:$ARGOCD_LOCAL_PORT"
echo "  Username: admin"
if [[ -n "$ARGOCD_PASSWORD" ]]; then
  printf '  Password: %s\n' "$ARGOCD_PASSWORD"
else
  echo "  Password: unavailable (see warning above)"
fi

echo
echo "Grafana"
echo "  URL:      http://localhost:$GRAFANA_LOCAL_PORT"
if [[ -n "$GRAFANA_USER" ]]; then
  printf '  Username: %s\n' "$GRAFANA_USER"
else
  echo "  Username: unavailable (see warning above)"
fi
if [[ -n "$GRAFANA_PASSWORD" ]]; then
  printf '  Password: %s\n' "$GRAFANA_PASSWORD"
else
  echo "  Password: unavailable (see warning above)"
fi

echo
echo "Keep this terminal open. Press Ctrl+C to stop both port-forwards."
echo "Credentials are read from Kubernetes Secrets and are not written to the log files."

# Exit if either port-forward exits unexpectedly.
while kill -0 "$ARGOCD_PID" 2>/dev/null && kill -0 "$GRAFANA_PID" 2>/dev/null; do
  sleep 1
done

echo "A port-forward process exited unexpectedly. Check logs in: $LOG_DIR" >&2
cat "$LOG_DIR/argocd.log" >&2
cat "$LOG_DIR/grafana.log" >&2
exit 1
