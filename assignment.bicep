// ============================================================================
// Azure Policy Assignment for CrowdStrike Falcon Initiative
// ============================================================================
// Assigns the Falcon Security Baseline initiative to a resource group
// Deploy this at the RESOURCE GROUP level
// ============================================================================

targetScope = 'resourceGroup'

@description('CrowdStrike Falcon API Client ID')
param falconClientId string

@description('Azure Key Vault name containing the Falcon client secret')
param keyVaultName string

@description('Name of the resource group containing the Key Vault')
param keyVaultResourceGroup string

@description('Name of the secret in Key Vault')
param keyVaultSecretName string = 'falcon-client-secret'

@description('Falcon Cloud region')
@allowed([
  'autodiscover'
  'us-1'
  'us-2'
  'eu-1'
  'us-gov-1'
])
param falconCloud string = 'autodiscover'

@description('Falcon update policy name from Falcon Console')
param updatePolicy string = 'platform_default'

@description('Admission Controller failure policy')
@allowed([
  'Ignore'
  'Fail'
])
param admissionFailurePolicy string = 'Fail'

@description('Effect for Falcon Operator policy')
@allowed([
  'DeployIfNotExists'
  'AuditIfNotExists'
  'Disabled'
])
param operatorEffect string = 'AuditIfNotExists'

@description('Effect for Node Sensor policy')
@allowed([
  'DeployIfNotExists'
  'AuditIfNotExists'
  'Disabled'
])
param nodeSensorEffect string = 'AuditIfNotExists'

@description('Effect for Admission Controller policy')
@allowed([
  'DeployIfNotExists'
  'AuditIfNotExists'
  'Disabled'
])
param admissionEffect string = 'AuditIfNotExists'

@description('Effect for Image Analyzer policy')
@allowed([
  'DeployIfNotExists'
  'AuditIfNotExists'
  'Disabled'
])
param imageAnalyzerEffect string = 'AuditIfNotExists'

@description('Effect for Compliance Audit policy')
@allowed([
  'Audit'
  'Disabled'
])
param complianceEffect string = 'Audit'

@description('Location for the managed identity')
param location string = 'eastus'

// Build the Key Vault secret URI
var falconClientSecretUri = 'https://${keyVaultName}.vault.azure.net/secrets/${keyVaultSecretName}'

// Reference the existing policy initiative at subscription level
resource falconInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' existing = {
  name: 'falcon-security-baseline'
  scope: subscription()
}

// Create the policy assignment at resource group level
resource falconAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'falcon-security-assignment'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'CrowdStrike Falcon Security Baseline Assignment'
    description: 'Assigns the Falcon Security Baseline initiative to monitor and deploy Falcon components across AKS clusters in this resource group'
    policyDefinitionId: falconInitiative.id
    parameters: {
      falconClientId: {
        value: falconClientId
      }
      falconClientSecretUri: {
        value: falconClientSecretUri
      }
      falconCloud: {
        value: falconCloud
      }
      updatePolicy: {
        value: updatePolicy
      }
      admissionFailurePolicy: {
        value: admissionFailurePolicy
      }
      operatorEffect: {
        value: operatorEffect
      }
      nodeSensorEffect: {
        value: nodeSensorEffect
      }
      admissionEffect: {
        value: admissionEffect
      }
      imageAnalyzerEffect: {
        value: imageAnalyzerEffect
      }
      complianceEffect: {
        value: complianceEffect
      }
    }
  }
}

// Grant the managed identity access to Key Vault
module keyVaultAccessPolicy 'keyvault-access.bicep' = {
  name: 'grant-keyvault-access'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    keyVaultName: keyVaultName
    principalId: falconAssignment.identity.principalId
  }
}

output assignmentId string = falconAssignment.id
output assignmentName string = falconAssignment.name
output managedIdentityPrincipalId string = falconAssignment.identity.principalId
