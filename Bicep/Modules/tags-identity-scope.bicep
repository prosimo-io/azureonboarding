param tags object
param identityName string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: identityName
}

resource tagResources 'Microsoft.Resources/tags@2021-04-01' = {
  scope: identity
  name: 'default'
  properties: {
    tags: tags
  }
}
