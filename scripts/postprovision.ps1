Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "Post-Provision: Creating SQL Database User"
Write-Host "=========================================="

# Get the required values from azd environment
$RESOURCE_GROUP = azd env get-value AZURE_RESOURCE_GROUP
$SQL_SERVER = azd env get-value sqlServerName
$SQL_DATABASE = azd env get-value sqlDatabaseName
$WEBAPP_NAME = azd env get-value webAppName

if ([string]::IsNullOrEmpty($RESOURCE_GROUP) -or 
    [string]::IsNullOrEmpty($SQL_SERVER) -or 
    [string]::IsNullOrEmpty($SQL_DATABASE) -or 
    [string]::IsNullOrEmpty($WEBAPP_NAME)) {
    Write-Host "Error: Required environment variables are not set."
    Write-Host "RESOURCE_GROUP: $RESOURCE_GROUP"
    Write-Host "SQL_SERVER: $SQL_SERVER"
    Write-Host "SQL_DATABASE: $SQL_DATABASE"
    Write-Host "WEBAPP_NAME: $WEBAPP_NAME"
    exit 1
}

Write-Host "Resource Group: $RESOURCE_GROUP"
Write-Host "SQL Server: $SQL_SERVER"
Write-Host "SQL Database: $SQL_DATABASE"
Write-Host "Web App Name: $WEBAPP_NAME"
Write-Host ""

# Validate webapp name contains only safe characters (alphanumeric, hyphens)
# Azure resource names follow specific patterns and shouldn't contain SQL special chars
if ($WEBAPP_NAME -notmatch '^[a-zA-Z0-9-]+$') {
    Write-Host "Error: Web app name contains invalid characters. Only alphanumeric and hyphens are allowed."
    Write-Host "Web App Name: $WEBAPP_NAME"
    exit 1
}

Write-Host "Creating SQL database user for managed identity..."
Write-Host ""

# Add a temporary firewall rule for the current client IP
$CLIENT_IP = (Invoke-RestMethod -Uri "https://api.ipify.org")
Write-Host "Adding temporary firewall rule for client IP: $CLIENT_IP"
az sql server firewall-rule create `
  --resource-group $RESOURCE_GROUP `
  --server $SQL_SERVER `
  --name "PostProvisionTemp" `
  --start-ip-address $CLIENT_IP `
  --end-ip-address $CLIENT_IP `
  --output none 2>$null

# Ensure SqlServer module is available for Invoke-Sqlcmd
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "Installing SqlServer PowerShell module..."
    Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
}
Import-Module SqlServer

# Read SQL script template and replace placeholder
$SCRIPT_DIR = Split-Path -Parent $PSCommandPath
# Use Replace() method instead of -replace operator for literal string replacement
# Since we've validated WEBAPP_NAME contains only [a-zA-Z0-9-], this is safe
$SQL_SCRIPT = (Get-Content "$SCRIPT_DIR/create-db-user.sql" -Raw).Replace('{{WEBAPP_NAME}}', $WEBAPP_NAME)

# Get an Azure AD access token for Azure SQL
$ACCESS_TOKEN = (az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv)

# INTENTIONAL FAILURE SCENARIO FOR SRE AGENT TESTING
# Database user creation is DISABLED - the app will fail with login errors
Write-Host ""
Write-Host "=========================================="
Write-Host "[SRE-TEST] Database user creation SKIPPED"
Write-Host "=========================================="
Write-Host "This simulates a missing database user scenario."
Write-Host "When the app tries to connect, it will fail with:"
Write-Host "  'Login failed for user [webapp-identity]'"
Write-Host "=========================================="
Write-Host ""

# Database user creation is commented out below for testing:
<# Disabled for SRE testing:
try {
    Invoke-Sqlcmd `
      -ServerInstance "$SQL_SERVER.database.windows.net" `
      -Database $SQL_DATABASE `
      -AccessToken $ACCESS_TOKEN `
      -Query $SQL_SCRIPT

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "SQL Database User created successfully!"
    Write-Host "=========================================="

    # Clean up temporary firewall rule
    Write-Host "Removing temporary firewall rule..."
    az sql server firewall-rule delete `
      --resource-group $RESOURCE_GROUP `
      --server $SQL_SERVER `
      --name "PostProvisionTemp" `
      --output none 2>$null
} catch {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "ERROR: Failed to create SQL database user"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Error: $_"
    Write-Host ""
    Write-Host "This could be due to:"
    Write-Host "  1. Insufficient permissions (you must be a SQL Entra admin)"
    Write-Host "  2. Network connectivity issues"
    Write-Host "  3. The database or server does not exist yet"
    Write-Host ""
    Write-Host "You can manually create the database user later by running:"
    Write-Host "  .\scripts\postprovision.ps1"
    Write-Host ""
    exit 1
}
  #>
