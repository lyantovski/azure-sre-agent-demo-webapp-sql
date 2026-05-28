@description('SQL Server resource ID')
param sqlServerId string

@description('Web App managed identity principal ID')
param webAppPrincipalId string

@description('SQL Server name')
param sqlServerName string

// Note: This assigns the Azure RBAC role, but does NOT create the SQL database user
// The SQL database user must be created separately by someone with SQL admin privileges

// Reference existing SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' existing = {
  name: sqlServerName
}

// Assign SQL DB Contributor role to Web App's managed identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sqlServerId, webAppPrincipalId, 'SqlDbContributor')
  scope: sqlServer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec') // SQL DB Contributor
    principalId: webAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
