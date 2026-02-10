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

## Next Steps

1. Review `policies.bicep` - contains all policy definitions
2. Customize `assignment.bicep` with your parameters
3. Deploy with the commands above
4. Monitor in Azure Portal → Policy

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
