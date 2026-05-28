-- Create contained database user for the managed identity
-- This script is parameterized with {{WEBAPP_NAME}} placeholder
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'{{WEBAPP_NAME}}')
BEGIN
    CREATE USER [{{WEBAPP_NAME}}] FROM EXTERNAL PROVIDER;
    PRINT 'User [{{WEBAPP_NAME}}] created successfully.';
END
ELSE
BEGIN
    PRINT 'User [{{WEBAPP_NAME}}] already exists.';
END

-- Grant minimal permissions for health check (db_datareader allows SELECT)
-- This will succeed whether the user was just created or already existed
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = N'{{WEBAPP_NAME}}')
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [{{WEBAPP_NAME}}];
    PRINT 'User [{{WEBAPP_NAME}}] added to db_datareader role.';
END
ELSE
BEGIN
    PRINT 'ERROR: User [{{WEBAPP_NAME}}] does not exist. Cannot grant permissions.';
END
