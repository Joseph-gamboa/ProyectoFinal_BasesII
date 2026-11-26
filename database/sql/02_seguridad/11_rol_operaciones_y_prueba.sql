USE GravityFinance;
GO

-- Crear el rol y su usuario de demostración
IF DATABASE_PRINCIPAL_ID(N'rol_operaciones') IS NULL
    CREATE ROLE rol_operaciones AUTHORIZATION dbo;

IF DATABASE_PRINCIPAL_ID(N'prueba_operaciones') IS NULL
    CREATE USER prueba_operaciones WITHOUT LOGIN;

ALTER ROLE rol_operaciones ADD MEMBER prueba_operaciones;

-- Cuentas
GRANT EXECUTE ON OBJECT::dbo.usp_Cuentas_Insertar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_Cuentas_Consultar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_Cuentas_Actualizar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_Cuentas_Eliminar TO rol_operaciones;

-- Presupuestos
GRANT EXECUTE ON OBJECT::dbo.usp_Presupuestos_Insertar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_Presupuestos_Consultar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_Presupuestos_Actualizar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_Presupuestos_Eliminar TO rol_operaciones;

-- Metas de ahorro
GRANT EXECUTE ON OBJECT::dbo.usp_MetasAhorro_Insertar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_MetasAhorro_Consultar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_MetasAhorro_Actualizar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_MetasAhorro_Eliminar TO rol_operaciones;

-- Movimientos, aportes y reporte
GRANT EXECUTE ON OBJECT::dbo.usp_Movimientos_Registrar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_MetasAhorro_Aportar TO rol_operaciones;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_ResumenFinanciero TO rol_operaciones;
GO

-- Comprobar los permisos efectivos
EXECUTE AS USER = N'prueba_operaciones';

BEGIN TRY
    SELECT
        USER_NAME() AS usuario_actual,
        HAS_PERMS_BY_NAME(
            N'dbo.usp_Cuentas_Insertar', N'OBJECT', N'EXECUTE'
        ) AS puede_crear_cuentas,
        HAS_PERMS_BY_NAME(
            N'dbo.usp_Movimientos_Registrar', N'OBJECT', N'EXECUTE'
        ) AS puede_registrar_movimientos,
        HAS_PERMS_BY_NAME(
            N'dbo.usp_UsuarioRol_Actualizar', N'OBJECT', N'EXECUTE'
        ) AS puede_cambiar_roles,
        HAS_PERMS_BY_NAME(
            N'dbo.Cuentas', N'OBJECT', N'DELETE'
        ) AS puede_borrar_directamente;

    -- Probar una consulta mediante el procedimiento
    EXEC dbo.usp_Cuentas_Consultar
        @id_usuario = 1,
        @id_cuenta = NULL;
END TRY
BEGIN CATCH
    REVERT;
    THROW;
END CATCH;

REVERT;

SELECT USER_NAME() AS usuario_al_final;