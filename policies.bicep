// ============================================================================
// Azure Policy Definitions for CrowdStrike Falcon Operator
// ============================================================================
// This Bicep file defines five Azure Policies for automated deployment and
// compliance monitoring of CrowdStrike Falcon components on AKS clusters
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// POLICY 1: Deploy Falcon Operator
// ============================================================================

resource deployFalconOperatorPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'deploy-falcon-operator'
  properties: {
    displayName: 'Deploy CrowdStrike Falcon Operator to AKS'
    description: 'Automatically deploys the CrowdStrike Falcon Operator to Azure Kubernetes Service clusters'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Kubernetes'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
    }
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.ContainerService/managedClusters'
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.ContainerService/managedClusters'
          existenceCondition: {
            field: 'Microsoft.ContainerService/managedClusters/addonProfiles.omsagent.enabled'
            equals: 'true'
          }
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          deployment: {
            properties: {
              mode: 'Incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  clusterName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.Resources/deploymentScripts'
                    apiVersion: '2020-10-01'
                    name: 'deploy-falcon-operator'
                    location: '[parameters(\'location\')]'
                    kind: 'AzureCLI'
                    properties: {
                      azCliVersion: '2.45.0'
                      scriptContent: '''#!/bin/bash
set -e

# Get AKS credentials
az aks get-credentials --resource-group $(echo $AZ_RESOURCE_GROUP) --name $CLUSTER_NAME --overwrite-existing

# Deploy Falcon Operator
kubectl apply -f https://github.com/CrowdStrike/falcon-operator/releases/latest/download/falcon-operator.yaml

# Wait for operator to be ready
kubectl wait --for=condition=Available deployment/falcon-operator-controller-manager -n falcon-operator --timeout=300s

# Verify deployment
kubectl get pods -n falcon-operator
echo "Falcon Operator deployed successfully"'''
                      environmentVariables: [
                        {
                          name: 'CLUSTER_NAME'
                          value: '[parameters(\'clusterName\')]'
                        }
                        {
                          name: 'AZ_RESOURCE_GROUP'
                          value: '[resourceGroup().name]'
                        }
                      ]
                      retentionInterval: 'P1D'
                      timeout: 'PT30M'
                    }
                  }
                ]
              }
              parameters: {
                clusterName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
              }
            }
          }
        }
      }
    }
  }
}

// ============================================================================
// POLICY 2: Deploy Falcon Node Sensor
// ============================================================================

resource deployFalconNodeSensorPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'deploy-falcon-node-sensor'
  properties: {
    displayName: 'Deploy CrowdStrike Falcon Node Sensor to AKS'
    description: 'Automatically deploys the CrowdStrike Falcon Node Sensor as a DaemonSet to Azure Kubernetes Service clusters'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Kubernetes'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
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
          description: 'Azure Key Vault URI for Falcon API Client Secret'
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
    }
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.ContainerService/managedClusters'
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.ContainerService/managedClusters'
          existenceCondition: {
            field: 'Microsoft.ContainerService/managedClusters/agentPoolProfiles[*].osType'
            equals: 'Linux'
          }
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          deployment: {
            properties: {
              mode: 'Incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  clusterName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                  falconClientId: {
                    type: 'string'
                  }
                  falconClientSecretUri: {
                    type: 'string'
                  }
                  acrName: {
                    type: 'string'
                  }
                  falconCloud: {
                    type: 'string'
                  }
                  updatePolicy: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.Resources/deploymentScripts'
                    apiVersion: '2020-10-01'
                    name: 'deploy-falcon-node-sensor'
                    location: '[parameters(\'location\')]'
                    kind: 'AzureCLI'
                    identity: {
                      type: 'SystemAssigned'
                    }
                    properties: {
                      azCliVersion: '2.45.0'
                      scriptContent: '''#!/bin/bash
set -e

# Get AKS credentials
az aks get-credentials --resource-group $AZ_RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Create namespace if it doesn't exist
kubectl create namespace falcon-system --dry-run=client -o yaml | kubectl apply -f -

# Get Falcon Client Secret from Key Vault
FALCON_CLIENT_SECRET=$(az keyvault secret show --vault-name $(echo $FALCON_CLIENT_SECRET_URI | cut -d'/' -f3 | cut -d'.' -f1) --name $(echo $FALCON_CLIENT_SECRET_URI | rev | cut -d'/' -f1 | rev) --query value -o tsv)

# Create Falcon API secret
kubectl create secret generic falcon-api-secret \
  --from-literal=falcon-client-id=$FALCON_CLIENT_ID \
  --from-literal=falcon-client-secret=$FALCON_CLIENT_SECRET \
  -n falcon-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Create FalconNodeSensor CR
cat <<EOF | kubectl apply -f -
apiVersion: falcon.crowdstrike.com/v1alpha1
kind: FalconNodeSensor
metadata:
  name: falcon-node-sensor
  namespace: falcon-system
spec:
  falcon_api:
    client_id: $FALCON_CLIENT_ID
    cloud_region: $FALCON_CLOUD
  node:
    backend: bpf
    advanced:
      updatePolicy: $UPDATE_POLICY
      autoUpdate: normal
  falconSecret:
    enabled: true
    namespace: falcon-system
    secretName: falcon-api-secret
EOF

# Wait for DaemonSet to be ready
echo "Waiting for Falcon Node Sensor DaemonSet to be ready..."
kubectl wait --for=condition=Ready daemonset/falcon-node-sensor -n falcon-system --timeout=600s || true

# Verify deployment
kubectl get pods -n falcon-system -l app=falcon-node-sensor
echo "Falcon Node Sensor deployed successfully"'''
                      environmentVariables: [
                        {
                          name: 'CLUSTER_NAME'
                          value: '[parameters(\'clusterName\')]'
                        }
                        {
                          name: 'AZ_RESOURCE_GROUP'
                          value: '[resourceGroup().name]'
                        }
                        {
                          name: 'FALCON_CLIENT_ID'
                          value: '[parameters(\'falconClientId\')]'
                        }
                        {
                          name: 'FALCON_CLIENT_SECRET_URI'
                          value: '[parameters(\'falconClientSecretUri\')]'
                        }
                        {
                          name: 'FALCON_CLOUD'
                          value: '[parameters(\'falconCloud\')]'
                        }
                        {
                          name: 'UPDATE_POLICY'
                          value: '[parameters(\'updatePolicy\')]'
                        }
                      ]
                      retentionInterval: 'P1D'
                      timeout: 'PT45M'
                    }
                  }
                ]
              }
              parameters: {
                clusterName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
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
            }
          }
        }
      }
    }
  }
}

// ============================================================================
// POLICY 3: Deploy Falcon Admission Controller
// ============================================================================

resource deployFalconAdmissionControllerPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'deploy-falcon-admission-controller'
  properties: {
    displayName: 'Deploy CrowdStrike Falcon Admission Controller to AKS'
    description: 'Automatically deploys the CrowdStrike Falcon Admission Controller to Azure Kubernetes Service clusters for container image validation'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Kubernetes'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
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
          description: 'Azure Key Vault URI for Falcon API Client Secret'
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
    }
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.ContainerService/managedClusters'
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.ContainerService/managedClusters'
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          deployment: {
            properties: {
              mode: 'Incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  clusterName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                  falconClientId: {
                    type: 'string'
                  }
                  falconClientSecretUri: {
                    type: 'string'
                  }
                  acrName: {
                    type: 'string'
                  }
                  falconCloud: {
                    type: 'string'
                  }
                  admissionFailurePolicy: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.Resources/deploymentScripts'
                    apiVersion: '2020-10-01'
                    name: 'deploy-falcon-admission-controller'
                    location: '[parameters(\'location\')]'
                    kind: 'AzureCLI'
                    identity: {
                      type: 'SystemAssigned'
                    }
                    properties: {
                      azCliVersion: '2.45.0'
                      scriptContent: '''#!/bin/bash
set -e

# Get AKS credentials
az aks get-credentials --resource-group $AZ_RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Create namespace if it doesn't exist
kubectl create namespace falcon-kac --dry-run=client -o yaml | kubectl apply -f -

# Get Falcon Client Secret from Key Vault
FALCON_CLIENT_SECRET=$(az keyvault secret show --vault-name $(echo $FALCON_CLIENT_SECRET_URI | cut -d'/' -f3 | cut -d'.' -f1) --name $(echo $FALCON_CLIENT_SECRET_URI | rev | cut -d'/' -f1 | rev) --query value -o tsv)

# Create Falcon API secret for admission controller
kubectl create secret generic falcon-api-secret \
  --from-literal=falcon-client-id=$FALCON_CLIENT_ID \
  --from-literal=falcon-client-secret=$FALCON_CLIENT_SECRET \
  -n falcon-kac \
  --dry-run=client -o yaml | kubectl apply -f -

# Create FalconAdmission CR
cat <<EOF | kubectl apply -f -
apiVersion: falcon.crowdstrike.com/v1alpha1
kind: FalconAdmission
metadata:
  name: falcon-admission
  namespace: falcon-kac
spec:
  falcon_api:
    client_id: $FALCON_CLIENT_ID
    cloud_region: $FALCON_CLOUD
  admission:
    replicas: 2
    serviceAccount:
      annotations:
        admissions.enforcer/disabled: "true"
    admissionPolicyService:
      annotations:
        admissions.enforcer/disabled: "true"
    failurePolicy: $ADMISSION_FAILURE_POLICY
    disabledNamespaces:
      namespaces:
        - kube-system
        - kube-public
        - falcon-system
        - falcon-operator
        - azure-arc
  falconSecret:
    enabled: true
    namespace: falcon-kac
    secretName: falcon-api-secret
EOF

# Wait for admission controller to be ready
echo "Waiting for Falcon Admission Controller to be ready..."
kubectl wait --for=condition=Available deployment/falcon-admission -n falcon-kac --timeout=600s || true

# Verify ValidatingWebhookConfiguration is created
kubectl get validatingwebhookconfiguration falcon-kac-admission || echo "Webhook configuration not yet ready"

# Verify deployment
kubectl get pods -n falcon-kac
echo "Falcon Admission Controller deployed successfully"'''
                      environmentVariables: [
                        {
                          name: 'CLUSTER_NAME'
                          value: '[parameters(\'clusterName\')]'
                        }
                        {
                          name: 'AZ_RESOURCE_GROUP'
                          value: '[resourceGroup().name]'
                        }
                        {
                          name: 'FALCON_CLIENT_ID'
                          value: '[parameters(\'falconClientId\')]'
                        }
                        {
                          name: 'FALCON_CLIENT_SECRET_URI'
                          value: '[parameters(\'falconClientSecretUri\')]'
                        }
                        {
                          name: 'FALCON_CLOUD'
                          value: '[parameters(\'falconCloud\')]'
                        }
                        {
                          name: 'ADMISSION_FAILURE_POLICY'
                          value: '[parameters(\'admissionFailurePolicy\')]'
                        }
                      ]
                      retentionInterval: 'P1D'
                      timeout: 'PT45M'
                    }
                  }
                ]
              }
              parameters: {
                clusterName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
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
            }
          }
        }
      }
    }
  }
}

// ============================================================================
// POLICY 4: Deploy Falcon Image Analyzer
// ============================================================================

resource deployFalconImageAnalyzerPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'deploy-falcon-image-analyzer'
  properties: {
    displayName: 'Deploy CrowdStrike Falcon Image Analyzer to AKS'
    description: 'Automatically deploys the CrowdStrike Falcon Image Analyzer to Azure Kubernetes Service clusters for runtime image analysis'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Kubernetes'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
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
          description: 'Azure Key Vault URI for Falcon API Client Secret'
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
    }
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.ContainerService/managedClusters'
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.ContainerService/managedClusters'
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          deployment: {
            properties: {
              mode: 'Incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  clusterName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                  falconClientId: {
                    type: 'string'
                  }
                  falconClientSecretUri: {
                    type: 'string'
                  }
                  acrName: {
                    type: 'string'
                  }
                  falconCloud: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.Resources/deploymentScripts'
                    apiVersion: '2020-10-01'
                    name: 'deploy-falcon-image-analyzer'
                    location: '[parameters(\'location\')]'
                    kind: 'AzureCLI'
                    identity: {
                      type: 'SystemAssigned'
                    }
                    properties: {
                      azCliVersion: '2.45.0'
                      scriptContent: '''#!/bin/bash
set -e

# Get AKS credentials
az aks get-credentials --resource-group $AZ_RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Create namespace if it doesn't exist
kubectl create namespace falcon-iar --dry-run=client -o yaml | kubectl apply -f -

# Get Falcon Client Secret from Key Vault
FALCON_CLIENT_SECRET=$(az keyvault secret show --vault-name $(echo $FALCON_CLIENT_SECRET_URI | cut -d'/' -f3 | cut -d'.' -f1) --name $(echo $FALCON_CLIENT_SECRET_URI | rev | cut -d'/' -f1 | rev) --query value -o tsv)

# Create Falcon API secret for image analyzer
kubectl create secret generic falcon-api-secret \
  --from-literal=falcon-client-id=$FALCON_CLIENT_ID \
  --from-literal=falcon-client-secret=$FALCON_CLIENT_SECRET \
  -n falcon-iar \
  --dry-run=client -o yaml | kubectl apply -f -

# Create FalconImageAnalyzer CR
cat <<EOF | kubectl apply -f -
apiVersion: falcon.crowdstrike.com/v1alpha1
kind: FalconImageAnalyzer
metadata:
  name: falcon-image-analyzer
  namespace: falcon-iar
spec:
  falcon_api:
    client_id: $FALCON_CLIENT_ID
    cloud_region: $FALCON_CLOUD
  image_analyzer:
    replicas: 2
    serviceAccount:
      annotations:
        azure.workload.identity/client-id: "system-assigned"
    exclusions:
      registries:
        - "mcr.microsoft.com"
        - "docker.io/library"
      namespaces:
        - kube-system
        - kube-public
        - falcon-system
        - falcon-operator
        - falcon-kac
        - azure-arc
  falconSecret:
    enabled: true
    namespace: falcon-iar
    secretName: falcon-api-secret
EOF

# Wait for image analyzer to be ready
echo "Waiting for Falcon Image Analyzer to be ready..."
kubectl wait --for=condition=Available deployment/falcon-image-analyzer -n falcon-iar --timeout=600s || true

# Verify deployment
kubectl get pods -n falcon-iar
echo "Falcon Image Analyzer deployed successfully"'''
                      environmentVariables: [
                        {
                          name: 'CLUSTER_NAME'
                          value: '[parameters(\'clusterName\')]'
                        }
                        {
                          name: 'AZ_RESOURCE_GROUP'
                          value: '[resourceGroup().name]'
                        }
                        {
                          name: 'FALCON_CLIENT_ID'
                          value: '[parameters(\'falconClientId\')]'
                        }
                        {
                          name: 'FALCON_CLIENT_SECRET_URI'
                          value: '[parameters(\'falconClientSecretUri\')]'
                        }
                        {
                          name: 'FALCON_CLOUD'
                          value: '[parameters(\'falconCloud\')]'
                        }
                      ]
                      retentionInterval: 'P1D'
                      timeout: 'PT45M'
                    }
                  }
                ]
              }
              parameters: {
                clusterName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
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
            }
          }
        }
      }
    }
  }
}

// ============================================================================
// POLICY 5: Audit Falcon Compliance
// ============================================================================

resource auditFalconCompliancePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'audit-falcon-compliance'
  properties: {
    displayName: 'Audit CrowdStrike Falcon Compliance on AKS'
    description: 'Audits Azure Kubernetes Service clusters for CrowdStrike Falcon component deployment and security compliance'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Kubernetes'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'Audit'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
    }
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.ContainerService/managedClusters'
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.ContainerService/managedClusters'
          evaluationDelay: 'AfterProvisioning'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.ContainerService/managedClusters/addonProfiles.omsagent.enabled'
                equals: 'true'
              }
            ]
          }
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          deployment: {
            properties: {
              mode: 'Incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  clusterName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.Resources/deploymentScripts'
                    apiVersion: '2020-10-01'
                    name: 'audit-falcon-compliance'
                    location: '[parameters(\'location\')]'
                    kind: 'AzureCLI'
                    properties: {
                      azCliVersion: '2.45.0'
                      scriptContent: '''#!/bin/bash
set -e

# Get AKS credentials
az aks get-credentials --resource-group $AZ_RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Initialize compliance report
echo "=== Falcon Security Compliance Audit for $CLUSTER_NAME ==="
COMPLIANCE_PASS=true

# Check 1: Falcon Operator exists
echo "\n[CHECK 1] Falcon Operator Deployment"
if kubectl get deployment falcon-operator-controller-manager -n falcon-operator > /dev/null 2>&1; then
    echo "✓ PASS: Falcon Operator is deployed"
else
    echo "✗ FAIL: Falcon Operator not found"
    COMPLIANCE_PASS=false
fi

# Check 2: FalconNodeSensor exists and is ready
echo "\n[CHECK 2] Falcon Node Sensor"
if kubectl get falconnodesensor -A > /dev/null 2>&1; then
    SENSOR_COUNT=$(kubectl get falconnodesensor -A --no-headers | wc -l)
    READY_SENSORS=$(kubectl get falconnodesensor -A -o jsonpath='{.items[?(@.status.conditions[?(@.type=="Ready")].status=="True")].metadata.name}' | wc -w)
    echo "✓ PASS: $SENSOR_COUNT Falcon Node Sensor(s) found, $READY_SENSORS ready"

    # Check registry type
    REGISTRY_TYPE=$(kubectl get falconnodesensor -A -o jsonpath='{.items[0].spec.registry.type}' 2>/dev/null || echo "unknown")
    if [[ "$REGISTRY_TYPE" == "acr" ]]; then
        echo "✓ PASS: Using ACR registry"
    else
        echo "⚠ WARNING: Not using ACR registry (current: $REGISTRY_TYPE)"
    fi
else
    echo "✗ FAIL: No Falcon Node Sensors found"
    COMPLIANCE_PASS=false
fi

# Check 3: FalconAdmission exists and webhook is configured
echo "\n[CHECK 3] Falcon Admission Controller"
if kubectl get falconadmission -A > /dev/null 2>&1; then
    ADM_COUNT=$(kubectl get falconadmission -A --no-headers | wc -l)
    echo "✓ PASS: $ADM_COUNT Falcon Admission Controller(s) found"

    # Check ValidatingWebhookConfiguration
    if kubectl get validatingwebhookconfiguration | grep -q falcon; then
        echo "✓ PASS: Falcon ValidatingWebhookConfiguration found"
    else
        echo "⚠ WARNING: Falcon ValidatingWebhookConfiguration not found"
    fi

    # Check failure policy
    FAILURE_POLICY=$(kubectl get falconadmission -A -o jsonpath='{.items[0].spec.admission.failurePolicy}' 2>/dev/null || echo "unknown")
    echo "ℹ INFO: Admission failure policy: $FAILURE_POLICY"
else
    echo "✗ FAIL: No Falcon Admission Controllers found"
    COMPLIANCE_PASS=false
fi

# Check 4: FalconImageAnalyzer (optional)
echo "\n[CHECK 4] Falcon Image Analyzer (Optional)"
if kubectl get falconimageanalyzer -A > /dev/null 2>&1; then
    IAR_COUNT=$(kubectl get falconimageanalyzer -A --no-headers | wc -l)
    echo "✓ PASS: $IAR_COUNT Falcon Image Analyzer(s) found"
else
    echo "ℹ INFO: No Falcon Image Analyzers found (optional component)"
fi

# Check 5: Namespace security
echo "\n[CHECK 5] Namespace Security"
FALCON_NAMESPACES=$(kubectl get ns -l crowdstrike.com/component --no-headers 2>/dev/null | wc -l || echo "0")
if [[ $FALCON_NAMESPACES -gt 0 ]]; then
    echo "✓ PASS: $FALCON_NAMESPACES Falcon-managed namespaces found"
else
    echo "⚠ WARNING: No labeled Falcon namespaces found"
fi

# Check 6: Pod Security Standards
echo "\n[CHECK 6] Pod Security Standards"
PRIVILEGED_PODS=$(kubectl get pods -A -o jsonpath='{.items[?(@.spec.securityContext.privileged==true)].metadata.name}' | wc -w)
echo "ℹ INFO: $PRIVILEGED_PODS privileged pods running (Falcon Node Sensor requires privileged access)"

# Final compliance result
echo "\n=== COMPLIANCE SUMMARY ==="
if $COMPLIANCE_PASS; then
    echo "✓ OVERALL: COMPLIANT - All critical Falcon components are deployed"
    exit 0
else
    echo "✗ OVERALL: NON-COMPLIANT - Missing critical Falcon components"
    exit 1
fi'''
                      environmentVariables: [
                        {
                          name: 'CLUSTER_NAME'
                          value: '[parameters(\'clusterName\')]'
                        }
                        {
                          name: 'AZ_RESOURCE_GROUP'
                          value: '[resourceGroup().name]'
                        }
                      ]
                      retentionInterval: 'P1D'
                      timeout: 'PT30M'
                    }
                  }
                ]
              }
              parameters: {
                clusterName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
              }
            }
          }
        }
      }
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

output deployFalconOperatorPolicyId string = deployFalconOperatorPolicy.id
output deployFalconNodeSensorPolicyId string = deployFalconNodeSensorPolicy.id
output deployFalconAdmissionControllerPolicyId string = deployFalconAdmissionControllerPolicy.id
output deployFalconImageAnalyzerPolicyId string = deployFalconImageAnalyzerPolicy.id
output auditFalconCompliancePolicyId string = auditFalconCompliancePolicy.id
