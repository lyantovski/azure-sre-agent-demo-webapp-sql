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
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = N'{{WEBAPP_NAME}}')
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sys.database_role_members drm
        INNER JOIN sys.database_principals role_principal ON drm.role_principal_id = role_principal.principal_id
        INNER JOIN sys.database_principals member_principal ON drm.member_principal_id = member_principal.principal_id
        WHERE role_principal.name = N'db_datareader'
          AND member_principal.name = N'{{WEBAPP_NAME}}'
    )
    BEGIN
        ALTER ROLE db_datareader ADD MEMBER [{{WEBAPP_NAME}}];
        PRINT 'User [{{WEBAPP_NAME}}] added to db_datareader role.';
    END
    ELSE
    BEGIN
        PRINT 'User [{{WEBAPP_NAME}}] is already a member of db_datareader.';
    END
END
ELSE
BEGIN
    PRINT 'ERROR: User [{{WEBAPP_NAME}}] does not exist. Cannot grant permissions.';
END
