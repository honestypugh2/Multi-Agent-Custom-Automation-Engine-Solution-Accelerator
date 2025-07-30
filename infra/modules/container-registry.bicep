metadata name = 'Azure Container Registry Module'
metadata description = 'This module deploys an Azure Container Registry with appropriate role assignments for the Multi-Agent Custom Automation Engine solution.'

@description('Required. The name of the Container Registry resource.')
@maxLength(50)
param name string

@description('Optional. Location for the Container Registry resource.')
@metadata({ azd: { type: 'location' } })
param location string = resourceGroup().location

@description('Optional. The tags to apply to the Container Registry resource.')
param tags object = {}

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

@description('Optional. The SKU of the Container Registry.')
@allowed(['Basic', 'Standard', 'Premium'])
param acrSku string = 'Standard'

@description('Optional. Whether or not public network access is allowed for the container registry.')
// @allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

// @description('Optional. Enable admin user for the container registry.')
// param adminUserEnabled bool = false

// @description('Required. The principal ID of the user-assigned managed identity that needs access to the registry.')
// param managedIdentityPrincipalId string

@description('Required. The resource ID of the user-assigned managed identity.')
param userAssignedIdentityResourceId string

@description('Required. The principal ID of the user-assigned managed identity.')
param userAssignedIdentityPrincipalId string

@description('Optional. Additional role assignments for the container registry.')
param additionalRoleAssignments array = []

// Deploy Azure Container Registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.0' = {
  name: take('avm.res.container-registry.registry.${name}', 64)
  params: {
    name: name
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
    acrSku: acrSku
    publicNetworkAccess: publicNetworkAccess
    // acrAdminUserEnabled: adminUserEnabled
    roleAssignments: concat([
      {
        principalId: userAssignedIdentityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'AcrPull'
      }
      {
        principalId: userAssignedIdentityPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'AcrPush'
      }
    ], additionalRoleAssignments)
  }
}

// Outputs
@description('The resource ID of the Container Registry.')
output resourceId string = containerRegistry.outputs.resourceId

@description('The name of the Container Registry.')
output name string = containerRegistry.outputs.name

@description('The login server URL of the Container Registry.')
output loginServer string = containerRegistry.outputs.loginServer

@description('The location of the Container Registry.')
output location string = containerRegistry.outputs.location

@description('The resource group name of the Container Registry.')
output resourceGroupName string = containerRegistry.outputs.resourceGroupName

@description('The principal ID of the system assigned identity.')
output systemAssignedMIPrincipalId string = containerRegistry.outputs.?systemAssignedMIPrincipalId ?? ''

// @description('Admin username for the Container Registry (if admin user is enabled).')
// output adminUsername string = containerRegistry.outputs.?adminUsername ?? ''
