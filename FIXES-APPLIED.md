# Fixes Applied to Deploy Falcon Operator Policy

## Issue
The "Deploy Falcon Operator" Azure Policy remediation task was not executing because of an incorrect `existenceCondition` that was checking for the OMS agent addon instead of the Falcon Operator deployment.

## Root Cause
The policy had this problematic condition:
```json
"existenceCondition": {
  "field": "Microsoft.ContainerService/managedClusters/addonProfiles.omsagent.enabled",
  "equals": "true"
}
```

This meant the policy would only trigger if:
1. The resource is an AKS cluster AND
2. The OMS agent (Azure Monitor) addon is enabled

If the OMS agent wasn't enabled, the remediation would never run.

## Changes Made

### 1. Fixed the Existence Condition
- **Changed `type`** from `Microsoft.ContainerService/managedClusters` to `Microsoft.Resources/deploymentScripts`
- **Removed** the incorrect `existenceCondition` checking for OMS agent
- **Added `name`** field to properly identify the deployment script

### 2. Added Additional RBAC Role
- Added `Azure Kubernetes Service RBAC Writer` role (ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8)
- This ensures the deployment script has sufficient permissions to deploy to AKS

### 3. Added Managed Identity
- Added `UserAssigned` managed identity reference to the deployment script
- References: `falcon-policy-identity` (must be created separately)

### 4. Improved Deployment Script
- Added detailed logging for troubleshooting
- Added idempotency check (exits gracefully if already deployed)
- Added better error handling with descriptive output on failure
- Fixed variable reference (removed `$(echo ...)` wrapper)

## Files Updated
- `deploy-falcon-operator.json` - Main policy definition
- `deploy-falcon-operator-rule.json` - Policy rule file

## Next Steps

### 1. Create the Managed Identity (if not exists)
```bash
az identity create \
  --name falcon-policy-identity \
  --resource-group <your_resource_group>
```

### 2. Assign Required Permissions
```bash
# Get the identity principal ID
IDENTITY_ID=$(az identity show \
  --name falcon-policy-identity \
  --resource-group <your_resource_group> \
  --query principalId -o tsv)

# Assign Contributor role on AKS clusters
az role assignment create \
  --assignee $IDENTITY_ID \
  --role "Contributor" \
  --scope /subscriptions/<subscription_id>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<cluster_name>

# Assign AKS RBAC Writer
az role assignment create \
  --assignee $IDENTITY_ID \
  --role "Azure Kubernetes Service RBAC Writer" \
  --scope /subscriptions/<subscription_id>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<cluster_name>
```

### 3. Update the Policy in Azure
```bash
# Update the policy definition
az policy definition update \
  --name "deploy-falcon-operator" \
  --rules deploy-falcon-operator-rule.json \
  --params deploy-falcon-operator-params.json

# Or redeploy completely
./deploy-policies.sh
```

### 4. Create a New Remediation Task
```bash
az policy remediation create \
  --name "remediate-falcon-operator-$(date +%s)" \
  --policy-assignment <assignment_id> \
  --resource-group <your_resource_group>
```

### 5. Monitor the Remediation
```bash
# Check remediation status
az policy remediation show \
  --name "remediate-falcon-operator-<timestamp>" \
  --resource-group <your_resource_group>

# View deployment script logs
az deployment-scripts show-log \
  --resource-group <your_resource_group> \
  --name deploy-falcon-operator
```

## Validation
After remediation completes, verify the Falcon Operator is running:
```bash
kubectl get pods -n falcon-operator
kubectl get deployment falcon-operator-controller-manager -n falcon-operator
```

Expected output:
```
NAME                                              READY   STATUS    RESTARTS   AGE
falcon-operator-controller-manager-xxxxx-xxxxx    2/2     Running   0          2m
```
