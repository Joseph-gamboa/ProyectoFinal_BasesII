USE GravityFinance;
GO

IF COL_LENGTH(N'dbo.Usuarios', N'foto_perfil') IS NULL
BEGIN
    ALTER TABLE dbo.Usuarios
        ADD foto_perfil NVARCHAR(255) NULL;
END;
GO

GRANT UPDATE ON OBJECT::dbo.Usuarios (foto_perfil)
TO rol_autenticacion;
GO