param tags object
param keyVaultName string

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
}

resource tagResources 'Microsoft.Resources/tags@2021-04-01' = {
  scope: keyVault
  name: 'default'
  properties: {
    tags: tags
  }
}
