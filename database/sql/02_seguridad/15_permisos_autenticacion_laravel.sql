USE GravityFinance;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_autenticacion') IS NULL
    CREATE ROLE rol_autenticacion AUTHORIZATION dbo;
GO

GRANT SELECT ON OBJECT::dbo.Usuarios TO rol_autenticacion;
GRANT SELECT ON OBJECT::dbo.Roles TO rol_autenticacion;
GRANT SELECT ON OBJECT::dbo.UsuarioRol TO rol_autenticacion;

GRANT INSERT ON OBJECT::dbo.Usuarios TO rol_autenticacion;
GRANT INSERT ON OBJECT::dbo.UsuarioRol TO rol_autenticacion;

ALTER ROLE rol_autenticacion ADD MEMBER laravel_app;
GO