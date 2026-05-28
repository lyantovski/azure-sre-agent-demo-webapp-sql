@description('Location for all resources')
param location string

@description('Environment name')
param environmentName string

@description('Unique suffix for resource names')
param uniqueSuffix string

@description('VNet subnet ID for VNet integration')
param vnetSubnetId string

@description('SQL Server FQDN')
param sqlServerFqdn string

@description('SQL Database name')
param sqlDatabaseName string

var appServicePlanName = 'asp-${environmentName}-${uniqueSuffix}'
var webAppName = 'app-${environmentName}-${uniqueSuffix}'

// App Service Plan (Linux)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'P1v3' // Premium V3 required for VNet integration
    tier: 'PremiumV3'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux
  }
}

// Web App with System-Assigned Managed Identity
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  tags: {
    'azd-service-name': 'web'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'SQL_SERVER'
          value: sqlServerFqdn
        }
        {
          name: 'SQL_DATABASE'
          value: '${sqlDatabaseName}-misconfigured'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
    virtualNetworkSubnetId: vnetSubnetId
    vnetRouteAllEnabled: true // Route all traffic through VNet
  }
}

output webAppId string = webApp.id
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppPrincipalId string = webApp.identity.principalId
