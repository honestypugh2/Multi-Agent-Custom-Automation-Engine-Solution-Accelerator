metadata name = 'Azure Container Registry Deployment'
metadata description = 'This template deploys only the Azure Container Registry and its dependencies for the Multi-Agent Custom Automation Engine solution.'

@description('Required. Name of the environment to deploy the solution into.')
param environmentName string

@description('Required. Location for all Resources.')
param solutionLocation string = resourceGroup().location

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

@description('Set the image tag for the container images used in the solution. Default is "latest".')
param imageTag string = 'latest'

// Generate solution prefix same as main.bicep
param solutionPrefix string = 'macae${padLeft(take(toLower(uniqueString(subscription().id, environmentName, resourceGroup().location, resourceGroup().name)), 12), 12, '0')}'

@description('Optional. The tags to apply to all deployed Azure resources.')
param tags object = {
  app: solutionPrefix
  location: solutionLocation
  deployment: 'acr-only'
}

@description('Optional. The configuration to apply for the Multi-Agent Custom Automation Engine Managed Identity resource.')
param userAssignedManagedIdentityConfiguration object = {
  enabled: true
  name: 'id-${solutionPrefix}'
  location: solutionLocation
  tags: tags
}

@description('Optional. The configuration to apply for the Container Registry resource.')
param containerRegistryConfiguration object = {
  enabled: true
  name: 'cr${solutionPrefix}'
  location: solutionLocation
  tags: tags
  publicNetworkAccess: 'Enabled'
}

// ========== Resource Group Tag ========== //
resource resourceGroupTags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  properties: {
    tags: {
      ...tags
      TemplateName: 'MacaeAcrOnly'
      DeploymentStep: 'Step1-ACR'
    }
  }
}

// ========== User assigned identity ========== //
var userAssignedManagedIdentityEnabled = userAssignedManagedIdentityConfiguration.?enabled ?? true
var userAssignedManagedIdentityResourceName = userAssignedManagedIdentityConfiguration.?name ?? 'id-${solutionPrefix}'
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (userAssignedManagedIdentityEnabled) {
  name: take('avm.res.managed-identity.user-assigned-identity.${userAssignedManagedIdentityResourceName}', 64)
  params: {
    name: userAssignedManagedIdentityResourceName
    tags: userAssignedManagedIdentityConfiguration.?tags ?? tags
    location: userAssignedManagedIdentityConfiguration.?location ?? solutionLocation
    enableTelemetry: enableTelemetry
  }
}

// ========== Container Registry ========== //
var containerRegistryEnabled = containerRegistryConfiguration.?enabled ?? true
var containerRegistryResourceName = containerRegistryConfiguration.?name ?? 'cr${solutionPrefix}'

module containerRegistry 'modules/container-registry.bicep' = if (containerRegistryEnabled) {
  name: take('module.container-registry.${containerRegistryResourceName}', 64)
  params: {
    name: containerRegistryResourceName
    location: containerRegistryConfiguration.?location ?? solutionLocation
    tags: containerRegistryConfiguration.?tags ?? tags
    enableTelemetry: enableTelemetry
    acrSku: 'Standard'
    publicNetworkAccess: containerRegistryConfiguration.?publicNetworkAccess ?? 'Enabled'
    userAssignedIdentityResourceId: userAssignedIdentity.outputs.resourceId
    userAssignedIdentityPrincipalId: userAssignedIdentity.outputs.principalId
    additionalRoleAssignments: []
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource group name.')
output resourceGroupName string = resourceGroup().name

@description('The solution prefix used for naming.')
output solutionPrefix string = solutionPrefix

@description('The name of the Container Registry.')
output containerRegistryName string = containerRegistry.outputs.name

@description('The login server URL of the container registry.')
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

@description('The resource ID of the Container Registry.')
output containerRegistryResourceId string = containerRegistry.outputs.resourceId

@description('The name of the user-assigned managed identity.')
output userAssignedIdentityName string = userAssignedIdentity.outputs.name

@description('The resource ID of the user-assigned managed identity.')
output userAssignedIdentityResourceId string = userAssignedIdentity.outputs.resourceId

@description('The principal ID of the user-assigned managed identity.')
output userAssignedIdentityPrincipalId string = userAssignedIdentity.outputs.principalId

@description('The client ID of the user-assigned managed identity.')
output userAssignedIdentityClientId string = userAssignedIdentity.outputs.clientId
