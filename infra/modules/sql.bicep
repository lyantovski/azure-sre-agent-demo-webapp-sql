@description('Location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Unique suffix for resource names')
param uniqueSuffix string

@description('Azure AD admin object ID')
param adminObjectId string

@description('Azure AD admin login name')
param adminLoginName string

var sqlServerName = 'sql-${environmentName}-${uniqueSuffix}'
var sqlDatabaseName = 'sqldb-${environmentName}'

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      login: adminLoginName
      sid: adminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true // Entra-only authentication
    }
  }
}

// Allow Azure services to access the SQL server (required for az sql db query and managed identity auth)
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2 GB
  }
}

output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name
