USE master;
GO

CREATE LOGIN laravel_app
WITH PASSWORD = 'REEMPLAZAR_POR_TU_CLAVE',
     CHECK_POLICY = ON,
     DEFAULT_DATABASE = GravityFinance;
GO

USE GravityFinance;
GO

CREATE USER laravel_app FOR LOGIN laravel_app;
GO

ALTER ROLE rol_operaciones ADD MEMBER laravel_app;
GO

-- Comprobar la asignación
SELECT
    r.name AS rol,
    u.name AS usuario
FROM sys.database_role_members AS rm
INNER JOIN sys.database_principals AS r
    ON r.principal_id = rm.role_principal_id
INNER JOIN sys.database_principals AS u
    ON u.principal_id = rm.member_principal_id
WHERE u.name = N'laravel_app';