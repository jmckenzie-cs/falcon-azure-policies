#!/bin/bash
set -e

# Configuration - UPDATE THESE VALUES
SCOPE_TYPE="subscription"  # or "management-group"
SCOPE_ID="your-subscription-id"  # or management group ID
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
echo "📝 Updating initiative scope references..."
cp falcon-initiative.json falcon-initiative-backup.json

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

# Restore original initiative file
mv falcon-initiative-backup.json falcon-initiative.json

# Assign the initiative
echo "🎯 Assigning policy initiative..."
az policy assignment create \
  --name "falcon-security-assignment" \
  --display-name "Falcon Security Baseline Assignment" \
  --policy-set-definition "falcon-security-baseline" \
  --scope "/subscriptions/${SCOPE_ID}" \
  --identity-scope "/subscriptions/${SCOPE_ID}" \
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
  --scope "/subscriptions/${SCOPE_ID}" \
  --query identity.principalId -o tsv)

KEYVAULT_NAME=$(echo ${KEYVAULT_URI} | cut -d'/' -f3 | cut -d'.' -f1)
az keyvault set-policy \
  --name "${KEYVAULT_NAME}" \
  --object-id $POLICY_IDENTITY \
  --secret-permissions get list

echo ""
echo "✅ Falcon Azure Policies deployed successfully!"
echo ""
echo "📊 Next Steps:"
echo "1. Check policy compliance: az policy state list --policy-assignment falcon-security-assignment"
echo "2. View in Azure Portal: https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Compliance"
echo "3. Monitor AKS clusters for Falcon component deployment"
echo ""
echo "🔍 Verify Falcon components in AKS:"
echo "   kubectl get pods -n falcon-operator"
echo "   kubectl get falconnodesensor -A"
echo "   kubectl get falconadmission -A"
echo "   kubectl get falconimageanalyzer -A"