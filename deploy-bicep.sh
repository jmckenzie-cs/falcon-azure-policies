#!/bin/bash
# ============================================================================
# Deploy CrowdStrike Falcon Policies using Bicep
# ============================================================================

set -e

# Configuration
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
LOCATION="${LOCATION:-eastus}"

echo "🚀 Deploying CrowdStrike Falcon Azure Policies with Bicep"
echo "   Subscription: $SUBSCRIPTION_ID"
echo "   Location: $LOCATION"
echo ""

# Step 1: Deploy Policy Definitions
echo "📋 Step 1/3: Deploying policy definitions..."
az deployment sub create \
  --name falcon-policies-$(date +%Y%m%d-%H%M%S) \
  --location $LOCATION \
  --template-file policies.bicep \
  --verbose

echo "✅ Policy definitions deployed successfully"
echo ""

# Step 2: Deploy Policy Initiative
echo "📦 Step 2/3: Deploying policy initiative..."
az deployment sub create \
  --name falcon-initiative-$(date +%Y%m%d-%H%M%S) \
  --location $LOCATION \
  --template-file initiative.bicep \
  --verbose

echo "✅ Policy initiative deployed successfully"
echo ""

# Step 3: Verify deployment
echo "🔍 Step 3/3: Verifying deployment..."
echo ""
echo "Policy Definitions:"
az policy definition list --query "[?contains(name, 'falcon')].{Name:name, DisplayName:displayName}" -o table
echo ""
echo "Policy Initiative:"
az policy set-definition list --query "[?contains(name, 'falcon')].{Name:name, DisplayName:displayName}" -o table
echo ""

echo "✅ Deployment complete!"
echo ""
echo "📖 Next Steps:"
echo "   1. Assign the initiative: see README-BICEP.md for assignment instructions"
echo "   2. Configure parameters for your environment"
echo "   3. Monitor policy compliance in Azure Portal"
echo ""
