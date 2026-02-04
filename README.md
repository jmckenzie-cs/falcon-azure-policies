# Azure Policy Deployment Guide for CrowdStrike Falcon Operator

This guide provides Azure Policy definitions to automatically deploy and manage CrowdStrike Falcon security components across your AKS clusters.

## 📋 Overview

The Azure Policy Initiative deploys:
1. **Falcon Operator** - Core controller managing all Falcon resources
2. **Falcon Node Sensor** - DaemonSet providing kernel-level protection on Linux nodes
3. **Falcon Admission Controller** - ValidatingWebhook enforcing security policies
4. **Falcon Image Analyzer** - Runtime image scanning and assessment
5. **Compliance Auditing** - Automated compliance reporting

## 🚀 Quick Start

### Prerequisites

1. **Azure Key Vault** with your Falcon API credentials:
   ```bash
   # Create Key Vault secret for Falcon client secret
   az keyvault secret set --vault-name "your-keyvault" \
     --name "falcon-client-secret" \
     --value "YOUR_FALCON_CLIENT_SECRET"
   ```

2. **AKS Cluster** with:
   - Linux node pools
   - Azure Monitor enabled
   - Managed identity with Key Vault access

### Step 1: Deploy Policy Initiative

```bash
# Create the policy initiative
az policy set-definition create \
  --name "falcon-security-baseline" \
  --display-name "Falcon Security Baseline Initiative" \
  --description "Deploy CrowdStrike Falcon security across AKS clusters" \
  --definitions @falcon-initiative.json \
  --management-group "your-mg-id"

# Assign the initiative to your subscription/resource group
az policy assignment create \
  --name "falcon-security-assignment" \
  --display-name "Falcon Security Baseline Assignment" \
  --policy-set-definition "falcon-security-baseline" \
  --scope "/subscriptions/your-sub-id" \
  --identity-scope "/subscriptions/your-sub-id" \
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

### Step 2: Grant Key Vault Access

```bash
# Get the policy assignment's managed identity
POLICY_IDENTITY=$(az policy assignment show --name "falcon-security-assignment" --scope "/subscriptions/your-sub-id" --query identity.principalId -o tsv)

# Grant Key Vault access
az keyvault set-policy \
  --name "your-keyvault" \
  --object-id $POLICY_IDENTITY \
  --secret-permissions get list
```

### Step 3: Verify Deployment

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