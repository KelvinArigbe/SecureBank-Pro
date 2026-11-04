@description('Azure region for the lab resources.')
param location string = resourceGroup().location

@description('Globally unique Azure SQL logical server name. Override if this default is already taken.')
param sqlServerName string = 'sbp-sql-${uniqueString(resourceGroup().id)}'

param sqlDbName string = 'sbp-database'
param adminLogin string = 'sqladmin'

@secure()
param adminPassword string

@description('Globally unique Key Vault name. Override if this default is already taken.')
param keyVaultName string = 'sbp-kv-${uniqueString(resourceGroup().id)}'

param sqlDbPasswordSecretName string = 'sqlAdminPassword'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
  }
}

resource sqlServer 'Microsoft.Sql/servers@2022-11-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    version: '12.0'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2022-11-01-preview' = {
  name: '${sqlServer.name}/${sqlDbName}'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
  }
}

resource sqlAdminSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: sqlDbPasswordSecretName
  properties: {
    value: adminPassword
    contentType: 'SQL Server administrator password for the SecureBank-Pro lab'
  }
}

output keyVaultName string = keyVault.name
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDb.name
output sqlAdminPasswordSecretName string = sqlAdminSecret.name
