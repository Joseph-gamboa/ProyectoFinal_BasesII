USE GravityFinance;
GO

-- Crear el rol y el usuario de prueba
IF DATABASE_PRINCIPAL_ID(N'rol_reportes') IS NULL
    CREATE ROLE rol_reportes AUTHORIZATION dbo;

IF DATABASE_PRINCIPAL_ID(N'prueba_reportes') IS NULL
    CREATE USER prueba_reportes WITHOUT LOGIN;

ALTER ROLE rol_reportes ADD MEMBER prueba_reportes;

-- Permitir ejecutar el reporte
GRANT EXECUTE
ON OBJECT::dbo.usp_Reporte_ResumenFinanciero
TO rol_reportes;
GO

-- Probar los permisos del usuario
EXECUTE AS USER = N'prueba_reportes';

BEGIN TRY
    SELECT USER_NAME() AS usuario_actual;

    SELECT
        HAS_PERMS_BY_NAME(
            N'dbo.usp_Reporte_ResumenFinanciero',
            N'OBJECT', N'EXECUTE'
        ) AS puede_ejecutar_reporte,
        HAS_PERMS_BY_NAME(
            N'dbo.Cuentas',
            N'OBJECT', N'DELETE'
        ) AS puede_borrar_cuentas,
        HAS_PERMS_BY_NAME(
            N'dbo.Usuarios',
            N'OBJECT', N'SELECT'
        ) AS puede_leer_tabla_usuarios;

    EXEC dbo.usp_Reporte_ResumenFinanciero
        @id_usuario = 1,
        @mes = 11,
        @anio = 2026;
END TRY
BEGIN CATCH
    REVERT;
    THROW;
END CATCH;

REVERT;

SELECT USER_NAME() AS usuario_al_final;