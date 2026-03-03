# Orchestrator Workflows

The Orchestrator plugin integrates SonataFlow serverless workflows into Developer Hub.

## Available Workflows

### Utility Rate Report

Generates a utility rate report for a specified city based on current weather conditions and utility rates.

**Input Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `city` | Yes | City to generate the report for (new-york, london, tokyo, sydney, paris) |
| `requestedBy` | No | Name or ID of the person requesting the report |

**Workflow Steps:**

1. Fetch weather data for the selected city
2. Fetch current utility rates
3. Generate a formatted report
4. Return completion status

### Provision Utility Monitor

Provisions a new utility monitoring service for a specific city.

**Input Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `serviceName` | Yes | Name for the new monitoring service |
| `city` | Yes | City to monitor |
| `namespace` | Yes | Kubernetes namespace to deploy to |
| `owner` | No | Backstage entity reference (default: user:default/admin) |
| `alertThreshold` | No | Rate increase percentage that triggers an alert (default: 25) |

**Workflow Steps:**

1. Validate input parameters
2. Fetch initial weather and rate data
3. Log provisioning details
4. Complete provisioning

## Deploying Workflows

Workflows require the Orchestrator operators to be installed first:

```bash
# Install operators
oc apply -k cluster-configs/orchestrator/

# Wait for operators to be ready
oc get csv -n openshift-serverless
oc get csv -n openshift-serverless-logic

# Deploy workflows
oc apply -k workflows/
```

## Prerequisites

- OpenShift Serverless operator (Knative)
- OpenShift Serverless Logic operator (SonataFlow)
- `sonataflow-platform-data-index-service` must be available in the RHDH namespace
