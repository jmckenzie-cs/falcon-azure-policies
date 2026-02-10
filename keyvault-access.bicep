// ============================================================================
// Key Vault Access Policy Module
// ============================================================================
// Grants a managed identity access to Key Vault secrets
// ============================================================================

targetScope = 'resourceGroup'

@description('Name of the Key Vault')
param keyVaultName string

@description('Principal ID of the managed identity')
param principalId string

// Reference the existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: keyVaultName
}

// Grant access policy
resource accessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-06-01-preview' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

output keyVaultName string = keyVault.name
