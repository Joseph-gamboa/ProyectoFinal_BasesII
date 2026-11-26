USE GravityFinance;
GO

-- Crear el perfil administrativo y su usuario de prueba
IF DATABASE_PRINCIPAL_ID(N'rol_administracion') IS NULL
    CREATE ROLE rol_administracion AUTHORIZATION dbo;

IF DATABASE_PRINCIPAL_ID(N'prueba_administracion') IS NULL
    CREATE USER prueba_administracion WITHOUT LOGIN;

ALTER ROLE rol_administracion ADD MEMBER prueba_administracion;

-- Heredar los permisos de operaciones
ALTER ROLE rol_operaciones ADD MEMBER rol_administracion;

-- Categorías
GRANT EXECUTE ON OBJECT::dbo.usp_Categorias_Insertar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_Categorias_Consultar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_Categorias_Actualizar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_Categorias_Eliminar TO rol_administracion;

-- Usuarios
GRANT EXECUTE ON OBJECT::dbo.usp_Usuarios_Insertar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_Usuarios_Consultar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_Usuarios_Actualizar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_Usuarios_Eliminar TO rol_administracion;

-- Roles
GRANT EXECUTE ON OBJECT::dbo.usp_Roles_Insertar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_Roles_Consultar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_Roles_Actualizar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_Roles_Eliminar TO rol_administracion;

-- Asignaciones de roles
GRANT EXECUTE ON OBJECT::dbo.usp_UsuarioRol_Insertar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_UsuarioRol_Consultar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_UsuarioRol_Actualizar TO rol_administracion;
GRANT EXECUTE ON OBJECT::dbo.usp_UsuarioRol_Eliminar TO rol_administracion;
GO

-- Comprobar permisos
EXECUTE AS USER = N'prueba_administracion';

BEGIN TRY
    SELECT
        USER_NAME() AS usuario_actual,
        HAS_PERMS_BY_NAME(
            N'dbo.usp_UsuarioRol_Actualizar', N'OBJECT', N'EXECUTE'
        ) AS puede_cambiar_roles,
        HAS_PERMS_BY_NAME(
            N'dbo.usp_Cuentas_Insertar', N'OBJECT', N'EXECUTE'
        ) AS puede_crear_cuentas,
        HAS_PERMS_BY_NAME(
            N'dbo.Usuarios', N'OBJECT', N'DELETE'
        ) AS puede_borrar_directamente;

    EXEC dbo.usp_UsuarioRol_Consultar
        @id_usuario = 1,
        @id_rol = NULL;
END TRY
BEGIN CATCH
    REVERT;
    THROW;
END CATCH;

REVERT;

SELECT USER_NAME() AS usuario_al_final;