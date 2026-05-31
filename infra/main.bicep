targetScope = 'resourceGroup'

@description('Primary location for all resources')
param location string = 'swedencentral'

@description('Environment name (e.g., dev, test, prod)')
param environmentName string = 'dev'

@description('Unique suffix for resource names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Current user object ID for SQL admin')
param currentUserObjectId string

@description('Current user principal name for SQL admin')
param currentUserName string

// VNet Module
module vnet 'modules/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    location: location
    environmentName: environmentName
    uniqueSuffix: uniqueSuffix
  }
}

// SQL Server and Database Module
module sql 'modules/sql.bicep' = {
  name: 'sql-deployment'
  params: {
    location: location
    environmentName: environmentName
    uniqueSuffix: uniqueSuffix
    adminObjectId: currentUserObjectId
    adminLoginName: currentUserName
  }
}

// Private Endpoint Module
module privateEndpoint 'modules/privateEndpoint.bicep' = {
  name: 'private-endpoint-deployment'
  params: {
    location: location
    environmentName: environmentName
    uniqueSuffix: uniqueSuffix
    sqlServerId: sql.outputs.sqlServerId
    vnetId: vnet.outputs.vnetId
    privateEndpointSubnetId: vnet.outputs.privateEndpointSubnetId
  }
}

// Web App Module
module webapp 'modules/webapp.bicep' = {
  name: 'webapp-deployment'
  params: {
    location: location
    environmentName: environmentName
    uniqueSuffix: uniqueSuffix
    vnetSubnetId: vnet.outputs.appSubnetId
    sqlServerFqdn: sql.outputs.sqlServerFqdn
    sqlDatabaseName: sql.outputs.sqlDatabaseName
  }
}

// SQL Role Assignment Module
// Note: Deployer must have Microsoft.Authorization/roleAssignments/write at SQL server scope
module sqlRoleAssignment 'modules/sqlRoleAssignment.bicep' = {
  name: 'sql-role-assignment-deployment'
  params: {
    sqlServerId: sql.outputs.sqlServerId
    sqlServerName: sql.outputs.sqlServerName
    webAppPrincipalId: webapp.outputs.webAppPrincipalId
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output webAppUrl string = webapp.outputs.webAppUrl
output webAppName string = webapp.outputs.webAppName
output sqlServerName string = sql.outputs.sqlServerName
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output sqlDatabaseName string = sql.outputs.sqlDatabaseName
output webAppPrincipalId string = webapp.outputs.webAppPrincipalId
