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
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'{{WEBAPP_NAME}}')
BEGIN
    PRINT 'ERROR: User [{{WEBAPP_NAME}}] does not exist. Cannot grant permissions.';
END
ELSE IF IS_ROLEMEMBER(N'db_datareader', N'{{WEBAPP_NAME}}') = 1
BEGIN
    PRINT 'User [{{WEBAPP_NAME}}] is already a member of db_datareader.';
END
ELSE
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [{{WEBAPP_NAME}}];
    PRINT 'User [{{WEBAPP_NAME}}] added to db_datareader role.';
END
