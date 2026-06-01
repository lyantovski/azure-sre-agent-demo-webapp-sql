# Azure SRE Agent Demo

A demonstration application showcasing Azure SQL Database connectivity with Managed Identity authentication in a private network environment.

## Architecture

This application demonstrates:
- Azure App Service with System-Assigned Managed Identity
- Azure SQL Database with Entra ID (Azure AD) authentication only
- Private Endpoint for secure SQL connectivity
- VNet integration for the App Service
- Health check endpoints for monitoring

## Prerequisites

- Azure CLI installed and authenticated
- Azure Developer CLI (azd) installed
- Appropriate Azure subscription permissions:
  - Resource creation in a resource group
  - Role assignment permissions for SQL Server
  - User Access Administrator or Owner role

## Deployment

### 1. Initialize and Provision

```bash
# Login to Azure
az login

azd auth login

# Initialize the environment (first time only)
azd init

# Provision infrastructure and deploy application
azd up
```

The deployment will:
1. **Preprovision Hook**: Capture your user identity for SQL admin setup
2. **Infrastructure Deployment**: 
   - Create VNet with subnets
   - Deploy Azure SQL Server with Entra-only authentication
   - Create SQL Database
   - Set up Private Endpoint for SQL
   - Deploy App Service with VNet integration
   - Configure Managed Identity
   - Assign Azure RBAC roles
3. **Postprovision Hook**: **Automatically create SQL database user for the managed identity**
4. **App Deployment**: Build and deploy the Node.js application

### 2. What the Postprovision Hook Does

The postprovision hook (`scripts/postprovision.sh` or `scripts/postprovision.ps1`) automatically:

1. Retrieves deployment outputs (resource group, SQL server, database, web app names)
2. Connects to the SQL database as the Entra admin (your user account)
3. Executes T-SQL to:
   ```sql
   -- Create contained database user for the managed identity
   CREATE USER [app-name] FROM EXTERNAL PROVIDER;
   
   -- Grant minimal permissions (SELECT) for health check
   ALTER ROLE db_datareader ADD MEMBER [app-name];
   ```

This step is **critical** because:
- Azure RBAC role assignments alone do NOT create SQL database users
- Without this step, the managed identity cannot authenticate to the database
- The error would be: `Login failed for user '<token-identified principal>'`

## Endpoints

After deployment, the application exposes:

- `GET /` - Root endpoint with available routes
- `GET /health` - Basic application health check
- `GET /health/sql` - SQL Database connectivity health check

### Expected Responses

**Healthy SQL Connection:**
```json
{
  "status": "healthy",
  "message": "Successfully connected to Azure SQL Database",
  "server": "sql-dev-xxxxx.database.windows.net",
  "database": "sqldb-dev",
  "timestamp": "2026-01-25T17:30:00.000Z"
}
```

**Unhealthy SQL Connection (if postprovision fails):**
```json
{
  "status": "unhealthy",
  "error": "Login failed for user '<token-identified principal>'",
  "errorType": "ConnectionError",
  "timestamp": "2026-01-25T17:30:00.000Z",
  "sqlServer": "sql-dev-xxxxx.database.windows.net",
  "sqlDatabase": "sqldb-dev",
  "hint": "The managed identity may not have a database user created. Run: CREATE USER [<webapp-name>] FROM EXTERNAL PROVIDER; ALTER ROLE db_datareader ADD MEMBER [<webapp-name>];"
}
```

## Manual Database User Creation (if needed)

If the postprovision hook fails or you need to manually create the database user:

1. **Connect to the database** using Azure CLI or SQL Server Management Studio as the Entra admin:
   ```bash
   # Using Azure CLI
   az sql db query \
     --resource-group <resource-group> \
     --server <sql-server-name> \
     --name <database-name> \
     --query "SELECT SYSTEM_USER"
   ```

2. **Create the database user** for the managed identity:
   ```sql
   -- Replace <webapp-name> with your App Service name
   CREATE USER [<webapp-name>] FROM EXTERNAL PROVIDER;
   
   -- Grant minimal permissions for health check
   ALTER ROLE db_datareader ADD MEMBER [<webapp-name>];
   
   -- Optional: Grant write permissions if needed
   -- ALTER ROLE db_datawriter ADD MEMBER [<webapp-name>];
   ```

3. **Verify the user** was created:
   ```sql
   SELECT name, type_desc, authentication_type_desc 
   FROM sys.database_principals 
   WHERE name = '<webapp-name>';
   ```

## Troubleshooting

### "Login failed for user" Error

**Symptom**: `/health/sql` returns authentication error

**Common Causes**:
1. Database user not created (postprovision hook failed)
2. Managed identity not enabled on App Service
3. SQL connection string incorrect
4. Private endpoint connectivity issues

**Resolution**:
1. Check if managed identity is enabled:
   ```bash
   az webapp identity show --name <webapp-name> --resource-group <rg>
   ```

2. Manually run the postprovision script:
   ```bash
   ./scripts/postprovision.sh
   ```

3. Verify database user exists (see Manual Database User Creation above)

### "Failed to resolve the signed-in Azure CLI identity" Error

**Symptom**: `azd up` fails in the preprovision hook before infrastructure deployment starts

**Cause**: The current Azure CLI login is stale or incomplete, so the hook cannot resolve your object ID and UPN for SQL Entra admin setup.

**Resolution**:
```bash
az login
azd up
```

### Private Endpoint Connectivity Issues

**Symptom**: Connection timeout or network errors

**Resolution**:
1. Verify VNet integration is enabled on the App Service
2. Check Private Endpoint is provisioned and approved
3. Verify DNS resolution in the VNet
4. Ensure `vnetRouteAllEnabled` is true in App Service config

## Security Features

- **Entra-only authentication**: SQL Server accepts only Azure AD authentication
- **No SQL passwords**: All authentication via managed identities/Azure AD
- **Private connectivity**: SQL Server accessible only via Private Endpoint
- **Minimal permissions**: App uses principle of least privilege (db_datareader)
- **VNet isolation**: All traffic routed through private network

## Infrastructure Components

- **VNet**: Virtual network with two subnets (app, private endpoint)
- **SQL Server**: Azure SQL with Entra admin and private access only
- **SQL Database**: Basic tier database
- **Private Endpoint**: Secure connection to SQL Server
- **App Service Plan**: Premium V3 (required for VNet integration)
- **App Service**: Node.js 20 with system-assigned managed identity

## Development

### Local Development

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Run locally (requires SQL connection environment variables)
npm start

# Development mode with auto-reload
npm run dev
```

### Environment Variables

- `SQL_SERVER`: SQL Server FQDN (set automatically by Bicep)
- `SQL_DATABASE`: Database name (set automatically by Bicep)
- `PORT`: Application port (default: 3000)

## Clean Up

To delete all Azure resources:

```bash
azd down
```

## License

MIT
