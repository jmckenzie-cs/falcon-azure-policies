# Azure Policy Deployment with Bicep

This simplified approach uses Bicep to define and deploy all Azure Policies for CrowdStrike Falcon.

## Benefits of Bicep Approach

✅ **Single file** instead of 15+ JSON files
✅ **No split files needed** - Bicep handles the structure
✅ **Type checking** and validation built-in
✅ **Cleaner syntax** - easier to read and maintain
✅ **Version control friendly** - better diffs
✅ **Modular** - can split into modules if needed

## Quick Start

### 1. Deploy All Policies

```bash
# Deploy all policy definitions to your subscription
az deployment sub create \
  --name falcon-policies-deployment \
  --location eastus \
  --template-file policies.bicep
```

That's it! This single command replaces all the individual policy creation commands.

### 2. Deploy the Policy Initiative

```bash
# Deploy the policy initiative (groups all policies together)
az deployment sub create \
  --name falcon-initiative-deployment \
  --location eastus \
  --template-file initiative.bicep
```

### 3. Assign the Initiative to a Resource Group

```bash
# Assign to your resource group (this targets only AKS clusters in this RG)
az deployment group create \
  --name falcon-assignment-deployment \
  --resource-group YOUR_RESOURCE_GROUP \
  --template-file assignment.bicep \
  --parameters falconClientId='YOUR_CLIENT_ID' \
               keyVaultName='YOUR_KEYVAULT_NAME' \
               keyVaultResourceGroup='YOUR_KEYVAULT_RG' \
               keyVaultSecretName='falcon-client-secret'
```

**Resource Group Scoping Benefits:**
- Only affects AKS clusters in the specified resource group
- Better isolation between environments (dev/staging/prod)
- Easier to manage and test policy rollouts
- Manual control via AuditIfNotExists (default)

## Files Structure

```
azure-policies/
├── policies.bicep          # All policy definitions
├── initiative.bicep        # Policy initiative (grouping)
├── assignment.bicep        # Policy assignment (resource group scoped)
├── keyvault-access.bicep   # Helper module for Key Vault permissions
└── README-BICEP.md         # This file
```

## Alternative: All-in-One Deployment

Create a main.bicep that orchestrates everything:

```bash
az deployment sub create \
  --name falcon-complete-deployment \
  --location eastus \
  --template-file main.bicep \
  --parameters @parameters.json
```

## Updating Policies

Just edit the Bicep file and redeploy:

```bash
az deployment sub create \
  --name falcon-policies-deployment \
  --location eastus \
  --template-file policies.bicep
```

## Comparing Approaches

### Old Way (JSON + CLI):
- 15+ JSON files
- Split -rule.json and -params.json files
- Multiple CLI commands
- Hard to track what's deployed
- Manual parameter handling

### New Way (Bicep):
- 3 Bicep files
- Single deployment command per stage
- Built-in validation
- Deployment history in Azure
- Parameters file for configuration

## Understanding Compliance Status

**IMPORTANT:** The compliance status shown in Azure Portal is **NOT** an accurate indicator of whether Falcon is actually deployed in your clusters.

### What the Compliance Status Actually Means

All policies will show **Non-compliant** by default because they check for tags that don't exist on your AKS clusters:

| Policy | Checks For | Default Status |
|--------|-----------|----------------|
| Falcon Operator | `tags['falcon-operator-deployed'] == 'true'` | Non-compliant |
| Node Sensor | `tags['falcon-node-sensor-deployed'] == 'true'` | Non-compliant |
| Admission Controller | `tags['falcon-admission-deployed'] == 'true'` | Non-compliant |
| Image Analyzer | `tags['falcon-image-analyzer-deployed'] == 'true'` | Non-compliant |
| Compliance Audit | `tags['falcon-compliance-audited'] == 'true'` | Non-compliant |

### Why It's This Way

- Azure Policy can only check **Azure resource properties** (like tags)
- It **cannot** see inside Kubernetes to verify actual pod deployments
- Non-compliant status enables you to create **remediation tasks**
- Remediation tasks trigger the deployment scripts that install Falcon

### How to Actually Deploy Falcon

1. **Wait for policies to show Non-compliant** (5-10 minutes after assignment)
2. **Go to Azure Portal** → Policy → Remediation
3. **Create remediation task** for each policy
4. **Select which clusters** to remediate
5. **Verify deployment** with kubectl:
   ```bash
   kubectl get pods -n falcon-operator
   kubectl get falconnodesensor -A
   kubectl get falconadmission -A
   kubectl get falconimageanalyzer -A
   ```

### Recommended Verification Approach

Don't rely on Azure Policy compliance status. Instead, use:
- **kubectl** to verify actual deployments
- **Azure Monitor Container Insights** for ongoing monitoring
- **Manual remediation tasks** to control when/where Falcon deploys

## Next Steps

1. Review [policies.bicep](policies.bicep) - contains all policy definitions
2. Customize [assignment.bicep](assignment.bicep) with your parameters
3. Deploy with the commands above
4. Wait 5-10 minutes for compliance evaluation
5. Create remediation tasks in Azure Portal
6. Verify deployment with kubectl

## Troubleshooting

View deployment status:
```bash
az deployment sub show --name falcon-policies-deployment
```

List deployed policies:
```bash
az policy definition list --query "[?contains(name, 'falcon')].{Name:name, DisplayName:displayName}" -o table
```

Delete all policies (cleanup):
```bash
az policy definition delete --name deploy-falcon-operator
az policy definition delete --name deploy-falcon-node-sensor
# ... etc
```
