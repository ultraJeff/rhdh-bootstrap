# Overview

Red Hat Developer Hub (RHDH) is deployed on OpenShift with the following integrated components:

## Architecture

| Component | Purpose |
|-----------|---------|
| **OpenShift GitOps (ArgoCD)** | GitOps-driven cluster management |
| **Red Hat Developer Hub** | Developer portal with software catalog, templates, and plugins |
| **Keycloak (RHBK)** | Single Sign-On with OIDC authentication |
| **Dev Spaces** | Cloud-based development environments |
| **Orchestrator (SonataFlow)** | Serverless workflow engine |

## How It Works

1. **GitOps Bootstrap**: ArgoCD manages cluster configuration from this Git repository
2. **Identity Management**: Keycloak provides OIDC-based SSO for Developer Hub
3. **Developer Portal**: RHDH offers a unified interface for software catalog, templates, and platform tools
4. **Cloud IDEs**: Dev Spaces enables browser-based development with pre-configured environments
5. **Automation**: The Orchestrator plugin runs SonataFlow workflows for infrastructure operations

## Enabled Plugins

- Keycloak user/group sync
- GitHub catalog discovery
- Kubernetes resource viewing
- Topology visualization
- ArgoCD GitOps integration
- RBAC (Role-Based Access Control)
- Orchestrator (SonataFlow workflows)
- Notifications and Signals
