# Platform Documentation

Welcome to the Developer Hub platform documentation. This guide covers everything you need to know about using Red Hat Developer Hub on OpenShift.

## What is Developer Hub?

Red Hat Developer Hub (RHDH) is an enterprise-grade developer portal based on Backstage. It provides:

- **Software Catalog**: Track all your services, libraries, and infrastructure
- **Software Templates**: Self-service scaffolding for new projects
- **TechDocs**: Documentation as code
- **Plugins**: Extensible architecture for custom functionality

## Quick Links

| Resource | Description |
|----------|-------------|
| [Getting Started](getting-started/overview.md) | Platform overview and first steps |
| [Prerequisites](getting-started/prerequisites.md) | What you need before deploying |
| [Orchestrator Workflows](orchestrator/workflows.md) | Serverless workflow automation |

## Platform Components

```
┌─────────────────────────────────────────────────────────────┐
│                   Red Hat Developer Hub                      │
├─────────────────────────────────────────────────────────────┤
│  Catalog  │  Templates  │  TechDocs  │  Orchestrator        │
├─────────────────────────────────────────────────────────────┤
│                      OpenShift                               │
│     (Kubernetes, Routes, Dev Spaces, GitOps)                 │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### Self-Service Development

Developers can create new applications without waiting for platform teams:

1. Choose a software template
2. Fill in the required parameters
3. Get a fully configured repository with CI/CD

### Cloud Development Environments

OpenShift Dev Spaces provides cloud-based development environments:

- Pre-configured with all dependencies
- Accessible from any browser
- Consistent across the team

### Serverless Workflows

The Orchestrator plugin integrates SonataFlow workflows for automated infrastructure provisioning and operations.

## Getting Help

- **Platform Team**: Contact the platform team for infrastructure issues
- **Documentation**: Check the relevant section in this guide
- **Community**: Backstage community resources at [backstage.io](https://backstage.io)
