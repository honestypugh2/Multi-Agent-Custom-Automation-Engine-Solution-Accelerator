metadata name = 'Container Apps Deployment'
metadata description = 'This template deploys Container Apps and their dependencies, expecting ACR to already exist.'

@description('Required. Name of the environment to deploy the solution into.')
param environmentName string

@description('Required. Location for all Resources.')
param solutionLocation string = resourceGroup().location

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

@description('Set the image tag for the container images used in the solution.')
param imageTag string = 'latest'

// Generate solution prefix same as main.bicep
param solutionPrefix string = 'macae${padLeft(take(toLower(uniqueString(subscription().id, environmentName, resourceGroup().location, resourceGroup().name)), 12), 12, '0')}'

// AI Configuration
@allowed(['australiaeast', 'eastus2', 'francecentral', 'japaneast', 'norwayeast', 'swedencentral', 'uksouth', 'westus'])
@description('Azure OpenAI Location')
param aiDeploymentsLocation string = 'eastus2'

@description('Name of the GPT model to deploy')
param gptModelName string = 'gpt-4o'

@description('GPT model version')
param gptModelVersion string = '2024-08-06'

@description('GPT model deployment type')
param modelDeploymentType string = 'GlobalStandard'

@description('AI model deployment token capacity')
param gptModelCapacity int = 150

@description('Use an existing AI project resource ID')
param existingFoundryProjectResourceId string = ''

@description('Existing Log Analytics Workspace ID')
param existingLogAnalyticsWorkspaceId string = ''

@description('Set to true for WAF-aligned architecture')
param useWafAlignedArchitecture bool = false

@description('Optional. The tags to apply to all deployed Azure resources.')
param tags object = {
  app: solutionPrefix
  location: solutionLocation
  deployment: 'container-apps-only'
}

// Configuration parameters
@description('Optional. The configuration to apply for the Network Security Group resource for the backend subnet.')
param networkSecurityGroupBackendConfiguration networkSecurityGroupConfigurationType = {
  enabled: true
  name: 'nsg-backend-${solutionPrefix}'
  location: solutionLocation
  tags: tags
  securityRules: null
}

@description('Optional. The configuration to apply for the Network Security Group resource for the containers subnet.')
param networkSecurityGroupContainersConfiguration networkSecurityGroupConfigurationType = {
  enabled: true
  name: 'nsg-containers-${solutionPrefix}'
  location: solutionLocation
  tags: tags
  securityRules: null
}

@description('Optional. The configuration to apply for the Network Security Group resource for the Bastion subnet.')
param networkSecurityGroupBastionConfiguration networkSecurityGroupConfigurationType = {
  enabled: true
  name: 'nsg-bastion-${solutionPrefix}'
  location: solutionLocation
  tags: tags
  securityRules: null
}

@description('Optional. The configuration to apply for the Network Security Group resource for the administration subnet.')
param networkSecurityGroupAdministrationConfiguration networkSecurityGroupConfigurationType = {
  enabled: true
  name: 'nsg-administration-${solutionPrefix}'
  location: solutionLocation
  tags: tags
  securityRules: null
}

@description('Optional. The configuration to apply for the virtual network resource.')
param virtualNetworkConfiguration virtualNetworkConfigurationType = {
  enabled: useWafAlignedArchitecture ? true : false
  name: 'vnet-${solutionPrefix}'
  location: solutionLocation
  tags: tags
  addressPrefixes: null
  subnets: null
}

@description('Optional. The configuration to apply for the bastion resource.')
param bastionConfiguration bastionConfigurationType = {
  enabled: true
  name: 'bas-${solutionPrefix}'
  location: solutionLocation
  tags: tags
  sku: 'Standard'
  virtualNetworkResourceId: null
  publicIpResourceName: 'pip-bas${solutionPrefix}'
}

@description('Optional. Configuration for the Windows virtual machine.')
param virtualMachineConfiguration virtualMachineConfigurationType = {
  enabled: true
  name: 'vm${solutionPrefix}'
  location: solutionLocation
  tags: tags
  adminUsername: 'adminuser'
  adminPassword: useWafAlignedArchitecture? 'P@ssw0rd1234' : guid(solutionPrefix, subscription().subscriptionId)
  vmSize: 'Standard_D2s_v3'
  subnetResourceId: null
}

@description('Optional. The configuration to apply for the Web Server Farm resource.')
param webServerFarmConfiguration webServerFarmConfigurationType = {
  enabled: true
  name: 'asp-${solutionPrefix}'
  location: solutionLocation
  skuName: useWafAlignedArchitecture? 'P1v3' : 'B2'
  skuCapacity: useWafAlignedArchitecture ? 3 : 1
  tags: tags
}

@description('Optional. The configuration to apply for the Web Server Farm resource.')
param webSiteConfiguration webSiteConfigurationType = {
  enabled: true
  name: 'app-${solutionPrefix}'
  location: solutionLocation
  containerImageName: 'macaefrontend'
  containerImageTag: imageTag
  containerName: 'backend'
  tags: tags
  environmentResourceId: null
}

// Reference existing resources
var containerRegistryName = 'cr${solutionPrefix}'
var userAssignedIdentityName = 'id-${solutionPrefix}'

// Reference existing Container Registry
resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

// Reference existing User Assigned Identity
resource existingUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

// ========== Resource Group Tag ========== //
resource resourceGroupTags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  properties: {
    tags: {
      ...tags
      TemplateName: 'MacaeContainerApps'
      DeploymentStep: 'Step3-ContainerApps'
    }
  }
}

// ========== Log Analytics Workspace ========== //
var logAnalyticsWorkspaceResourceName = 'log-${solutionPrefix}'
var useExistingWorkspace = existingLogAnalyticsWorkspaceId != ''

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.11.2' = if (!useExistingWorkspace) {
  name: take('avm.res.operational-insights.workspace.${logAnalyticsWorkspaceResourceName}', 64)
  params: {
    name: logAnalyticsWorkspaceResourceName
    tags: tags
    location: solutionLocation
    enableTelemetry: enableTelemetry
    skuName: 'PerGB2018'
    dataRetention: useWafAlignedArchitecture ? 365 : 30
    diagnosticSettings: [{ useThisWorkspace: true }]
  }
}

var logAnalyticsWorkspaceId = useExistingWorkspace ? existingLogAnalyticsWorkspaceId : logAnalyticsWorkspace.outputs.resourceId

// ========== Application Insights ========== //
var applicationInsightsResourceName = 'appi-${solutionPrefix}'
module applicationInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: take('avm.res.insights.component.${applicationInsightsResourceName}', 64)
  params: {
    name: applicationInsightsResourceName
    workspaceResourceId: logAnalyticsWorkspaceId
    location: solutionLocation
    enableTelemetry: enableTelemetry
    tags: tags
    retentionInDays: useWafAlignedArchitecture ? 365 : 30
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    kind: 'web'
    disableIpMasking: false
    flowType: 'Bluefield'
  }
}

// ========== Network Security Groups ========== //
var virtualNetworkEnabled = virtualNetworkConfiguration.?enabled ?? true
var networkSecurityGroupBackendEnabled = networkSecurityGroupBackendConfiguration.?enabled ?? true
var networkSecurityGroupBackendResourceName = networkSecurityGroupBackendConfiguration.?name ?? 'nsg-backend-${solutionPrefix}'

module networkSecurityGroupBackend 'br/public:avm/res/network/network-security-group:0.5.1' = if (virtualNetworkEnabled && networkSecurityGroupBackendEnabled) {
  name: take('avm.res.network.network-security-group.${networkSecurityGroupBackendResourceName}', 64)
  params: {
    name: networkSecurityGroupBackendResourceName
    location: networkSecurityGroupBackendConfiguration.?location ?? solutionLocation
    tags: networkSecurityGroupBackendConfiguration.?tags ?? tags
    enableTelemetry: enableTelemetry
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    securityRules: networkSecurityGroupBackendConfiguration.?securityRules ?? []
  }
}

var networkSecurityGroupContainersEnabled = networkSecurityGroupContainersConfiguration.?enabled ?? true
var networkSecurityGroupContainersResourceName = networkSecurityGroupContainersConfiguration.?name ?? 'nsg-containers-${solutionPrefix}'

module networkSecurityGroupContainers 'br/public:avm/res/network/network-security-group:0.5.1' = if (virtualNetworkEnabled && networkSecurityGroupContainersEnabled) {
  name: take('avm.res.network.network-security-group.${networkSecurityGroupContainersResourceName}', 64)
  params: {
    name: networkSecurityGroupContainersResourceName
    location: networkSecurityGroupContainersConfiguration.?location ?? solutionLocation
    tags: networkSecurityGroupContainersConfiguration.?tags ?? tags
    enableTelemetry: enableTelemetry
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    securityRules: networkSecurityGroupContainersConfiguration.?securityRules ?? []
  }
}

var networkSecurityGroupBastionEnabled = networkSecurityGroupBastionConfiguration.?enabled ?? true
var networkSecurityGroupBastionResourceName = networkSecurityGroupBastionConfiguration.?name ?? 'nsg-bastion-${solutionPrefix}'

module networkSecurityGroupBastion 'br/public:avm/res/network/network-security-group:0.5.1' = if (virtualNetworkEnabled && networkSecurityGroupBastionEnabled) {
  name: take('avm.res.network.network-security-group.${networkSecurityGroupBastionResourceName}', 64)
  params: {
    name: networkSecurityGroupBastionResourceName
    location: networkSecurityGroupBastionConfiguration.?location ?? solutionLocation
    tags: networkSecurityGroupBastionConfiguration.?tags ?? tags
    enableTelemetry: enableTelemetry
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    securityRules: networkSecurityGroupBastionConfiguration.?securityRules ?? [
      {
        name: 'AllowHttpsInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowGatewayManagerInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowLoadBalancerInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudCommunicationOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowGetSessionInformationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

var networkSecurityGroupAdministrationEnabled = networkSecurityGroupAdministrationConfiguration.?enabled ?? true
var networkSecurityGroupAdministrationResourceName = networkSecurityGroupAdministrationConfiguration.?name ?? 'nsg-administration-${solutionPrefix}'

module networkSecurityGroupAdministration 'br/public:avm/res/network/network-security-group:0.5.1' = if (virtualNetworkEnabled && networkSecurityGroupAdministrationEnabled) {
  name: take('avm.res.network.network-security-group.${networkSecurityGroupAdministrationResourceName}', 64)
  params: {
    name: networkSecurityGroupAdministrationResourceName
    location: networkSecurityGroupAdministrationConfiguration.?location ?? solutionLocation
    tags: networkSecurityGroupAdministrationConfiguration.?tags ?? tags
    enableTelemetry: enableTelemetry
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    securityRules: networkSecurityGroupAdministrationConfiguration.?securityRules ?? []
  }
}

// ========== Virtual Network ========== //
var virtualNetworkResourceName = virtualNetworkConfiguration.?name ?? 'vnet-${solutionPrefix}'

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.6.1' = if (virtualNetworkEnabled) {
  name: take('avm.res.network.virtual-network.${virtualNetworkResourceName}', 64)
  params: {
    name: virtualNetworkResourceName
    location: virtualNetworkConfiguration.?location ?? solutionLocation
    tags: virtualNetworkConfiguration.?tags ?? tags
    enableTelemetry: enableTelemetry
    addressPrefixes: virtualNetworkConfiguration.?addressPrefixes ?? ['10.0.0.0/8']
    subnets: virtualNetworkConfiguration.?subnets ?? [
      {
        name: 'backend'
        addressPrefix: '10.0.0.0/27'
        networkSecurityGroupResourceId: networkSecurityGroupBackend.outputs.resourceId
      }
      {
        name: 'administration'
        addressPrefix: '10.0.0.32/27'
        networkSecurityGroupResourceId: networkSecurityGroupAdministration.outputs.resourceId
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.0.64/26'
        networkSecurityGroupResourceId: networkSecurityGroupBastion.outputs.resourceId
      }
      {
        name: 'containers'
        addressPrefix: '10.0.2.0/23'
        delegation: 'Microsoft.App/environments'
        networkSecurityGroupResourceId: networkSecurityGroupContainers.outputs.resourceId
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
  }
}

// ========== Bastion host ========== //
var bastionEnabled = bastionConfiguration.?enabled ?? true
var bastionResourceName = bastionConfiguration.?name ?? 'bas-${solutionPrefix}'

module bastionHost 'br/public:avm/res/network/bastion-host:0.6.1' = if (virtualNetworkEnabled && bastionEnabled) {
  name: take('avm.res.network.bastion-host.${bastionResourceName}', 64)
  params: {
    name: bastionResourceName
    location: bastionConfiguration.?location ?? solutionLocation
    skuName: bastionConfiguration.?sku ?? 'Standard'
    enableTelemetry: enableTelemetry
    tags: bastionConfiguration.?tags ?? tags
    virtualNetworkResourceId: bastionConfiguration.?virtualNetworkResourceId ?? virtualNetwork.?outputs.?resourceId
    publicIPAddressObject: {
      name: bastionConfiguration.?publicIpResourceName ?? 'pip-bas${solutionPrefix}'
      zones: []
    }
    disableCopyPaste: false
    enableFileCopy: false
    enableIpConnect: true
    enableShareableLink: true
  }
}

// ========== Virtual machine ========== //
var virtualMachineEnabled = virtualMachineConfiguration.?enabled ?? true
var virtualMachineResourceName = virtualMachineConfiguration.?name ?? 'vm${solutionPrefix}'

module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.13.0' = if (virtualNetworkEnabled && virtualMachineEnabled) {
  name: take('avm.res.compute.virtual-machine.${virtualMachineResourceName}', 64)
  params: {
    name: virtualMachineResourceName
    computerName: take(virtualMachineResourceName, 15)
    location: virtualMachineConfiguration.?location ?? solutionLocation
    tags: virtualMachineConfiguration.?tags ?? tags
    enableTelemetry: enableTelemetry
    vmSize: virtualMachineConfiguration.?vmSize ?? 'Standard_D2s_v3'
    adminUsername: virtualMachineConfiguration.?adminUsername ?? 'adminuser'
    adminPassword: virtualMachineConfiguration.?adminPassword ?? guid(solutionPrefix, subscription().subscriptionId)
    nicConfigurations: [
      {
        name: 'nic-${virtualMachineResourceName}'
        diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
        ipConfigurations: [
          {
            name: '${virtualMachineResourceName}-nic01-ipconfig01'
            subnetResourceId: virtualMachineConfiguration.?subnetResourceId ?? virtualNetwork.outputs.subnetResourceIds[1]
            diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
          }
        ]
      }
    ]
    imageReference: {
      publisher: 'microsoft-dsvm'
      offer: 'dsvm-win-2022'
      sku: 'winserver-2022'
      version: 'latest'
    }
    osDisk: {
      name: 'osdisk-${virtualMachineResourceName}'
      createOption: 'FromImage'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
      diskSizeGB: 128
      caching: 'ReadWrite'
    }
    osType: 'Windows'
    encryptionAtHost: false
    zone: 0
    extensionAadJoinConfig: {
      enabled: true
      typeHandlerVersion: '1.0'
    }
  }
}

// ========== Private DNS Zones for AI Services ========== //
var openAiSubResource = 'account'
var openAiPrivateDnsZones = {
  'privatelink.cognitiveservices.azure.com': openAiSubResource
  'privatelink.openai.azure.com': openAiSubResource
  'privatelink.services.ai.azure.com': openAiSubResource
}

module privateDnsZonesAiServices 'br/public:avm/res/network/private-dns-zone:0.7.1' = [
  for zone in objectKeys(openAiPrivateDnsZones): if (virtualNetworkEnabled) {
    name: take(
      'avm.res.network.private-dns-zone.ai-services.${uniqueString(aiFoundryAiServicesResourceName,zone)}.${solutionPrefix}',
      64
    )
    params: {
      name: zone
      tags: tags
      enableTelemetry: enableTelemetry
      virtualNetworkLinks: [
        {
          name: 'vnetlink-${split(zone, '.')[1]}'
          virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        }
      ]
    }
  }
]

// ========== AI Foundry: AI Services ========== //
var useExistingFoundryProject = !empty(existingFoundryProjectResourceId)
var existingAiFoundryName = useExistingFoundryProject ? split(existingFoundryProjectResourceId, '/')[8] : ''
var aiFoundryAiServicesResourceName = useExistingFoundryProject ? existingAiFoundryName : 'aisa-${solutionPrefix}'

var aiFoundryAiServicesModelDeployment = {
  format: 'OpenAI'
  name: gptModelName
  version: gptModelVersion
  sku: {
    name: modelDeploymentType
    capacity: gptModelCapacity
  }
  raiPolicyName: 'Microsoft.Default'
}

module aiFoundryAiServices 'modules/account/main.bicep' = if (!useExistingFoundryProject) {
  name: take('avm.res.cognitive-services.account.${aiFoundryAiServicesResourceName}', 64)
  params: {
    name: aiFoundryAiServicesResourceName
    tags: tags
    location: aiDeploymentsLocation
    enableTelemetry: enableTelemetry
    projectName: 'aifp-${solutionPrefix}'
    projectDescription: 'aifp-${solutionPrefix}'
    existingFoundryProjectResourceId: ''
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    sku: 'S0'
    kind: 'AIServices'
    disableLocalAuth: true
    customSubDomainName: aiFoundryAiServicesResourceName
    apiProperties: {}
    allowProjectManagement: true
    managedIdentities: {
      systemAssigned: true
    }
    publicNetworkAccess: virtualNetworkEnabled ? 'Disabled' : 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: virtualNetworkEnabled ? 'Deny' : 'Allow'
    }
    privateEndpoints: virtualNetworkEnabled && !useExistingFoundryProject
      ? ([
          {
            name: 'pep-${aiFoundryAiServicesResourceName}'
            customNetworkInterfaceName: 'nic-${aiFoundryAiServicesResourceName}'
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: map(objectKeys(openAiPrivateDnsZones), zone => {
                name: replace(zone, '.', '-')
                privateDnsZoneResourceId: resourceId('Microsoft.Network/privateDnsZones', zone)
              })
            }
          }
        ])
      : []
    deployments: [
      {
        name: aiFoundryAiServicesModelDeployment.name
        model: {
          format: aiFoundryAiServicesModelDeployment.format
          name: aiFoundryAiServicesModelDeployment.name
          version: aiFoundryAiServicesModelDeployment.version
        }
        raiPolicyName: aiFoundryAiServicesModelDeployment.raiPolicyName
        sku: {
          name: aiFoundryAiServicesModelDeployment.sku.name
          capacity: aiFoundryAiServicesModelDeployment.sku.capacity
        }
      }
    ]
  }
}

// Reference existing AI services if using existing project
resource existingAiFoundryAiServices 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = if (useExistingFoundryProject) {
  name: existingAiFoundryName
  scope: resourceGroup(split(existingFoundryProjectResourceId, '/')[2], split(existingFoundryProjectResourceId, '/')[4])
}

// Extract project name from the existing project resource ID
var existingProjectName = useExistingFoundryProject ? split(existingFoundryProjectResourceId, '/')[10] : ''

// Simplified and safer approach for aiFoundryOutputs - ensure consistent structure
var aiFoundryOutputs = useExistingFoundryProject ? {
  resourceId: existingAiFoundryAiServices.id
  name: existingAiFoundryName
  aiProjectInfo: {
    name: existingProjectName
    resourceId: existingFoundryProjectResourceId
    apiEndpoint: 'https://${existingAiFoundryName}.services.ai.azure.com/api/projects/${existingProjectName}'
  }
} : {
  resourceId: aiFoundryAiServices.outputs.resourceId
  name: aiFoundryAiServices.outputs.name
  aiProjectInfo: aiFoundryAiServices.outputs.aiProjectInfo
}

// Define variables for environment variables to ensure they're properly resolved
var azureAiAgentEndpoint = useExistingFoundryProject 
  ? 'https://${existingAiFoundryName}.services.ai.azure.com/api/projects/${existingProjectName}'
  : aiFoundryAiServices.outputs.aiProjectInfo.apiEndpoint

// ========== Private DNS Zone for Cosmos DB ========== //
module privateDnsZonesCosmosDb 'br/public:avm/res/network/private-dns-zone:0.7.0' = if (virtualNetworkEnabled) {
  name: take('avm.res.network.private-dns-zone.cosmos-db.${solutionPrefix}', 64)
  params: {
    name: 'privatelink.documents.azure.com'
    enableTelemetry: enableTelemetry
    virtualNetworkLinks: [
      {
        name: 'vnetlink-cosmosdb'
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
    tags: tags
  }
}

// ========== Cosmos DB ========== //
var cosmosDbResourceName = 'cosmos-${solutionPrefix}'
var cosmosDbDatabaseName = 'macae'
var cosmosDbDatabaseMemoryContainerName = 'memory'

module cosmosDb 'br/public:avm/res/document-db/database-account:0.12.0' = {
  name: take('avm.res.document-db.database-account.${cosmosDbResourceName}', 64)
  params: {
    name: cosmosDbResourceName
    location: solutionLocation
    tags: tags
    enableTelemetry: enableTelemetry
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    databaseAccountOfferType: 'Standard'
    enableFreeTier: false
    networkRestrictions: {
      networkAclBypass: 'None'
      publicNetworkAccess: virtualNetworkEnabled ? 'Disabled' : 'Enabled'
    }
    privateEndpoints: virtualNetworkEnabled
      ? [
          {
            name: 'pep-${cosmosDbResourceName}'
            customNetworkInterfaceName: 'nic-${cosmosDbResourceName}'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [{ privateDnsZoneResourceId: privateDnsZonesCosmosDb.outputs.resourceId }]
            }
            service: 'Sql'
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
          }
        ]
      : []
    sqlDatabases: [
      {
        name: cosmosDbDatabaseName
        containers: [
          {
            name: cosmosDbDatabaseMemoryContainerName
            paths: ['/session_id']
            kind: 'Hash'
            version: 2
          }
        ]
      }
    ]
    locations: [
      {
        locationName: solutionLocation
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilitiesToAdd: ['EnableServerless']
    sqlRoleAssignmentsPrincipalIds: []  // Will be updated after container app is deployed
    sqlRoleDefinitions: [
      {
        roleType: 'CustomRole'
        roleName: 'Cosmos DB SQL Data Contributor'
        name: 'cosmos-db-sql-data-contributor'
        dataAction: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
      }
    ]
  }
}

// ========== Container App Environment ========== //
var containerAppEnvironmentResourceName = 'cae-${solutionPrefix}'
module containerAppEnvironment 'modules/container-app-environment.bicep' = {
  name: take('module.container-app-environment.${containerAppEnvironmentResourceName}', 64)
  params: {
    name: containerAppEnvironmentResourceName
    tags: tags
    location: solutionLocation
    logAnalyticsResourceId: logAnalyticsWorkspaceId
    publicNetworkAccess: 'Enabled'
    zoneRedundant: false
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
    enableTelemetry: enableTelemetry
    subnetResourceId: virtualNetworkEnabled
      ? virtualNetwork.?outputs.?subnetResourceIds[3] ?? ''
      : ''
  }
}

// ========== Container App ========== //
var containerAppResourceName = 'ca-${solutionPrefix}'
var webSiteName = 'app-${solutionPrefix}'

var existingAiFounryProjectName = useExistingFoundryProject ? last(split(existingFoundryProjectResourceId, '/')) : ''
var aiFoundryAiProjectName = useExistingFoundryProject ? existingAiFounryProjectName : 'aifp-${solutionPrefix}'

module containerApp 'br/public:avm/res/app/container-app:0.14.2' = {
  name: take('avm.res.app.container-app.${containerAppResourceName}', 64)
  params: {
    name: containerAppResourceName
    tags: tags
    location: solutionLocation
    enableTelemetry: enableTelemetry
    environmentResourceId: containerAppEnvironment.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [existingUserAssignedIdentity.id]
    }
    ingressTargetPort: 8000
    ingressExternal: true
    activeRevisionsMode: 'Single'
    corsPolicy: {
      allowedOrigins: [
        'https://${webSiteName}.azurewebsites.net'
        'http://${webSiteName}.azurewebsites.net'
      ]
    }
    scaleSettings: {
      maxReplicas: 1
      minReplicas: 1
      rules: [
        {
          name: 'http-scaler'
          http: {
            metadata: {
              concurrentRequests: '100'
            }
          }
        }
      ]
    }
    registries: [
      {
        server: existingContainerRegistry.properties.loginServer
        identity: existingUserAssignedIdentity.id
      }
    ]
    containers: [
      {
        name: 'backend'
        image: '${existingContainerRegistry.properties.loginServer}/macaebackend:${imageTag}'
        resources: {
          cpu: '2.0'
          memory: '4.0Gi'
        }
        env: [
          {
            name: 'COSMOSDB_ENDPOINT'
            value: 'https://${cosmosDbResourceName}.documents.azure.com:443/'
          }
          {
            name: 'COSMOSDB_DATABASE'
            value: cosmosDbDatabaseName
          }
          {
            name: 'COSMOSDB_CONTAINER'
            value: cosmosDbDatabaseMemoryContainerName
          }
          {
            name: 'AZURE_OPENAI_ENDPOINT'
            value: 'https://${aiFoundryAiServicesResourceName}.openai.azure.com/'
          }
          {
            name: 'AZURE_OPENAI_MODEL_NAME'
            value: aiFoundryAiServicesModelDeployment.name
          }
          {
            name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
            value: aiFoundryAiServicesModelDeployment.name
          }
          {
            name: 'AZURE_OPENAI_API_VERSION'
            value: '2025-01-01-preview'
          }
          {
            name: 'APPLICATIONINSIGHTS_INSTRUMENTATION_KEY'
            value: applicationInsights.outputs.instrumentationKey
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: applicationInsights.outputs.connectionString
          }
          {
            name: 'AZURE_AI_SUBSCRIPTION_ID'
            value: subscription().subscriptionId
          }
          {
            name: 'AZURE_AI_RESOURCE_GROUP'
            value: resourceGroup().name
          }
          {
            name: 'AZURE_AI_PROJECT_NAME'
            value: aiFoundryAiProjectName
          }
          {
            name: 'FRONTEND_SITE_NAME'
            value: 'https://${webSiteName}.azurewebsites.net'
          }
          {
            name: 'AZURE_AI_AGENT_ENDPOINT'
            value: azureAiAgentEndpoint
          }
          {
            name: 'AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME'
            value: aiFoundryAiServicesModelDeployment.name
          }
        ]
      }
    ]
  }
}

// Role assignments for Container App to access AI services
var useExistingResourceId = !empty(existingFoundryProjectResourceId)

module cogServiceRoleAssignmentsNew './modules/role.bicep' = if (!useExistingResourceId) {
  params: {
    name: 'new-${guid(containerAppResourceName, aiFoundryOutputs.resourceId)}'
    principalId: containerApp.outputs.systemAssignedMIPrincipalId
    aiServiceName: aiFoundryOutputs.name
  }
  scope: resourceGroup(subscription().subscriptionId, resourceGroup().name)
}

module cogServiceRoleAssignmentsExisting './modules/role.bicep' = if (useExistingResourceId) {
  params: {
    name: 'reuse-${guid(containerAppResourceName, aiFoundryOutputs.aiProjectInfo.resourceId)}'
    principalId: containerApp.outputs.systemAssignedMIPrincipalId
    aiServiceName: aiFoundryOutputs.name
  }
  scope: resourceGroup(split(existingFoundryProjectResourceId, '/')[2], split(existingFoundryProjectResourceId, '/')[4])
}

// Update Cosmos DB with Container App principal ID
module cosmosDbRoleAssignment 'br/public:avm/res/document-db/database-account:0.12.0' = {
  name: take('avm.res.document-db.database-account.role-assignment.${cosmosDbResourceName}', 64)
  params: {
    name: cosmosDbResourceName
    location: solutionLocation
    tags: tags
    enableTelemetry: enableTelemetry
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    databaseAccountOfferType: 'Standard'
    enableFreeTier: false
    networkRestrictions: {
      networkAclBypass: 'None'
      publicNetworkAccess: virtualNetworkEnabled ? 'Disabled' : 'Enabled'
    }
    privateEndpoints: virtualNetworkEnabled
      ? [
          {
            name: 'pep-${cosmosDbResourceName}'
            customNetworkInterfaceName: 'nic-${cosmosDbResourceName}'
            privateDnsZoneGroup: {
              privateDnsZoneGroupConfigs: [{ privateDnsZoneResourceId: privateDnsZonesCosmosDb.outputs.resourceId }]
            }
            service: 'Sql'
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
          }
        ]
      : []
    sqlDatabases: [
      {
        name: cosmosDbDatabaseName
        containers: [
          {
            name: cosmosDbDatabaseMemoryContainerName
            paths: ['/session_id']
            kind: 'Hash'
            version: 2
          }
        ]
      }
    ]
    locations: [
      {
        locationName: solutionLocation
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilitiesToAdd: ['EnableServerless']
    sqlRoleAssignmentsPrincipalIds: [
      containerApp.outputs.systemAssignedMIPrincipalId
    ]
    sqlRoleDefinitions: [
      {
        roleType: 'CustomRole'
        roleName: 'Cosmos DB SQL Data Contributor'
        name: 'cosmos-db-sql-data-contributor'
        dataAction: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
      }
    ]
  }
}

// ========== Frontend server farm ========== //
var webServerFarmEnabled = webServerFarmConfiguration.?enabled ?? true
var webServerFarmResourceName = webServerFarmConfiguration.?name ?? 'asp-${solutionPrefix}'

module webServerFarm 'br/public:avm/res/web/serverfarm:0.4.1' = if (webServerFarmEnabled) {
  name: take('avm.res.web.serverfarm.${webServerFarmResourceName}', 64)
  params: {
    name: webServerFarmResourceName
    tags: tags
    location: webServerFarmConfiguration.?location ?? solutionLocation
    skuName: webServerFarmConfiguration.?skuName ?? 'P1v3'
    skuCapacity: webServerFarmConfiguration.?skuCapacity ?? 3
    reserved: true
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    kind: 'linux'
    zoneRedundant: false
  }
}

// ========== Frontend web site ========== //
var webSiteEnabled = webSiteConfiguration.?enabled ?? true

module webSite 'br/public:avm/res/web/site:0.15.1' = if (webSiteEnabled) {
  name: take('avm.res.web.site.${webSiteName}', 64)
  params: {
    name: webSiteName
    tags: webSiteConfiguration.?tags ?? tags
    location: webSiteConfiguration.?location ?? solutionLocation
    kind: 'app,linux,container'
    enableTelemetry: enableTelemetry
    serverFarmResourceId: webSiteConfiguration.?environmentResourceId ?? webServerFarm.?outputs.resourceId
    appInsightResourceId: applicationInsights.outputs.resourceId
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspaceId }]
    publicNetworkAccess: 'Enabled'

    // Add managed identity configuration
    managedIdentities: {
      userAssignedResourceIds: [existingUserAssignedIdentity.id]
    }

    siteConfig: {
      linuxFxVersion: 'DOCKER|${existingContainerRegistry.properties.loginServer}/${webSiteConfiguration.?containerImageName ?? 'macaefrontend'}:${webSiteConfiguration.?containerImageTag ?? 'latest'}'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: existingUserAssignedIdentity.properties.clientId
    }
    appSettingsKeyValuePairs: {
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
      DOCKER_REGISTRY_SERVER_URL: 'https://${existingContainerRegistry.properties.loginServer}'
      WEBSITES_PORT: '3000'
      WEBSITES_CONTAINER_START_TIME_LIMIT: '1800'
      BACKEND_API_URL: 'https://${containerApp.outputs.fqdn}'
      AUTH_ENABLED: 'false'

      // Add ACR authentication settings
      DOCKER_REGISTRY_SERVER_USERNAME: ''
      DOCKER_REGISTRY_SERVER_PASSWORD: ''
    }
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The FQDN of the Container App.')
output containerAppFqdn string = containerApp.outputs.fqdn

@description('The name of the Container App.')
output containerAppName string = containerApp.outputs.name

@description('The resource ID of the Container App.')
output containerAppResourceId string = containerApp.outputs.resourceId

@description('The system assigned managed identity principal ID of the Container App.')
output containerAppSystemAssignedMIPrincipalId string = containerApp.outputs.systemAssignedMIPrincipalId

@description('The resource group name.')
output resourceGroupName string = resourceGroup().name

@description('The solution prefix used for naming.')
output solutionPrefix string = solutionPrefix

@description('The default url of the website to connect to the Multi-Agent Custom Automation Engine solution.')
output webSiteDefaultHostname string = webSite.outputs.defaultHostname

// ================ //
// Type Definitions //
// ================ //

@export()
@description('The type for the Network Security Group resource configuration.')
type networkSecurityGroupConfigurationType = {
  @description('Optional. If the Network Security Group resource should be deployed or not.')
  enabled: bool?

  @description('Optional. The name of the Network Security Group resource.')
  @maxLength(90)
  name: string?

  @description('Optional. Location for the Network Security Group resource.')
  location: string?

  @description('Optional. The tags to set for the Network Security Group resource.')
  tags: object?

  @description('Optional. The security rules to set for the Network Security Group resource.')
  securityRules: securityRuleType[]?
}

@export()
import { securityRuleType } from 'br/public:avm/res/network/network-security-group:0.5.1'

@export()
@description('The type for the virtual network resource configuration.')
type virtualNetworkConfigurationType = {
  @description('Optional. If the Virtual Network resource should be deployed or not.')
  enabled: bool?

  @description('Optional. The name of the Virtual Network resource.')
  @maxLength(90)
  name: string?

  @description('Optional. Location for the Virtual Network resource.')
  location: string?

  @description('Optional. The tags to set for the Virtual Network resource.')
  tags: object?

  @description('Optional. An array of 1 or more IP Addresses prefixes for the Virtual Network resource.')
  addressPrefixes: string[]?

  @description('Optional. An array of 1 or more subnets for the Virtual Network resource.')
  subnets: subnetType[]?
}

import { roleAssignmentType } from 'br/public:avm/utl/types/avm-common-types:0.5.1'
type subnetType = {
  @description('Optional. The Name of the subnet resource.')
  name: string

  @description('Conditional. The address prefix for the subnet. Required if `addressPrefixes` is empty.')
  addressPrefix: string?

  @description('Conditional. List of address prefixes for the subnet. Required if `addressPrefix` is empty.')
  addressPrefixes: string[]?

  @description('Optional. Application gateway IP configurations of virtual network resource.')
  applicationGatewayIPConfigurations: object[]?

  @description('Optional. The delegation to enable on the subnet.')
  delegation: string?

  @description('Optional. The resource ID of the NAT Gateway to use for the subnet.')
  natGatewayResourceId: string?

  @description('Optional. The resource ID of the network security group to assign to the subnet.')
  networkSecurityGroupResourceId: string?

  @description('Optional. enable or disable apply network policies on private endpoint in the subnet.')
  privateEndpointNetworkPolicies: ('Disabled' | 'Enabled' | 'NetworkSecurityGroupEnabled' | 'RouteTableEnabled')?

  @description('Optional. enable or disable apply network policies on private link service in the subnet.')
  privateLinkServiceNetworkPolicies: ('Disabled' | 'Enabled')?

  @description('Optional. Array of role assignments to create.')
  roleAssignments: roleAssignmentType[]?

  @description('Optional. The resource ID of the route table to assign to the subnet.')
  routeTableResourceId: string?

  @description('Optional. An array of service endpoint policies.')
  serviceEndpointPolicies: object[]?

  @description('Optional. The service endpoints to enable on the subnet.')
  serviceEndpoints: string[]?

  @description('Optional. Set this property to false to disable default outbound connectivity for all VMs in the subnet. This property can only be set at the time of subnet creation and cannot be updated for an existing subnet.')
  defaultOutboundAccess: bool?

  @description('Optional. Set this property to Tenant to allow sharing subnet with other subscriptions in your AAD tenant. This property can only be set if defaultOutboundAccess is set to false, both properties can only be set if subnet is empty.')
  sharingScope: ('DelegatedServices' | 'Tenant')?
}

@export()
@description('The type for the Bastion resource configuration.')
type bastionConfigurationType = {
  @description('Optional. If the Bastion resource should be deployed or not.')
  enabled: bool?

  @description('Optional. The name of the Bastion resource.')
  @maxLength(90)
  name: string?

  @description('Optional. Location for the Bastion resource.')
  location: string?

  @description('Optional. The tags to set for the Bastion resource.')
  tags: object?

  @description('Optional. The SKU for the Bastion resource.')
  sku: ('Basic' | 'Developer' | 'Premium' | 'Standard')?

  @description('Optional. The Virtual Network resource id where the Bastion resource should be deployed.')
  virtualNetworkResourceId: string?

  @description('Optional. The name of the Public Ip resource created to connect to Bastion.')
  publicIpResourceName: string?
}

@export()
@description('The type for the virtual machine resource configuration.')
type virtualMachineConfigurationType = {
  @description('Optional. If the Virtual Machine resource should be deployed or not.')
  enabled: bool?

  @description('Optional. The name of the Virtual Machine resource.')
  @maxLength(90)
  name: string?

  @description('Optional. Location for the Virtual Machine resource.')
  location: string?

  @description('Optional. The tags to set for the Virtual Machine resource.')
  tags: object?

  @description('Optional. Specifies the size for the Virtual Machine resource.')
  vmSize: string?

  @description('Optional. Admin username for the Virtual Machine resource.')
  adminUsername: string?

  @description('Optional. Admin password for the Virtual Machine resource.')
  adminPassword: string?

  @description('Optional. The subnet resource ID for the Virtual Machine resource.')
  subnetResourceId: string?
}

@export()
@description('The type for the Web Server Farm resource configuration.')
type webServerFarmConfigurationType = {
  @description('Optional. If the Web Server Farm resource should be deployed or not.')
  enabled: bool?

  @description('Optional. The name of the Web Server Farm resource.')
  @maxLength(90)
  name: string?

  @description('Optional. Location for the Web Server Farm resource.')
  location: string?

  @description('Optional. The tags to set for the Web Server Farm resource.')
  tags: object?

  @description('Optional. The SKU name for the Web Server Farm resource.')
  skuName: string?

  @description('Optional. The SKU capacity for the Web Server Farm resource.')
  skuCapacity: int?
}

@export()
@description('The type for the Web Site resource configuration.')
type webSiteConfigurationType = {
  @description('Optional. If the Web Site resource should be deployed or not.')
  enabled: bool?

  @description('Optional. The name of the Web Site resource.')
  @maxLength(90)
  name: string?

  @description('Optional. Location for the Web Site resource.')
  location: string?

  @description('Optional. The tags to set for the Web Site resource.')
  tags: object?

  @description('Optional. The container image name for the Web Site resource.')
  containerImageName: string?

  @description('Optional. The container image tag for the Web Site resource.')
  containerImageTag: string?

  @description('Optional. The container name for the Web Site resource.')
  containerName: string?

  @description('Optional. The environment resource ID for the Web Site resource.')
  environmentResourceId: string?
}
