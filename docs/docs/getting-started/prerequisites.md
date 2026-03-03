# Prerequisites

## Cluster Requirements

- **OpenShift 4.14+** cluster with cluster-admin access
- **`oc` CLI** installed and logged in
- Sufficient cluster resources for all operators

## External Services

### GitHub

You need a GitHub App or Personal Access Token for catalog integration:

- **GitHub App** (recommended): Create at Settings > Developer Settings > GitHub Apps
  - Permissions: Contents (Read), Metadata (Read)
  - Generate a private key
- **Personal Access Token**: Settings > Developer Settings > Tokens
  - Scopes: `repo`, `read:org`

### Keycloak

Keycloak is deployed as part of this bootstrap. Default test users are created automatically:

| Username | Password | Groups |
|----------|----------|--------|
| admin | admin | rhdh-users |
| user1 | user1 | rhdh-users |

## Secrets Setup

Before deploying, you must create secret files from the provided examples:

1. `cluster-configs/keycloak/secrets/keycloak-db-secret.yaml`
2. `cluster-configs/developer-hub/secrets/keycloak-secrets.yaml`
3. `cluster-configs/developer-hub/secrets/rhdh-secrets.yaml`
4. `cluster-configs/developer-hub/secrets/argocd-secrets.yaml`
5. `cluster-configs/keycloak/rhdh-realm-import.yaml`

See the README files in each secrets directory for detailed instructions.
