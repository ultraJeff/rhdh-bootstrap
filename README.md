# RHDH Bootstrap

Bootstrap configuration for Red Hat Developer Hub (RHDH) on OpenShift with GitOps, Keycloak SSO, Dev Spaces, Orchestrator, Pipelines, and Quay.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       OpenShift Cluster                          │
│                                                                  │
│  ┌───────────────┐   ┌──────────────┐   ┌────────────────────┐  │
│  │  OpenShift    │   │   Keycloak   │   │  Red Hat Developer │  │
│  │  GitOps       │   │  (RHBK 26)   │──►│      Hub 1.8       │  │
│  │  (ArgoCD)     │   └──────────────┘   └────────────────────┘  │
│  └───────┬───────┘          │                     │              │
│          │             PostgreSQL            PostgreSQL           │
│    Manages all              │                     │              │
│    applications        ┌────┴─────┐         ┌────┴───────────┐  │
│          │             │          │         │                 │  │
│  ┌───────┴───────┐  ┌──┴───┐  ┌──┴──┐  ┌──┴──────────────┐  │  │
│  │  Pipelines    │  │ Dev  │  │Quay │  │  Orchestrator    │  │  │
│  │  (Tekton)     │  │Spaces│  │     │  │  (SonataFlow)    │  │  │
│  └───────────────┘  └──────┘  └─────┘  └─────────────────┘  │  │
└──────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Description |
|-----------|-------------|
| **OpenShift GitOps** | ArgoCD for GitOps-driven cluster management |
| **Red Hat Developer Hub** | Enterprise developer portal (Backstage) |
| **Keycloak (RHBK)** | SSO/Identity provider with OIDC |
| **OpenShift Pipelines** | Tekton-based CI/CD pipelines |
| **Quay** | Container image registry |
| **Dev Spaces** | Cloud-based development environments |
| **Orchestrator** | Serverless workflow engine (SonataFlow) |

## Directory Structure

```
rhdh-bootstrap/
├── init.sh                    # Bootstrap script (start here)
├── applications/              # ArgoCD Application manifests (app-of-apps)
│   ├── keycloak.yaml         #   Wave 1 - operators
│   ├── pipelines.yaml        #   Wave 1
│   ├── quay.yaml             #   Wave 1
│   ├── dev-spaces.yaml       #   Wave 2
│   ├── orchestrator.yaml     #   Wave 2
│   └── developer-hub.yaml    #   Wave 3 - depends on all above
├── cluster-configs/           # Cluster bootstrap configurations
│   ├── gitops/               # OpenShift GitOps (ArgoCD)
│   ├── security/             # htpasswd auth, admin RBAC
│   ├── pipelines/            # OpenShift Pipelines operator
│   ├── quay/                 # Quay operator
│   ├── keycloak/             # Keycloak operator, instance, realm
│   ├── developer-hub/        # RHDH operator, instance, plugins
│   ├── dev-spaces/           # Dev Spaces operator and CheCluster
│   └── orchestrator/         # Serverless + Logic + Orchestrator operators
├── workflows/                 # SonataFlow workflow definitions
└── docs/                      # TechDocs documentation
```

## Bootstrap Order (Sync Waves)

The init script and ArgoCD sync waves ensure components deploy in the right order:

```
Phase 0 (init.sh)         Phase 1 (Wave 1)       Phase 2 (Wave 2)       Phase 3 (Wave 3)
┌──────────────────┐      ┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  GitOps Operator │─────►│  Keycloak     │─────►│  Dev Spaces   │─────►│  Developer    │
│  ArgoCD Instance │      │  Pipelines    │      │  Orchestrator │      │    Hub        │
│  Security        │      │  Quay         │      │               │      │               │
└──────────────────┘      └───────────────┘      └───────────────┘      └───────────────┘
     (manual)               (auto-sync)            (auto-sync)            (auto-sync)
```

## Prerequisites

- OpenShift 4.14+ cluster
- `oc` CLI logged in as cluster-admin
- GitHub App or PAT for catalog integration

## Quick Start

### 1. Run the bootstrap script

```bash
./init.sh
```

This will:
1. Install the OpenShift GitOps operator and wait for ArgoCD
2. Apply security configs (htpasswd, admin RBAC)
3. Prompt you to create secrets
4. Deploy all ArgoCD Applications with sync wave ordering

### 2. Create Secrets (when prompted)

```bash
# Keycloak DB secret
cd cluster-configs/keycloak/secrets
cp keycloak-db-secret.yaml.example keycloak-db-secret.yaml
# Edit with your credentials
oc apply -k .

# Developer Hub secrets
cd ../../developer-hub/secrets
cp keycloak-secrets.yaml.example keycloak-secrets.yaml
cp rhdh-secrets.yaml.example rhdh-secrets.yaml
cp argocd-secrets.yaml.example argocd-secrets.yaml
# Edit each file with your values
oc apply -k .
```

### 3. Post-deploy: Keycloak Realm Import

```bash
# Wait for Keycloak operator
oc wait --for=condition=Established crd/keycloaks.k8s.keycloak.org --timeout=300s

# Create and apply realm import
cp cluster-configs/keycloak/rhdh-realm-import.yaml.example \
   cluster-configs/keycloak/rhdh-realm-import.yaml
# Edit: set client secret and cluster domain
oc apply -f cluster-configs/keycloak/rhdh-realm-import.yaml
```

### 4. Post-deploy: Orchestrator Workflows

```bash
# After SonataFlow operators are ready
oc apply -k workflows/
```

### 5. Access

```bash
# RHDH URL
oc get route backstage-developer-hub -n rhdh -o jsonpath='{.spec.host}'

# Keycloak URL
oc get route -n keycloak -o jsonpath='{.items[0].spec.host}'

# ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
```

## Default Test Users (Keycloak)

| Username | Password | Groups |
|----------|----------|--------|
| admin | admin | rhdh-users |
| user1 | user1 | rhdh-users |

## Enabled Plugins

- **Keycloak** - User/group sync from Keycloak
- **GitHub** - Catalog provider and org discovery
- **Kubernetes** - K8s resource viewing
- **Topology** - Visual topology view
- **ArgoCD** - GitOps integration
- **RBAC** - Role-based access control
- **Quay** - Container image registry integration
- **Orchestrator** - Serverless workflow management
- **Notifications** - Event notifications (required by Orchestrator)

## Customization

### Update Cluster Domain

Replace hostnames in these files:
- `cluster-configs/keycloak/keycloak-instance.yaml` - `spec.hostname.hostname`
- `cluster-configs/keycloak/rhdh-realm-import.yaml` - `redirectUris` and `webOrigins`
- `cluster-configs/developer-hub/secrets/keycloak-secrets.yaml` - `KEYCLOAK_BASE_URL`
- `cluster-configs/developer-hub/secrets/argocd-secrets.yaml` - `ARGOCD_URL`
- `cluster-configs/developer-hub/secrets/rhdh-secrets.yaml` - `BACKEND_URL`

### Update Git Repo URL

Replace `<YOUR_ORG>` in all `applications/*.yaml` files with your GitHub org/user:
```bash
sed -i '' 's|<YOUR_ORG>|your-org|g' applications/*.yaml
```

### Disable/Enable Plugins

Edit `cluster-configs/developer-hub/dynamic-plugins.yaml`:
```yaml
plugins:
  - package: ./dynamic-plugins/dist/plugin-name
    disabled: true  # or false
```

## Troubleshooting

### RHDH Pod CrashLoopBackOff

```bash
oc logs -l app.kubernetes.io/name=backstage -n rhdh -c backstage-backend
```

Common issues:
- **Missing secrets**: Ensure all secrets are applied before deploying RHDH
- **ENOTFOUND**: Check Keycloak URL is reachable from the RHDH pod
- **MigrationLocked**: Clear the DB lock:
  ```bash
  oc exec backstage-psql-developer-hub-0 -n rhdh -- psql -d backstage_plugin_catalog -c "UPDATE knex_migrations_lock SET is_locked = 0;"
  ```

### ArgoCD Application stuck

```bash
oc get applications -n openshift-gitops
oc describe application <app-name> -n openshift-gitops
```

### Keycloak Not Ready

```bash
oc get keycloak -n keycloak
oc logs keycloak-0 -n keycloak
```

## References

- [RHDH 1.8 Documentation](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.8)
- [RHDH Plugins Catalog](https://developers.redhat.com/rhdh/plugins)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/understanding_openshift_gitops/about-redhat-openshift-gitops.html)
- [Dev Spaces Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_dev_spaces)
- [OpenShift Pipelines Documentation](https://docs.openshift.com/pipelines/latest/about/about-pipelines.html)
