#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_REPO="${HOME}/Repos/openshift-bootstrap-gitops"

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

if ! git -C "$SCRIPT_DIR" remote get-url origin &>/dev/null; then
  echo "ERROR: No git remote 'origin' configured."
  echo "  Initialize git and push to GitHub first."
  exit 1
fi

CLUSTER_USER=$(oc whoami)
CLUSTER_URL=$(oc whoami --show-server)
echo "Cluster:  $CLUSTER_URL"
echo "User:     $CLUSTER_USER"
echo ""

# -------------------------------------------------------------------
# Auto-detect cluster domain
# -------------------------------------------------------------------
echo "--- Detecting cluster domain ---"
APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
CLUSTER_DOMAIN=${APPS_DOMAIN#apps.}
echo "Apps domain:    $APPS_DOMAIN"
echo "Cluster domain: $CLUSTER_DOMAIN"
echo ""

# -------------------------------------------------------------------
# Derive GitHub org from git remote
# -------------------------------------------------------------------
REMOTE_URL=$(git -C "$SCRIPT_DIR" remote get-url origin)
GH_ORG=$(echo "$REMOTE_URL" | sed -E 's|.*[:/]([^/]+)/[^/]+$|\1|')
echo "GitHub org: $GH_ORG"
echo ""

# -------------------------------------------------------------------
# Populate placeholders in repo files
# -------------------------------------------------------------------
echo "--- Populating cluster-specific values ---"

sed -i '' "s|<YOUR_ORG>|${GH_ORG}|g" "$SCRIPT_DIR"/applications/*.yaml
echo "  Set repoURL org -> ${GH_ORG} in applications/*.yaml"

# Replace keycloak hostname (works with placeholder or any previous domain)
sed -i '' "s|hostname: sso\.apps\..*|hostname: sso.apps.${CLUSTER_DOMAIN}|g" \
  "$SCRIPT_DIR/cluster-configs/keycloak/keycloak-instance.yaml"
echo "  Set keycloak hostname -> sso.apps.${CLUSTER_DOMAIN}"

# Replace ConsoleLink href (works with placeholder or any previous domain)
sed -i '' "s|href: https://backstage-developer-hub-rhdh\.apps\..*|href: https://backstage-developer-hub-rhdh.apps.${CLUSTER_DOMAIN}|g" \
  "$SCRIPT_DIR/cluster-configs/developer-hub/console-link.yaml"
echo "  Set console link -> https://backstage-developer-hub-rhdh.apps.${CLUSTER_DOMAIN}"
echo ""

# -------------------------------------------------------------------
# Create secret files (gitignored -- never committed)
# -------------------------------------------------------------------
echo "--- Creating secret files ---"

# Determine OIDC client secret
if [[ -d "$SOURCE_REPO" ]] && [[ -f "$SOURCE_REPO/cluster-configs/developer-hub/secrets/keycloak-secrets.yaml" ]]; then
  SRC_KC="$SOURCE_REPO/cluster-configs/developer-hub/secrets/keycloak-secrets.yaml"
  if grep -q 'stringData:' "$SRC_KC"; then
    CLIENT_SECRET=$(grep 'KEYCLOAK_CLIENT_SECRET:' "$SRC_KC" | awk '{print $2}')
  else
    CLIENT_SECRET_B64=$(grep 'KEYCLOAK_CLIENT_SECRET:' "$SRC_KC" | awk '{print $2}')
    CLIENT_SECRET=$(printf '%s' "$CLIENT_SECRET_B64" | base64 -d)
  fi
  echo "  Using KEYCLOAK_CLIENT_SECRET from source repo"
else
  CLIENT_SECRET=$(openssl rand -hex 16)
  echo "  Generated random KEYCLOAK_CLIENT_SECRET"
fi

# 1. Keycloak DB Secret
if [[ -d "$SOURCE_REPO" ]] && [[ -f "$SOURCE_REPO/cluster-configs/keycloak/secrets/keycloak-db-secret.yaml" ]]; then
  cp "$SOURCE_REPO/cluster-configs/keycloak/secrets/keycloak-db-secret.yaml" \
     "$SCRIPT_DIR/cluster-configs/keycloak/secrets/keycloak-db-secret.yaml"
  echo "  Copied keycloak-db-secret.yaml from source repo"
else
  cat > "$SCRIPT_DIR/cluster-configs/keycloak/secrets/keycloak-db-secret.yaml" <<EOFYAML
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-db-secret
  namespace: keycloak
type: Opaque
stringData:
  username: keycloak
  password: keycloak-db-password
EOFYAML
  echo "  Generated keycloak-db-secret.yaml with defaults"
fi

# 2. Keycloak Secrets (for RHDH integration)
cat > "$SCRIPT_DIR/cluster-configs/developer-hub/secrets/keycloak-secrets.yaml" <<EOFYAML
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-secrets
  namespace: rhdh
type: Opaque
stringData:
  KEYCLOAK_BASE_URL: "https://sso.${APPS_DOMAIN}"
  KEYCLOAK_CLIENT_ID: rhdh
  KEYCLOAK_CLIENT_SECRET: "${CLIENT_SECRET}"
  KEYCLOAK_LOGIN_REALM: rhdh
  KEYCLOAK_REALM: rhdh
EOFYAML
echo "  Created keycloak-secrets.yaml (KEYCLOAK_BASE_URL=https://sso.${APPS_DOMAIN})"

# 3. ArgoCD Secrets
cat > "$SCRIPT_DIR/cluster-configs/developer-hub/secrets/argocd-secrets.yaml" <<EOFYAML
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secrets
  namespace: rhdh
type: Opaque
stringData:
  ARGOCD_URL: "https://openshift-gitops-server-openshift-gitops.${APPS_DOMAIN}"
  ARGOCD_USERNAME: developer-hub
  ARGOCD_PASSWORD: d3v3l0p3rs
EOFYAML
echo "  Created argocd-secrets.yaml (ARGOCD_URL=https://openshift-gitops-server-openshift-gitops.${APPS_DOMAIN})"

# 4. RHDH Secrets (GitHub App + Backend)
if [[ -d "$SOURCE_REPO" ]] && [[ -f "$SOURCE_REPO/cluster-configs/developer-hub/secrets/rhdh-secrets.yaml" ]]; then
  cp "$SOURCE_REPO/cluster-configs/developer-hub/secrets/rhdh-secrets.yaml" \
     "$SCRIPT_DIR/cluster-configs/developer-hub/secrets/rhdh-secrets.yaml"

  NEW_BACKEND_URL_B64=$(printf '%s' "https://backstage-developer-hub-rhdh.${APPS_DOMAIN}" | base64)
  sed -i '' "s|BACKEND_URL:.*|BACKEND_URL: ${NEW_BACKEND_URL_B64}|" \
    "$SCRIPT_DIR/cluster-configs/developer-hub/secrets/rhdh-secrets.yaml"
  echo "  Copied rhdh-secrets.yaml from source repo, updated BACKEND_URL for current cluster"
else
  echo ""
  echo "  WARNING: Source repo not found at $SOURCE_REPO"
  echo "  Cannot create rhdh-secrets.yaml without GitHub App credentials."
  echo "  Create it manually from the .example template:"
  echo "    cp cluster-configs/developer-hub/secrets/rhdh-secrets.yaml.example \\"
  echo "       cluster-configs/developer-hub/secrets/rhdh-secrets.yaml"
  echo "  Then re-run this script."
  exit 1
fi

# 5. Keycloak Realm Import
sed \
  -e "s|<RHDH_CLIENT_SECRET>|${CLIENT_SECRET}|g" \
  -e "s|<YOUR_CLUSTER_DOMAIN>|${CLUSTER_DOMAIN}|g" \
  "$SCRIPT_DIR/cluster-configs/keycloak/rhdh-realm-import.yaml.example" \
  > "$SCRIPT_DIR/cluster-configs/keycloak/rhdh-realm-import.yaml"
echo "  Created rhdh-realm-import.yaml (domain=${CLUSTER_DOMAIN})"
echo ""

# -------------------------------------------------------------------
# Commit and push placeholder changes (secrets are gitignored)
# -------------------------------------------------------------------
echo "--- Committing placeholder changes ---"
cd "$SCRIPT_DIR"
git add -A
if ! git diff --cached --quiet; then
  git commit -m "Configure for cluster ${CLUSTER_DOMAIN}"
  git push
  echo "  Changes committed and pushed."
else
  echo "  No changes to commit (placeholders already populated)."
fi
echo ""

# -------------------------------------------------------------------
# Phase 0: Install OpenShift GitOps operator
# -------------------------------------------------------------------
echo "--- Phase 0: Installing OpenShift GitOps operator ---"

# Step 1: Install the operator subscription (CRDs don't exist yet)
oc apply -f "$SCRIPT_DIR/cluster-configs/gitops/gitops-operator.yaml"

echo "Waiting for GitOps operator CSV to succeed..."
until oc get csv -n openshift-gitops-operator 2>/dev/null | grep -q "openshift-gitops-operator.*Succeeded"; do
  echo "  ...waiting for GitOps operator CSV"
  sleep 15
done
echo "GitOps operator installed."

echo "Waiting for openshift-gitops namespace..."
until oc get namespace openshift-gitops &>/dev/null; do
  echo "  ...waiting for namespace"
  sleep 5
done

echo "Waiting for ArgoCD CRD..."
until oc wait --for=condition=Established crd/argocds.argoproj.io --timeout=10s 2>/dev/null; do
  echo "  ...waiting for ArgoCD CRD"
  sleep 10
done

# Step 2: Now apply the full gitops config (ArgoCD instance, RBAC, secret patch)
oc apply -k "$SCRIPT_DIR/cluster-configs/gitops/"

echo "Waiting for ArgoCD instance to be ready..."
until oc get argocd openshift-gitops -n openshift-gitops &>/dev/null; do
  echo "  ...waiting for ArgoCD CR"
  sleep 10
done

until oc get argocd openshift-gitops -n openshift-gitops \
  -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Available"; do
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
# Phase 2: Apply secrets to cluster
# -------------------------------------------------------------------
echo "--- Phase 2: Applying secrets to cluster ---"

oc create namespace keycloak --dry-run=client -o yaml | oc apply -f -
oc create namespace rhdh --dry-run=client -o yaml | oc apply -f -

oc apply -k "$SCRIPT_DIR/cluster-configs/keycloak/secrets/"
echo "  Keycloak secrets applied."

oc apply -k "$SCRIPT_DIR/cluster-configs/developer-hub/secrets/"
echo "  Developer Hub secrets applied."
echo ""

# -------------------------------------------------------------------
# Phase 3: Deploy app-of-apps (all ArgoCD Applications)
# -------------------------------------------------------------------
echo "--- Phase 3: Deploying ArgoCD Applications ---"
echo ""
echo "  Wave 1: keycloak, pipelines, quay"
echo "  Wave 2: dev-spaces, orchestrator"
echo "  Wave 3: developer-hub"
echo "  Wave 4: workflows"
echo ""
oc apply -k "$SCRIPT_DIR/applications/"
echo ""
echo "All ArgoCD Applications created. ArgoCD will now sync them."
echo ""

# -------------------------------------------------------------------
# Phase 4: Wait for Keycloak CRD and apply realm import
# -------------------------------------------------------------------
echo "--- Phase 4: Applying Keycloak realm import ---"

echo "Waiting for KeycloakRealmImport CRD..."
until oc wait --for=condition=Established \
  crd/keycloakrealmimports.k8s.keycloak.org --timeout=10s 2>/dev/null; do
  echo "  ...waiting for KeycloakRealmImport CRD"
  sleep 15
done

echo "Waiting for Keycloak instance to be ready..."
KEYCLOAK_WAIT=0
until oc get keycloak keycloak -n keycloak \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null \
  | grep -qi "true"; do
  echo "  ...waiting for Keycloak to become ready (${KEYCLOAK_WAIT}s)"
  sleep 20
  KEYCLOAK_WAIT=$((KEYCLOAK_WAIT + 20))
  if [[ $KEYCLOAK_WAIT -ge 600 ]]; then
    echo "  WARNING: Keycloak not ready after 10 minutes."
    echo "  Applying realm import anyway (it may reconcile once Keycloak is ready)."
    break
  fi
done

echo "Applying realm import..."
oc apply -f "$SCRIPT_DIR/cluster-configs/keycloak/rhdh-realm-import.yaml"
echo "Realm import applied."
echo ""

# -------------------------------------------------------------------
# Done
# -------------------------------------------------------------------
echo "============================================"
echo "  Bootstrap Complete!"
echo "============================================"
echo ""

ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "<pending>")
echo "  ArgoCD:   https://$ARGOCD_ROUTE"

echo ""
echo "Monitor progress:"
echo "  oc get applications -n openshift-gitops"
echo ""
echo "Once all applications are synced:"

RHDH_ROUTE=$(oc get route backstage-developer-hub -n rhdh \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "<not yet available>")
KEYCLOAK_ROUTE="sso.${APPS_DOMAIN}"
echo "  RHDH:     https://$RHDH_ROUTE"
echo "  Keycloak: https://$KEYCLOAK_ROUTE"
echo ""
echo "Default test users (Keycloak):"
echo "  admin / admin"
echo "  user1 / user1"
echo ""
