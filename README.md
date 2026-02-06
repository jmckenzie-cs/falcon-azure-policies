# Azure Policy Deployment Guide for CrowdStrike Falcon Operator

This guide provides Azure Policy definitions to automatically deploy and manage CrowdStrike Falcon security components across your AKS clusters.

## 📋 Overview

The Azure Policy Initiative deploys:
1. **Falcon Operator** - Core controller managing all Falcon resources
2. **Falcon Node Sensor** - DaemonSet providing kernel-level protection on Linux nodes
3. **Falcon Admission Controller** - ValidatingWebhook enforcing security policies
4. **Falcon Image Analyzer** - Runtime image scanning and assessment
5. **Compliance Auditing** - Automated compliance reporting

## 🔄 How Azure Policies Work

The JSON files in this repository are **policy definition templates** that need to be deployed to Azure before they can enforce compliance:

1. **JSON Files** (this repo) → **Upload to Azure** as Policy Definitions
2. **Policy Definitions** → **Group together** as Policy Initiative
3. **Policy Initiative** → **Assign to scope** (subscription/resource group)
4. **Policy Assignment** → **Automatic deployment** across AKS clusters

## 🚀 Deployment Process

### Step 1: Clone this Repository

```bash
git clone https://github.com/jmckenzie-cs/falcon-azure-policies.git
cd falcon-azure-policies
```

### Step 2: Deploy Individual Policy Definitions

Upload each JSON file as an Azure Policy Definition:

```bash
# Set your management group or subscription scope
SCOPE_TYPE="management-group"  # or "subscription"
SCOPE_ID="your-management-group-id"  # or "your-subscription-id"

# Deploy Falcon Operator Policy
az policy definition create \
  --name "deploy-falcon-operator" \
  --display-name "Deploy Falcon Operator" \
  --description "Deploy CrowdStrike Falcon Operator to AKS clusters" \
  --rules @deploy-falcon-operator.json \
  --mode "Microsoft.Kubernetes.Data" \
  --${SCOPE_TYPE} ${SCOPE_ID}

# Deploy Node Sensor Policy
az policy definition create \
  --name "deploy-falcon-node-sensor" \
  --display-name "Deploy Falcon Node Sensor" \
  --description "Deploy Falcon Node Sensor DaemonSet for kernel protection" \
  --rules @deploy-falcon-node-sensor.json \
  --mode "Microsoft.Kubernetes.Data" \
  --${SCOPE_TYPE} ${SCOPE_ID}

# Deploy Admission Controller Policy
az policy definition create \
  --name "deploy-falcon-admission-controller" \
  --display-name "Deploy Falcon Admission Controller" \
  --description "Deploy Falcon Kubernetes Admission Controller for policy enforcement" \
  --rules @deploy-falcon-admission-controller.json \
  --mode "Microsoft.Kubernetes.Data" \
  --${SCOPE_TYPE} ${SCOPE_ID}

# Deploy Image Analyzer Policy
az policy definition create \
  --name "deploy-falcon-image-analyzer" \
  --display-name "Deploy Falcon Image Analyzer" \
  --description "Deploy Falcon Image Analyzer for runtime image scanning" \
  --rules @deploy-falcon-image-analyzer.json \
  --mode "Microsoft.Kubernetes.Data" \
  --${SCOPE_TYPE} ${SCOPE_ID}

# Deploy Compliance Audit Policy
az policy definition create \
  --name "audit-falcon-compliance" \
  --display-name "Audit Falcon Security Compliance" \
  --description "Audit compliance of CrowdStrike Falcon components" \
  --rules @audit-falcon-compliance.json \
  --mode "Microsoft.Kubernetes.Data" \
  --${SCOPE_TYPE} ${SCOPE_ID}
```

### Step 3: Create the Policy Initiative

First, update the `falcon-initiative.json` file to reference your actual management group or subscription:

```bash
# Update the policyDefinitionId paths in falcon-initiative.json
# Replace {managementGroupId} with your actual management group ID
# OR replace the path format for subscription scope

# For Management Group scope:
sed -i 's/{managementGroupId}/your-actual-mg-id/g' falcon-initiative.json

# For Subscription scope, replace the entire path pattern:
# "/providers/Microsoft.Authorization/policyDefinitions/policy-name"
```

Then create the initiative:

```bash
az policy set-definition create \
  --name "falcon-security-baseline" \
  --display-name "Falcon Security Baseline Initiative" \
  --description "Deploy and enforce CrowdStrike Falcon security across AKS clusters" \
  --definitions @falcon-initiative.json \
  --${SCOPE_TYPE} ${SCOPE_ID}
```

### Step 4: Assign the Policy Initiative

Now assign the initiative to your target scope with your specific parameters:

```bash
# Assign the initiative to your subscription/resource group
az policy assignment create \
  --name "falcon-security-assignment" \
  --display-name "Falcon Security Baseline Assignment" \
  --policy-set-definition "falcon-security-baseline" \
  --scope "/subscriptions/your-subscription-id" \
  --identity-scope "/subscriptions/your-subscription-id" \
  --location "East US" \
  --assign-identity \
  --params '{
    "falconClientId": {"value": "YOUR_FALCON_CLIENT_ID"},
    "falconClientSecretUri": {"value": "https://your-keyvault.vault.azure.net/secrets/falcon-client-secret"},
    "falconCloud": {"value": "autodiscover"},
    "updatePolicy": {"value": "platform_default"},
    "enableImageScanning": {"value": true},
    "admissionFailurePolicy": {"value": "Fail"}
  }'
```

### Step 5: Grant Key Vault Access

Grant the policy assignment's managed identity access to your Key Vault:

```bash
# Get the policy assignment's managed identity
POLICY_IDENTITY=$(az policy assignment show \
  --name "falcon-security-assignment" \
  --scope "/subscriptions/your-subscription-id" \
  --query identity.principalId -o tsv)

# Grant Key Vault access
az keyvault set-policy \
  --name "your-keyvault" \
  --object-id $POLICY_IDENTITY \
  --secret-permissions get list
```

### Step 6: Verify Deployment

```bash
# Check policy compliance
az policy state list --policy-assignment "falcon-security-assignment"

# Verify Falcon components in AKS (after policies deploy)
az aks get-credentials --resource-group myRG --name myAKS
kubectl get pods -n falcon-operator
kubectl get falconnodesensor -A
kubectl get falconadmission -A
kubectl get falconimageanalyzer -A
```

## ⚡ Quick Deployment Script

For automated deployment, you can use this all-in-one script:

```bash
#!/bin/bash
set -e

# Configuration
SCOPE_TYPE="subscription"  # Policy definitions must be at subscription or mg level
SCOPE_ID="your-subscription-id"  # or management group ID
RESOURCE_GROUP="your-resource-group"  # Optional: for resource group scoping
FALCON_CLIENT_ID="YOUR_FALCON_CLIENT_ID"
KEYVAULT_URI="https://your-keyvault.vault.azure.net/secrets/falcon-client-secret"

echo "🚀 Deploying Falcon Azure Policies..."

# Deploy all policy definitions
policies=("deploy-falcon-operator" "deploy-falcon-node-sensor" "deploy-falcon-admission-controller" "deploy-falcon-image-analyzer" "audit-falcon-compliance")
for policy in "${policies[@]}"; do
  echo "📋 Creating policy: $policy"
  az policy definition create \
    --name "$policy" \
    --display-name "$(echo $policy | sed 's/-/ /g' | sed 's/\b\w/\U&/g')" \
    --description "Auto-deployed Falcon policy: $policy" \
    --rules @${policy}.json \
    --mode "Microsoft.Kubernetes.Data" \
    --${SCOPE_TYPE} ${SCOPE_ID}
done

# Update initiative with correct scope
if [ "$SCOPE_TYPE" = "management-group" ]; then
  sed -i "s/{managementGroupId}/${SCOPE_ID}/g" falcon-initiative.json
else
  # For subscription scope, update the path format
  sed -i 's|/providers/Microsoft.Management/managementGroups/{managementGroupId}/providers/Microsoft.Authorization/policyDefinitions/|/providers/Microsoft.Authorization/policyDefinitions/|g' falcon-initiative.json
fi

# Create policy initiative
echo "📦 Creating policy initiative..."
az policy set-definition create \
  --name "falcon-security-baseline" \
  --display-name "Falcon Security Baseline Initiative" \
  --description "Deploy CrowdStrike Falcon security across AKS clusters" \
  --definitions @falcon-initiative.json \
  --${SCOPE_TYPE} ${SCOPE_ID}

# Assign the initiative
echo "🎯 Assigning policy initiative..."

# Determine scope for assignment
if [ -n "$RESOURCE_GROUP" ]; then
  ASSIGNMENT_SCOPE="/subscriptions/${SCOPE_ID}/resourceGroups/${RESOURCE_GROUP}"
  echo "   📍 Scoping to Resource Group: ${RESOURCE_GROUP}"
else
  ASSIGNMENT_SCOPE="/subscriptions/${SCOPE_ID}"
  echo "   📍 Scoping to Subscription: ${SCOPE_ID}"
fi

az policy assignment create \
  --name "falcon-security-assignment" \
  --display-name "Falcon Security Baseline Assignment" \
  --policy-set-definition "falcon-security-baseline" \
  --scope "${ASSIGNMENT_SCOPE}" \
  --identity-scope "${ASSIGNMENT_SCOPE}" \
  --location "East US" \
  --assign-identity \
  --params "{
    \"falconClientId\": {\"value\": \"${FALCON_CLIENT_ID}\"},
    \"falconClientSecretUri\": {\"value\": \"${KEYVAULT_URI}\"},
    \"falconCloud\": {\"value\": \"autodiscover\"},
    \"updatePolicy\": {\"value\": \"platform_default\"},
    \"enableImageScanning\": {\"value\": true},
    \"admissionFailurePolicy\": {\"value\": \"Fail\"}
  }"

# Grant Key Vault access
echo "🔑 Granting Key Vault access..."
POLICY_IDENTITY=$(az policy assignment show \
  --name "falcon-security-assignment" \
  --scope "${ASSIGNMENT_SCOPE}" \
  --query identity.principalId -o tsv)

az keyvault set-policy \
  --name "$(echo ${KEYVAULT_URI} | cut -d'/' -f3 | cut -d'.' -f1)" \
  --object-id $POLICY_IDENTITY \
  --secret-permissions get list

echo "✅ Falcon Azure Policies deployed successfully!"
echo "📊 Check compliance: az policy state list --policy-assignment falcon-security-assignment"
```

Save this script as `deploy-policies.sh`, make it executable (`chmod +x deploy-policies.sh`), and run it after updating the configuration variables.

## 🎯 Resource Group Scoping

**Preferred Approach**: You can scope the policy assignment to a specific resource group for more granular control:

```bash
#!/bin/bash
set -e

# Configuration for Resource Group Scoping
SCOPE_TYPE="subscription"  # Policy definitions must be at subscription level
SCOPE_ID="your-subscription-id"
RESOURCE_GROUP="your-target-resource-group"  # Set this for RG scoping
FALCON_CLIENT_ID="YOUR_FALCON_CLIENT_ID"
KEYVAULT_URI="https://your-keyvault.vault.azure.net/secrets/falcon-client-secret"

# The script will automatically assign policies to the resource group
# if RESOURCE_GROUP is set, otherwise it assigns to the subscription
```

### **Benefits of Resource Group Scoping:**
- ✅ **Granular Control**: Only affects AKS clusters in that specific resource group
- ✅ **Environment Isolation**: Separate policies for dev/staging/prod resource groups
- ✅ **Reduced Blast Radius**: Limits impact to specific resources
- ✅ **Easier Management**: Clear boundaries for different teams/projects

### **Manual Resource Group Assignment:**

For manual deployment, modify Step 4 to target your resource group:

```bash
# Assign the initiative to your RESOURCE GROUP
az policy assignment create \
  --name "falcon-security-assignment" \
  --display-name "Falcon Security Baseline Assignment" \
  --policy-set-definition "falcon-security-baseline" \
  --scope "/subscriptions/your-subscription-id/resourceGroups/your-resource-group" \
  --identity-scope "/subscriptions/your-subscription-id/resourceGroups/your-resource-group" \
  --location "East US" \
  --assign-identity \
  --params '{
    "falconClientId": {"value": "YOUR_FALCON_CLIENT_ID"},
    "falconClientSecretUri": {"value": "https://your-keyvault.vault.azure.net/secrets/falcon-client-secret"},
    "falconCloud": {"value": "autodiscover"},
    "updatePolicy": {"value": "platform_default"},
    "enableImageScanning": {"value": true},
    "admissionFailurePolicy": {"value": "Fail"}
  }'
```

## 🚀 Prerequisites

1. **Azure Resource Group** (required for Key Vault and other resources):
   ```bash
   # Create resource group if it doesn't exist
   az group create --name "mckenzie-rg" --location "eastus"
   ```

2. **Azure Key Vault** with your Falcon API credentials:
   ```bash
   # Create Key Vault (requires resource group)
   az keyvault create \
     --name "mckenzie-keyvault" \
     --resource-group "mckenzie-rg" \
     --location "eastus"

   # Create Key Vault secret for Falcon client secret
   az keyvault secret set --vault-name "mckenzie-keyvault" \
     --name "falcon-client-secret" \
     --value "YOUR_FALCON_CLIENT_SECRET"
   ```

3. **AKS Cluster** with:
   - Linux node pools
   - Azure Monitor enabled
   - Managed identity with Key Vault access

## 📋 Post-Deployment Verification

After running the deployment script or manual steps above, verify that everything is working:

```bash
# Check policy compliance
az policy state list --policy-assignment "falcon-security-assignment"

# Verify Falcon components in AKS
az aks get-credentials --resource-group myRG --name myAKS
kubectl get pods -n falcon-operator
kubectl get falconnodesensor -A
kubectl get falconadmission -A
kubectl get falconimageanalyzer -A
```

## 📁 Policy Files

| File | Description |
|------|-------------|
| **falcon-initiative.json** | Main policy initiative grouping all Falcon policies |
| **deploy-falcon-operator.json** | Deploys the Falcon Operator controller |
| **deploy-falcon-node-sensor.json** | Deploys Node Sensor DaemonSet for kernel protection |
| **deploy-falcon-admission-controller.json** | Deploys Admission Controller ValidatingWebhook |
| **deploy-falcon-image-analyzer.json** | Deploys Image Analyzer for runtime scanning |
| **audit-falcon-compliance.json** | Audits compliance across all Falcon components |

## 🔧 Configuration Parameters

### Required Parameters
- **falconClientId**: Your Falcon API Client ID (e.g., `abcd1234-5678-90ef-ghij-klmnopqrstuv`)
- **falconClientSecretUri**: Key Vault URI for your Falcon Client Secret

### Optional Parameters
- **falconCloud**: Falcon cloud region (`autodiscover`, `us-1`, `us-2`, `eu-1`, `us-gov-1`)
- **updatePolicy**: Falcon Console update policy name (`platform_default`)
- **enableImageScanning**: Enable runtime image scanning (`true`/`false`)
- **admissionFailurePolicy**: Webhook failure behavior (`Fail`/`Ignore`)

## 🎯 Deployment Sequence

The policies deploy components in this order:

1. **Falcon Operator** deployed to `falcon-operator` namespace
2. **API Secrets** created in respective namespaces from Key Vault
3. **Node Sensor** deployed as DaemonSet in `falcon-system` namespace
4. **Admission Controller** deployed with ValidatingWebhook in `falcon-kac` namespace
5. **Image Analyzer** deployed for runtime scanning in `falcon-iar` namespace
6. **Compliance Audit** runs continuously to verify all components

## 📊 Compliance Monitoring

The audit policy checks:
- ✅ Falcon Operator deployment status
- ✅ Node Sensor existence and readiness
- ✅ Admission Controller webhook configuration
- ✅ Image Analyzer deployment (optional)
- ✅ ACR registry usage compliance
- ✅ Namespace security labeling

View compliance in the Azure Policy portal or via CLI:
```bash
az policy state list --policy-assignment "falcon-security-assignment" --filter "ComplianceState eq 'NonCompliant'"
```

## 🔒 Security Features

### Node-Level Protection
- Kernel-level threat detection via eBPF
- Real-time behavioral monitoring
- Custom hash and IOA blocking

### Runtime Scanning
- Continuous container image assessment
- Registry credential auto-discovery
- Exclusion lists for system namespaces

### Key Benefits
- ✅ **Always latest images** - Direct from CrowdStrike registry
- ✅ **Simpler configuration** - No registry management required
- ✅ **Automatic updates** - Falcon's update policies work seamlessly
- ✅ **Reduced complexity** - Fewer moving parts to maintain

## 🚨 Troubleshooting

### Common Issues

1. **Key Vault Access Denied**
   ```bash
   # Verify managed identity has access
   az keyvault show-deleted-vault --name your-keyvault
   az keyvault set-policy --name your-keyvault --object-id $POLICY_IDENTITY --secret-permissions get
   ```

2. **Webhook Certificate Issues**
   ```bash
   # Check webhook configuration
   kubectl get validatingwebhookconfiguration falcon-kac-admission -o yaml
   ```

4. **Node Sensor Not Starting**
   ```bash
   # Check privileged pod security
   kubectl describe daemonset falcon-node-sensor -n falcon-system
   ```

### Policy Remediation

Policies automatically remediate non-compliance through:
- **DeployIfNotExists**: Creates missing resources
- **Audit**: Reports compliance violations
- **Background Tasks**: Continuous monitoring and correction

## 📈 Monitoring & Alerting

Set up Azure Monitor alerts for:
- Policy compliance state changes
- Falcon component health status
- Security violation events
- Update policy compliance

```bash
# Create alert rule for non-compliance
az monitor metrics alert create \
  --name "falcon-non-compliance" \
  --resource-group myRG \
  --condition "count PolicyStates_s | where ComplianceState_s == 'NonCompliant'" \
  --description "Alert when Falcon policies are non-compliant"
```

---

**🛡️ Enterprise Security at Scale**

This Azure Policy approach provides:
- **Declarative Security**: Infrastructure-as-code for security controls
- **Automated Compliance**: Continuous monitoring and remediation
- **Centralized Management**: Single pane of glass across all AKS clusters
- **Native Integration**: Seamless Azure Key Vault and ACR integration
- **Audit Trail**: Complete compliance reporting and evidence

Deploy once, secure everywhere! 🚀