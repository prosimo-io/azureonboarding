param(
  [string] [Parameter(Mandatory=$true)] $prosimoTeamName,
  [string] [Parameter(Mandatory=$true)] $managementGroupName,
  [string] [Parameter(Mandatory=$true)] $tenantId,
  [string] [Parameter(Mandatory=$true)] $keyVaultName,
  [string] [Parameter(Mandatory=$true)] $ApiKvSecretName,
  [string] [Parameter(Mandatory=$true)] $ClientIdKvSecretName,
  [string] [Parameter(Mandatory=$true)] $PrincipalKvSecretName
)

$apiUrl = "https://" + $prosimoTeamName + ".admin.prosimo.io/api/cloud/creds"
$vaultUrl = "https://" + $keyVaultName + ".vault.azure.net"

$prosimoApiSecretURI = $vaultUrl + '/secrets/' + $ApiKvSecretName + '?api-version=2016-10-01'
$clientSecretUri = $vaultUrl + '/secrets/' + $clientId + '?api-version=2016-10-01'
$spSecretURI = $vaultUrl + '/secrets/' + $clientSecret + '?api-version=2016-10-01'

#// Retreive access token from Azure Instance Metadata service via User Managed Identity assigned to script resource with access to Azure Key Vault 
$Response = Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata='true'}
$KeyVaultToken = $Response.access_token

#// Retreive passwords from Key Vault using access token
$clientId = (Invoke-RestMethod -Uri $clientSecretUri -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}).value
$clientSecret = (Invoke-RestMethod -Uri $spSecretURI -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}).value
$ApiToken = (Invoke-RestMethod -Uri $prosimoApiSecretURI -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}).value

#// Check to see if Azure Resource Graph module is loaded and load if not
If (-not (Get-Module -Name Az.ResourceGraph)) { Install-Module -Name Az.ResourceGraph -Force }

#// Search Azure Resource Graph for all subscriptions in a management group
$subscriptionList = (Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions'" -ManagementGroup $managementGroupName).id

#// Build Prosimo API header using API token
$headers = @{
  "content-type" = 'application/json'
  "Prosimo-ApiToken" = $ApiToken
}

#// Retreive existing Azure Prosimo subscriptions
$existingAccounts = Invoke-RestMethod -Method Get -Uri $apiUrl -Headers $headers

#// Loop through all subscriptions
foreach ($subscription in $subscriptionList) {
  $subscriptionId = $subscription.Split("/")[2]
  $subscriptionName = (Get-AzSubscription -SubscriptionId $subscriptionId).Name 

  #// Create JSON body for Prosimo API to onboard new Azure account
  $body = @"
  {
    "cloudType": "AZURE",
    "keyType": "AZUREKEY",
    "name": "$subscriptionName",
    "details": {
      "clientID": "$clientId",
      "clientSecret": "$clientSecret",
      "subscriptionID": "$subscriptionId",
      "tenantID": "$tenantId"
    }
  }
"@

  #// If account does not exist add it to Prosimo SaaS dashboard
  if ($subscriptionId -notin $existingAccounts.data.accountID) { Invoke-RestMethod -Method Post -Uri $apiUrl -Headers $headers -Body $body }
  
}