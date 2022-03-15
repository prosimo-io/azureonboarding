targetScope = 'subscription'

param tags object
param subscriptionId string
param resourceGroupName string
param time string = utcNow()

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription(subscriptionId)
  name: resourceGroupName
}

module tagRg 'tags-resource-scope.bicep' = {
  scope: rg
  name: 'tagRg-${time}'
  params: {
    tags: tags
  }
}
