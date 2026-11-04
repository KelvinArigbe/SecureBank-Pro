@description('Azure region for the App Service resources. Use the same region as the existing Key Vault where practical.')
param location string = resourceGroup().location

param appServicePlanName string = 'sbp-plan'
@description('App Service name must be globally unique.')
param webAppName string = 'sbp-web-${uniqueString(resourceGroup().id)}'

param keyVaultName string
param sqlDbPasswordSecretName string = 'sqlAdminPassword'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|24-lts'
    }
  }
}

resource vault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource accessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-02-01' = {
  name: '${vault.name}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: webApp.identity.principalId
        permissions: {
          secrets: [ 'get' ]
        }
      }
    ]
  }
  dependsOn: [
    webApp
  ]
}

// Create app settings after the identity has been granted Key Vault secret-read access.
resource appSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: webApp
  name: 'appsettings'
  properties: {
    DB_PASSWORD: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${sqlDbPasswordSecretName})'
  }
  dependsOn: [
    accessPolicy
  ]
}

output appUrl string = 'https://${webApp.properties.defaultHostName}'
