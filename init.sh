#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "  RHDH Bootstrap - Cluster Initialization"
echo "============================================"
echo ""

# -------------------------------------------------------------------
# Pre-flight checks
# -------------------------------------------------------------------
if ! command -v oc &>/dev/null; then
  echo "ERROR: 'oc' CLI not found. Install it first."
  exit 1
fi

if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged into an OpenShift cluster. Run 'oc login' first."
  exit 1
fi

CLUSTER_USER=$(oc whoami)
CLUSTER_URL=$(oc whoami --show-server)
echo "Cluster:  $CLUSTER_URL"
echo "User:     $CLUSTER_USER"
echo ""

# -------------------------------------------------------------------
# Phase 0: Install OpenShift GitOps operator
# -------------------------------------------------------------------
echo "--- Phase 0: Installing OpenShift GitOps operator ---"
oc apply -k "$SCRIPT_DIR/cluster-configs/gitops/"

echo "Waiting for GitOps operator subscription to be available..."
until oc get csv -n openshift-gitops-operator 2>/dev/null | grep -q "openshift-gitops-operator.*Succeeded"; do
  echo "  ...waiting for GitOps operator CSV to succeed"
  sleep 15
done
echo "GitOps operator installed."

echo "Waiting for ArgoCD instance to be ready..."
until oc get argocd openshift-gitops -n openshift-gitops &>/dev/null; do
  echo "  ...waiting for ArgoCD CR"
  sleep 10
done

until oc get argocd openshift-gitops -n openshift-gitops -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Available"; do
  echo "  ...waiting for ArgoCD to become Available"
  sleep 15
done
echo "ArgoCD is ready."
echo ""

# -------------------------------------------------------------------
# Phase 1: Apply security configs
# -------------------------------------------------------------------
echo "--- Phase 1: Applying security configurations ---"
oc apply -k "$SCRIPT_DIR/cluster-configs/security/"
echo "Security configs applied (htpasswd auth, admin RBAC)."
echo ""

# -------------------------------------------------------------------
# Phase 2: Apply secrets (manual step reminder)
# -------------------------------------------------------------------
echo "--- Phase 2: Secrets ---"
echo ""
echo "  Before proceeding, ensure secrets are created:"
echo ""
echo "    Keycloak DB secret:"
echo "      cp cluster-configs/keycloak/secrets/keycloak-db-secret.yaml.example \\"
echo "         cluster-configs/keycloak/secrets/keycloak-db-secret.yaml"
echo "      # Edit with your credentials"
echo "      oc apply -k cluster-configs/keycloak/secrets/"
echo ""
echo "    Developer Hub secrets:"
echo "      cp cluster-configs/developer-hub/secrets/keycloak-secrets.yaml.example \\"
echo "         cluster-configs/developer-hub/secrets/keycloak-secrets.yaml"
echo "      cp cluster-configs/developer-hub/secrets/rhdh-secrets.yaml.example \\"
echo "         cluster-configs/developer-hub/secrets/rhdh-secrets.yaml"
echo "      cp cluster-configs/developer-hub/secrets/argocd-secrets.yaml.example \\"
echo "         cluster-configs/developer-hub/secrets/argocd-secrets.yaml"
echo "      # Edit each file with your values"
echo "      oc apply -k cluster-configs/developer-hub/secrets/"
echo ""

read -rp "Have you applied all secrets? (y/N) " SECRETS_READY
if [[ "$SECRETS_READY" != "y" && "$SECRETS_READY" != "Y" ]]; then
  echo ""
  echo "Apply secrets and re-run this script, or apply the app-of-apps manually:"
  echo "  oc apply -k applications/"
  exit 0
fi
echo ""

# -------------------------------------------------------------------
# Phase 3: Deploy app-of-apps (all ArgoCD Applications)
# -------------------------------------------------------------------
echo "--- Phase 3: Deploying ArgoCD Applications (app-of-apps) ---"
echo ""
echo "  Sync wave ordering:"
echo "    Wave 1: keycloak, pipelines, quay"
echo "    Wave 2: dev-spaces, orchestrator"
echo "    Wave 3: developer-hub"
echo ""
oc apply -k "$SCRIPT_DIR/applications/"
echo ""
echo "All ArgoCD Applications created. ArgoCD will now sync them in order."
echo ""

# -------------------------------------------------------------------
# Phase 4: Post-deploy reminders
# -------------------------------------------------------------------
echo "--- Post-deploy steps ---"
echo ""
echo "  1. Apply Keycloak realm import (after Keycloak operator is ready):"
echo "     cp cluster-configs/keycloak/rhdh-realm-import.yaml.example \\"
echo "        cluster-configs/keycloak/rhdh-realm-import.yaml"
echo "     # Edit with your client secret and cluster domain"
echo "     oc wait --for=condition=Established crd/keycloaks.k8s.keycloak.org --timeout=300s"
echo "     oc apply -f cluster-configs/keycloak/rhdh-realm-import.yaml"
echo ""
echo "  2. Deploy Orchestrator workflows (after SonataFlow operators are ready):"
echo "     oc apply -k workflows/"
echo ""
echo "  3. Monitor progress:"
echo "     oc get applications -n openshift-gitops"
echo ""

ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "<pending>")
echo "  ArgoCD console: https://$ARGOCD_ROUTE"
echo ""
echo "Bootstrap complete."
