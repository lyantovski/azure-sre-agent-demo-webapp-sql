import './telemetry';
import express, { Request, Response } from 'express';
import sql from 'mssql';
import { DefaultAzureCredential } from '@azure/identity';

const app = express();
const port = process.env.PORT || 3000;

// SQL Configuration from environment variables
const sqlServer = process.env.SQL_SERVER || '';
const sqlDatabase = process.env.SQL_DATABASE || '';

// Error messages and hints
const SQL_LOGIN_FAILURE_HINT = 'The managed identity may not have a database user created. To fix, connect to the database as Entra admin and run: CREATE USER [YOUR_WEBAPP_NAME] FROM EXTERNAL PROVIDER; ALTER ROLE db_datareader ADD MEMBER [YOUR_WEBAPP_NAME];';
const DOCUMENTATION_LINK = 'See README.md for detailed troubleshooting steps.';

// Health check endpoint for SQL connectivity
app.get('/health/sql', async (req: Request, res: Response) => {
  const diagnostics: any = {
    timestamp: new Date().toISOString(),
    endpoint: '/health/sql',
    sqlServer: sqlServer,
    sqlDatabase: sqlDatabase,
    checks: {}
  };

  try {
    // Check 1: Validate environment variables
    if (!sqlServer || !sqlDatabase) {
      diagnostics.status = 'unhealthy';
      diagnostics.checks.environment = {
        status: 'failed',
        message: 'Missing required environment variables',
        details: {
          sqlServerSet: !!sqlServer,
          sqlDatabaseSet: !!sqlDatabase
        }
      };
      res.status(503).json(diagnostics);
      return;
    }
    diagnostics.checks.environment = { status: 'passed' };

    // Check 2: Acquire Azure AD token for SQL Database
    const credential = new DefaultAzureCredential();
    let tokenResponse;
    try {
      tokenResponse = await credential.getToken('https://database.windows.net/.default');
    } catch (tokenError: any) {
      diagnostics.status = 'unhealthy';
      diagnostics.checks.authentication = {
        status: 'failed',
        message: 'Failed to acquire Azure AD access token',
        error: tokenError.message,
        hint: 'Ensure the App Service has a System-Assigned Managed Identity'
      };
      res.status(503).json(diagnostics);
      return;
    }

    if (!tokenResponse || !tokenResponse.token) {
      diagnostics.status = 'unhealthy';
      diagnostics.checks.authentication = {
        status: 'failed',
        message: 'Access token is empty or invalid'
      };
      res.status(503).json(diagnostics);
      return;
    }
    diagnostics.checks.authentication = { status: 'passed' };

    // Check 3: Configure SQL connection with managed identity authentication
    const config: sql.config = {
      server: sqlServer,
      database: sqlDatabase,
      authentication: {
        type: 'azure-active-directory-access-token',
        options: {
          token: tokenResponse.token
        }
      },
      options: {
        encrypt: true,
        trustServerCertificate: false,
        connectTimeout: 15000,
        requestTimeout: 15000
      }
    };

    // Check 4: Attempt to connect to SQL Database
    let pool;
    try {
      pool = await sql.connect(config);
      diagnostics.checks.connectivity = { status: 'passed' };
    } catch (connectError: any) {
      diagnostics.status = 'unhealthy';
      diagnostics.checks.connectivity = {
        status: 'failed',
        message: 'Failed to connect to SQL Server',
        error: connectError.message,
        code: connectError.code
      };

      // Provide hints based on error type
      if (connectError.message.includes('Login failed')) {
        diagnostics.checks.connectivity.hint = SQL_LOGIN_FAILURE_HINT;
        diagnostics.checks.connectivity.documentation = DOCUMENTATION_LINK;
      } else if (connectError.message.includes('Timeout') || connectError.message.includes('ESOCKET')) {
        diagnostics.checks.connectivity.hint = 'Network connectivity issue. Check if Private Endpoint is properly configured and accessible from App Service VNet.';
      } else if (connectError.message.includes('Cannot open server')) {
        diagnostics.checks.connectivity.hint = 'Server not found. Verify SQL Server FQDN is correct and resolvable.';
      }

      res.status(503).json(diagnostics);
      return;
    }

    // Check 5: Execute test query
    try {
      const result = await pool.request().query('SELECT 1 AS TestConnection');
      diagnostics.checks.query = { status: 'passed' };
    } catch (queryError: any) {
      diagnostics.status = 'unhealthy';
      diagnostics.checks.query = {
        status: 'failed',
        message: 'Failed to execute test query',
        error: queryError.message
      };
      await pool.close();
      res.status(503).json(diagnostics);
      return;
    }

    // Close connection
    await pool.close();
    diagnostics.checks.cleanup = { status: 'passed' };

    // All checks passed
    diagnostics.status = 'healthy';
    res.json({
      status: 'healthy',
      message: 'Successfully connected to Azure SQL Database',
      server: sqlServer,
      database: sqlDatabase,
      timestamp: new Date().toISOString()
    });

  } catch (error: any) {
    // Catch-all for unexpected errors
    diagnostics.status = 'unhealthy';
    diagnostics.unexpectedError = {
      message: error.message || 'Unknown error',
      type: error.name || 'Error',
      stack: error.stack
    };
    res.status(503).json(diagnostics);
  }
});

// Root health endpoint
app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'sre-agent-demo',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint
app.get('/', (req: Request, res: Response) => {
  res.json({
    message: 'Azure SRE Agent Demo',
    endpoints: {
      health: '/health',
      sqlHealth: '/health/sql'
    }
  });
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
  console.log(`SQL Server: ${sqlServer}`);
  console.log(`SQL Database: ${sqlDatabase}`);
});
