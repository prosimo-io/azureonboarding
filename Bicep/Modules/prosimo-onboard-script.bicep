param name string
param location string = resourceGroup().location
param identityId string
param prosimoTeamName string
param keyVaultName string
param managementGroupName string

var ApiKvSecretName = 'prosimoApiPassword'
var ClientIdKvSecretName = 'prosimoSPClientId'
var PrincipalKvSecretName = 'prosimoSPpassword'

var tenantId = tenant().tenantId
var scriptUrl = 'https://raw.githubusercontent.com/prosimo-io/azureonboarding/em-checkapifirst/PowerShell/onboard-cloud-account.ps1'

resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: name
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    azPowerShellVersion: '7.3'
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
    timeout: 'PT1H'
    arguments: '-prosimoTeamName \'${prosimoTeamName}\' -managementGroupName \'${managementGroupName}\' -tenantId \'${tenantId}\' -keyVaultName \'${keyVaultName}\' -ApiKvSecretName \'${ApiKvSecretName}\' -ClientIdKvSecretName \'${ClientIdKvSecretName}\' -PrincipalKvSecretName \'${PrincipalKvSecretName}\' '
    primaryScriptUri: scriptUrl
  }
}

output scriptId string = script.id
