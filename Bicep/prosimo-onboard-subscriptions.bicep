targetScope = 'managementGroup'

param location string = deployment().location
param prosimoTeamName string
param keyVaultId string
param prosimoApiToken string
param managementGroupName string
param subscriptionId string
param time string = utcNow()

var scriptRole = json(loadTextContent('../Parameters/script-role.json'))
var reader = '/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
var resourceGroupName = 'rg-prosimo-${take(guid(subscriptionGuid), 8)}'
var keyVaultName = split(keyVaultId, '/')[8]
var subscriptionGuid = replace(subscriptionId, '/subscriptions/', '')
var ApiKvSecretName = 'prosimoApiPassword'
var managedIdentityName = 'prosimo-sub-onboard'
var rgTags = {
  'Prosimo Login': 'https://${prosimoTeamName}.admin.prosimo.io/'
  'Prosimo API': 'https://${prosimoTeamName}.admin.prosimo.io/apidocs/team/index.html'
  'Purpose': 'Used to store Key Vault and Managed Identity for Prosimo Onboarding'
  'Deployed from': 'https://github.com/prosimo-io/azureonboarding'
}
var identityTags = {
  'Prosimo Login': 'https://${prosimoTeamName}.admin.prosimo.io/'
  'Prosimo API': 'https://${prosimoTeamName}.admin.prosimo.io/apidocs/team/index.html'
  'Purpose': 'Used to access Key Vault to onboard Prosimo subscriptions'
  'IAM Permissions': 'Reader at ${managementGroupName}, Deployment Script at ${resourceGroupName}'
  'Key Vault': keyVaultId
  'Key Vault Permissions': 'Secret: Get, List, Set'
}
var keyVaultTags = {
  'Prosimo Login': 'https://${prosimoTeamName}.admin.prosimo.io/'
  'Prosimo API': 'https://${prosimoTeamName}.admin.prosimo.io/apidocs/team/index.html'
  'Purpose': 'Used to store Service Principal ID, SP Password, and Prosimo API token'
}

resource scriptResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' existing = {
  scope: subscription(subscriptionGuid)
  name: resourceGroupName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  scope: resourceGroup(subscriptionGuid, resourceGroupName)
  name: managedIdentityName
}

module tagRg 'Modules/tags-rg-scope.bicep' = {
  scope: subscription(subscriptionGuid)
  name: 'updateRgTags-${time}'
  params: {
    tags: rgTags
    resourceGroupName: resourceGroupName
    subscriptionId: subscriptionGuid
  }
}

module tagIdentity 'Modules/tags-identity-scope.bicep' = {
  scope: scriptResourceGroup
  name: 'updateIdentityTags-${time}'
  params: {
    tags: identityTags
    identityName: managedIdentity.name
  }
}

module tagKeyVault 'Modules/tags-keyvault-scope.bicep' = {
  scope: scriptResourceGroup
  name: 'updateKvTags-${time}'
  params: {
    keyVaultName: keyVaultName
    tags: keyVaultTags
  }
}

module createApiKvSecret 'Modules/keyvault-secret.bicep' = {
  scope: scriptResourceGroup
  name: 'addApi-${time}'
  params: {
    keyVaultName: keyVaultName
    secretName: ApiKvSecretName
    secretValue: prosimoApiToken
  }
}

module createScriptRole './Modules/define-role-sub-scope.bicep' = {
  scope: subscription(subscriptionGuid)
  name: 'scriptRole-${time}'
  params: {
    assignmentScope: subscriptionId
    roleDescription: scriptRole.description
    roleName: scriptRole.roleName
    rolePermissions: scriptRole.permissions
  }
}

module assignMgtReaderRole './Modules/assign-role-mgt-scope.bicep' = {
  name: 'assignMgtReader-${time}'
  params: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleId: reader
    assignmentGuid: guid(managementGroup().id, reader, managedIdentity.id)
  }
}

module assignRgReaderRole './Modules/assign-role-rg-scope.bicep' = {
  scope: resourceGroup(subscriptionGuid, resourceGroupName)
  dependsOn: [
    scriptResourceGroup
  ]
  name: 'assignRgReader-${time}'
  params: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleId: reader
    assignmentGuid: guid(scriptResourceGroup.id, reader, managedIdentity.id)
  }
}

module assignScriptRole './Modules/assign-role-sub-scope.bicep' = {
  scope: subscription(subscriptionGuid)
  name: 'assignScriptRole-${time}'
  params: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleId: createScriptRole.outputs.roleId
    assignmentGuid: guid(subscriptionId, reader, managedIdentity.id)
  }
}

module onboardSubscriptions './Modules/prosimo-onboard-script.bicep' = {
  scope: resourceGroup(subscriptionGuid, resourceGroupName)
  dependsOn: [
    scriptResourceGroup
    assignScriptRole
    assignRgReaderRole
    assignMgtReaderRole
    createApiKvSecret
  ]
  name: 'onboardSubs-${time}'
  params: {
    identityId: managedIdentity.id
    name: 'prosimo-onboard-subscriptions'
    prosimoTeamName: prosimoTeamName
    managementGroupName: managementGroupName
    location: location
    keyVaultName: keyVaultName
  }
}
