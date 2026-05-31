#!/usr/bin/env bash
set -e

echo "=========================================="
echo "Post-Provision: Creating SQL Database User"
echo "=========================================="

# Get the required values from azd environment
RESOURCE_GROUP=$(azd env get-value AZURE_RESOURCE_GROUP)
SQL_SERVER=$(azd env get-value sqlServerName)
SQL_DATABASE=$(azd env get-value sqlDatabaseName)
WEBAPP_NAME=$(azd env get-value webAppName)

if [ -z "$RESOURCE_GROUP" ] || [ -z "$SQL_SERVER" ] || [ -z "$SQL_DATABASE" ] || [ -z "$WEBAPP_NAME" ]; then
  echo "Error: Required environment variables are not set."
  echo "RESOURCE_GROUP: $RESOURCE_GROUP"
  echo "SQL_SERVER: $SQL_SERVER"
  echo "SQL_DATABASE: $SQL_DATABASE"
  echo "WEBAPP_NAME: $WEBAPP_NAME"
  exit 1
fi

echo "Resource Group: $RESOURCE_GROUP"
echo "SQL Server: $SQL_SERVER"
echo "SQL Database: $SQL_DATABASE"
echo "Web App Name: $WEBAPP_NAME"
echo ""

# Validate webapp name contains only safe characters (alphanumeric, hyphens)
# Azure resource names follow specific patterns and shouldn't contain SQL special chars
if ! [[ "$WEBAPP_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
  echo "Error: Web app name contains invalid characters. Only alphanumeric and hyphens are allowed."
  echo "Web App Name: $WEBAPP_NAME"
  exit 1
fi

echo "Creating SQL database user for managed identity..."
echo ""

# Add a temporary firewall rule for the current client IP
CLIENT_IP=$(curl -s https://api.ipify.org)
echo "Adding temporary firewall rule for client IP: $CLIENT_IP"
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER" \
  --name "PostProvisionTemp" \
  --start-ip-address "$CLIENT_IP" \
  --end-ip-address "$CLIENT_IP" \
  --output none 2>/dev/null || true

# Read SQL script template and replace placeholder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use a safer approach: read the file and use parameter expansion instead of sed
# Since we've validated WEBAPP_NAME contains only [a-zA-Z0-9-], this is safe
SQL_SCRIPT=$(cat "$SCRIPT_DIR/create-db-user.sql")
SQL_SCRIPT="${SQL_SCRIPT//\{\{WEBAPP_NAME\}\}/$WEBAPP_NAME}"

cleanup() {
  echo "Removing temporary firewall rule..."
  az sql server firewall-rule delete \
    --resource-group "$RESOURCE_GROUP" \
    --server "$SQL_SERVER" \
    --name "PostProvisionTemp" \
    --output none 2>/dev/null || true
}
trap cleanup EXIT

if sqlcmd \
  -S "$SQL_SERVER.database.windows.net" \
  -d "$SQL_DATABASE" \
  -G \
  --authentication-method=ActiveDirectoryDefault \
  -Q "$SQL_SCRIPT"; then
  echo ""
  echo "=========================================="
  echo "SQL Database User created successfully!"
  echo "=========================================="
else
  echo ""
  echo "=========================================="
  echo "ERROR: Failed to create SQL database user"
  echo "=========================================="
  echo "This could be due to:"
  echo "  1. Insufficient permissions (you must be a SQL Entra admin)"
  echo "  2. Network connectivity issues"
  echo "  3. The database or server does not exist yet"
  echo ""
  echo "You can manually create the database user later by rerunning:"
  echo "  ./scripts/postprovision.sh"
  echo ""
  exit 1
fi
