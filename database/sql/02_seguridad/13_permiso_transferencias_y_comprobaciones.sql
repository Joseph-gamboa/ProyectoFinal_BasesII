USE GravityFinance;
GO

GRANT EXECUTE
ON OBJECT::dbo.usp_Transferencias_Registrar
TO rol_operaciones;

-- Comprobar el permiso del perfil de operaciones
EXECUTE AS USER = N'prueba_operaciones';

SELECT HAS_PERMS_BY_NAME(
    N'dbo.usp_Transferencias_Registrar',
    N'OBJECT',
    N'EXECUTE'
) AS puede_registrar_transferencias;

REVERT;

-- Revisar si el inicio de sesión ya existe en el servidor
SELECT name AS inicio_sesion,
       is_disabled AS deshabilitado
FROM sys.sql_logins
WHERE name = N'laravel_app';

-- Comprobar el modo de autenticación del servidor
SELECT CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
    WHEN 0 THEN N'Mixto: Windows y SQL Server'
    WHEN 1 THEN N'Solo Windows'
END AS modo_autenticacion;