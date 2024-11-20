targetScope = 'managementGroup'

param managementGroupId string
param managementGroupName string
param subscriptionId string
param principalId array
param appId string
@secure()
param spPassword string
param time string = utcNow()
param location string = deployment().location

var tenantId = tenant().tenantId
var subscriptionGuid = replace(subscriptionId, '/subscriptions/', '')
var resourceGroupName = 'rg-prosimo-${take(guid(subscriptionGuid), 8)}'
var managedIdentityName = 'prosimo-sub-onboard'
var keyVaultName = 'kv-prosimo'
var tags = {
  'Prosimo Login': 'https://admin.prosimo.io/signin'
  'Purpose': 'Used to store Key Vault and Managed Identity for Prosimo Onboarding'
  'Deployed from': 'https://github.com/prosimo-io/azureonboarding'
}
var identityTags = {
  'Purpose': 'Used to access Key Vault to onboard Prosimo subscriptions'
  'Key Vault Permissions': 'Secret: Get, List, Set'
}

resource prosimoServicePrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'ProsimoServicePrincipal'
  location: location
}

module keyVaultRg 'Modules/resource-group.bicep' = {
  scope: subscription(subscriptionGuid)
  name: 'createKvRg-${time}'
  params: {
    resourceGroupName: resourceGroupName
    tags: tags
    location: location
  }
}

module managedIdentity './Modules/managed-identity.bicep' = {
  scope: resourceGroup(subscriptionGuid, resourceGroupName)
  dependsOn: [
    keyVaultRg
  ]
  name: 'managedIdentity-${time}'
  params: {
    identityName: managedIdentityName
    location: location
    tags: identityTags
  }
}

// Additional role and key vault modules...

output subscriptionId string = subscriptionGuid
output tenantId string = tenantId
output clientId string = appId
