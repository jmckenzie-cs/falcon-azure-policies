// ============================================================================
// Azure Policy Initiative (Policy Set) for CrowdStrike Falcon
// ============================================================================
// Groups all Falcon policies together for easier assignment
// ============================================================================

targetScope = 'subscription'

// Reference the existing policy definitions
resource falconOperatorPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'deploy-falcon-operator'
}

resource falconNodeSensorPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'deploy-falcon-node-sensor'
}

resource falconAdmissionControllerPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'deploy-falcon-admission-controller'
}

resource falconImageAnalyzerPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'deploy-falcon-image-analyzer'
}

resource falconCompliancePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'audit-falcon-compliance'
}

// Create the policy initiative
resource falconInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: 'falcon-security-baseline'
  properties: {
    displayName: 'CrowdStrike Falcon Security Baseline for AKS'
    description: 'Comprehensive security baseline that deploys and monitors CrowdStrike Falcon components across Azure Kubernetes Service clusters'
    policyType: 'Custom'
    metadata: {
      category: 'Kubernetes'
      version: '1.0.0'
    }
    parameters: {
      falconClientId: {
        type: 'String'
        metadata: {
          displayName: 'Falcon Client ID'
          description: 'CrowdStrike Falcon API Client ID'
        }
      }
      falconClientSecretUri: {
        type: 'String'
        metadata: {
          displayName: 'Falcon Client Secret Key Vault URI'
          description: 'Azure Key Vault URI for Falcon API Client Secret (e.g., https://your-keyvault.vault.azure.net/secrets/falcon-secret)'
        }
      }
      falconCloud: {
        type: 'String'
        metadata: {
          displayName: 'Falcon Cloud Region'
          description: 'CrowdStrike Falcon Cloud region'
        }
        allowedValues: [
          'autodiscover'
          'us-1'
          'us-2'
          'eu-1'
          'us-gov-1'
        ]
        defaultValue: 'autodiscover'
      }
      updatePolicy: {
        type: 'String'
        metadata: {
          displayName: 'Falcon Update Policy'
          description: 'Update policy name from Falcon Console'
        }
        defaultValue: 'platform_default'
      }
      admissionFailurePolicy: {
        type: 'String'
        metadata: {
          displayName: 'Admission Failure Policy'
          description: 'Action when admission webhook fails'
        }
        allowedValues: [
          'Ignore'
          'Fail'
        ]
        defaultValue: 'Fail'
      }
      operatorEffect: {
        type: 'String'
        metadata: {
          displayName: 'Operator Policy Effect'
          description: 'Effect for Falcon Operator deployment policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      nodeSensorEffect: {
        type: 'String'
        metadata: {
          displayName: 'Node Sensor Policy Effect'
          description: 'Effect for Falcon Node Sensor deployment policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      admissionEffect: {
        type: 'String'
        metadata: {
          displayName: 'Admission Controller Policy Effect'
          description: 'Effect for Falcon Admission Controller deployment policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      imageAnalyzerEffect: {
        type: 'String'
        metadata: {
          displayName: 'Image Analyzer Policy Effect'
          description: 'Effect for Falcon Image Analyzer deployment policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      complianceEffect: {
        type: 'String'
        metadata: {
          displayName: 'Compliance Audit Policy Effect'
          description: 'Effect for Falcon compliance audit policy'
        }
        allowedValues: [
          'Audit'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: falconOperatorPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'operatorEffect\')]'
          }
        }
        policyDefinitionReferenceId: 'DeployFalconOperator'
      }
      {
        policyDefinitionId: falconNodeSensorPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'nodeSensorEffect\')]'
          }
          falconClientId: {
            value: '[parameters(\'falconClientId\')]'
          }
          falconClientSecretUri: {
            value: '[parameters(\'falconClientSecretUri\')]'
          }
          falconCloud: {
            value: '[parameters(\'falconCloud\')]'
          }
          updatePolicy: {
            value: '[parameters(\'updatePolicy\')]'
          }
        }
        policyDefinitionReferenceId: 'DeployFalconNodeSensor'
      }
      {
        policyDefinitionId: falconAdmissionControllerPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'admissionEffect\')]'
          }
          falconClientId: {
            value: '[parameters(\'falconClientId\')]'
          }
          falconClientSecretUri: {
            value: '[parameters(\'falconClientSecretUri\')]'
          }
          falconCloud: {
            value: '[parameters(\'falconCloud\')]'
          }
          admissionFailurePolicy: {
            value: '[parameters(\'admissionFailurePolicy\')]'
          }
        }
        policyDefinitionReferenceId: 'DeployFalconAdmissionController'
      }
      {
        policyDefinitionId: falconImageAnalyzerPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'imageAnalyzerEffect\')]'
          }
          falconClientId: {
            value: '[parameters(\'falconClientId\')]'
          }
          falconClientSecretUri: {
            value: '[parameters(\'falconClientSecretUri\')]'
          }
          falconCloud: {
            value: '[parameters(\'falconCloud\')]'
          }
        }
        policyDefinitionReferenceId: 'DeployFalconImageAnalyzer'
      }
      {
        policyDefinitionId: falconCompliancePolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'complianceEffect\')]'
          }
        }
        policyDefinitionReferenceId: 'AuditFalconCompliance'
      }
    ]
  }
}

output initiativeId string = falconInitiative.id
output initiativeName string = falconInitiative.name
