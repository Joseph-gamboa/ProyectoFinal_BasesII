/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   04_sp_roles_usuarios.sql
   Funcion auxiliar y procedimientos basicos de Roles, Usuarios y
   UsuarioRol (12 procedimientos + 1 funcion).
   Requiere: 01_crear_tablas.sql
   Codigos de error: 50001 duplicado, 50002 no existe,
   50003 valor invalido, 50004 tiene datos relacionados,
   50006 cambio no permitido
   ===================================================================== */
USE GravityFinance;
GO

/* Funcion auxiliar: ¿es el ultimo administrador activo? */
CREATE OR ALTER FUNCTION dbo.fn_EsUltimoAdministrador (@id_usuario INT)
RETURNS BIT
AS
BEGIN
    DECLARE @resultado BIT = 0;

    IF EXISTS (SELECT 1
               FROM dbo.UsuarioRol ur
               INNER JOIN dbo.Roles r    ON r.id_rol = ur.id_rol
               INNER JOIN dbo.Usuarios u ON u.id_usuario = ur.id_usuario
               WHERE ur.id_usuario = @id_usuario
                 AND r.nombre = 'Administrador' AND u.estado = 'ACTIVO')
       AND NOT EXISTS (SELECT 1
               FROM dbo.UsuarioRol ur
               INNER JOIN dbo.Roles r    ON r.id_rol = ur.id_rol
               INNER JOIN dbo.Usuarios u ON u.id_usuario = ur.id_usuario
               WHERE ur.id_usuario <> @id_usuario
                 AND r.nombre = 'Administrador' AND u.estado = 'ACTIVO')
        SET @resultado = 1;

    RETURN @resultado;
END;
GO

/* ===================== ROLES ===================== */
CREATE OR ALTER PROCEDURE dbo.usp_Roles_Insertar
    @nombre      VARCHAR(30),
    @descripcion NVARCHAR(150) = NULL,
    @id_rol      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF LEN(LTRIM(RTRIM(@nombre))) = 0
            THROW 50003, N'El nombre del rol no puede estar vacío.', 1;

        BEGIN TRANSACTION;
            IF EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = @nombre)
                THROW 50001, N'Ya existe un rol con ese nombre.', 1;

            INSERT INTO dbo.Roles (nombre, descripcion)
            VALUES (LTRIM(RTRIM(@nombre)), @descripcion);

            SET @id_rol = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Roles_Actualizar
    @id_rol      INT,
    @nombre      VARCHAR(30),
    @descripcion NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF LEN(LTRIM(RTRIM(@nombre))) = 0
            THROW 50003, N'El nombre del rol no puede estar vacío.', 1;

        BEGIN TRANSACTION;
            DECLARE @nombre_actual VARCHAR(30);
            SELECT @nombre_actual = nombre FROM dbo.Roles WHERE id_rol = @id_rol;

            IF @nombre_actual IS NULL
                THROW 50002, N'El rol no existe.', 1;

            IF @nombre_actual IN ('Administrador','Usuario') AND @nombre_actual <> @nombre
                THROW 50006, N'Los roles Administrador y Usuario no se pueden renombrar.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Roles WHERE nombre = @nombre AND id_rol <> @id_rol)
                THROW 50001, N'Ya existe otro rol con ese nombre.', 1;

            UPDATE dbo.Roles
            SET nombre = LTRIM(RTRIM(@nombre)),
                descripcion = @descripcion
            WHERE id_rol = @id_rol;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Roles_Eliminar
    @id_rol INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            DECLARE @nombre_actual VARCHAR(30);
            SELECT @nombre_actual = nombre FROM dbo.Roles WHERE id_rol = @id_rol;

            IF @nombre_actual IS NULL
                THROW 50002, N'El rol no existe.', 1;

            IF @nombre_actual IN ('Administrador','Usuario')
                THROW 50006, N'Los roles Administrador y Usuario no se pueden borrar.', 1;

            IF EXISTS (SELECT 1 FROM dbo.UsuarioRol WHERE id_rol = @id_rol)
                THROW 50004, N'No se puede borrar: hay usuarios con ese rol.', 1;

            DELETE FROM dbo.Roles WHERE id_rol = @id_rol;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Roles_Consultar
    @id_rol INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT r.id_rol, r.nombre, r.descripcion,
               (SELECT COUNT(*) FROM dbo.UsuarioRol ur WHERE ur.id_rol = r.id_rol) AS cantidad_usuarios
        FROM dbo.Roles r
        WHERE (@id_rol IS NULL OR r.id_rol = @id_rol)
        ORDER BY r.nombre;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ===================== USUARIOS =====================
   La contrasena llega YA protegida (la protege Laravel con Hash::make).
   La consulta nunca devuelve contrasena_hash. */
CREATE OR ALTER PROCEDURE dbo.usp_Usuarios_Insertar
    @nombre          NVARCHAR(60),
    @apellido        NVARCHAR(60) = NULL,
    @correo          NVARCHAR(120),
    @contrasena_hash NVARCHAR(255),
    @estado          VARCHAR(10) = 'ACTIVO',
    @id_usuario      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF LEN(LTRIM(RTRIM(@nombre))) = 0
            THROW 50003, N'El nombre no puede estar vacío.', 1;
        IF @correo NOT LIKE '%_@_%._%' OR @correo LIKE '% %'
            THROW 50003, N'El correo no tiene un formato válido.', 1;
        IF LEN(@contrasena_hash) < 8
            THROW 50003, N'La contraseña protegida no es válida.', 1;
        IF @estado NOT IN ('ACTIVO','INACTIVO')
            THROW 50003, N'El estado debe ser ACTIVO o INACTIVO.', 1;

        BEGIN TRANSACTION;
            IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE correo = @correo)
                THROW 50001, N'Ya existe un usuario con ese correo.', 1;

            INSERT INTO dbo.Usuarios (nombre, apellido, correo, contrasena_hash, estado)
            VALUES (LTRIM(RTRIM(@nombre)), @apellido, @correo, @contrasena_hash, @estado);

            SET @id_usuario = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuarios_Actualizar
    @id_usuario INT,
    @nombre     NVARCHAR(60),
    @apellido   NVARCHAR(60) = NULL,
    @correo     NVARCHAR(120),
    @estado     VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF LEN(LTRIM(RTRIM(@nombre))) = 0
            THROW 50003, N'El nombre no puede estar vacío.', 1;
        IF @correo NOT LIKE '%_@_%._%' OR @correo LIKE '% %'
            THROW 50003, N'El correo no tiene un formato válido.', 1;
        IF @estado NOT IN ('ACTIVO','INACTIVO')
            THROW 50003, N'El estado debe ser ACTIVO o INACTIVO.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario)
                THROW 50002, N'El usuario no existe.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE correo = @correo AND id_usuario <> @id_usuario)
                THROW 50001, N'Ya existe otro usuario con ese correo.', 1;

            IF @estado = 'INACTIVO' AND dbo.fn_EsUltimoAdministrador(@id_usuario) = 1
                THROW 50006, N'No se puede desactivar al último administrador activo.', 1;

            UPDATE dbo.Usuarios
            SET nombre   = LTRIM(RTRIM(@nombre)),
                apellido = @apellido,
                correo   = @correo,
                estado   = @estado
            WHERE id_usuario = @id_usuario;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuarios_Eliminar
    @id_usuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario)
                THROW 50002, N'El usuario no existe.', 1;

            IF dbo.fn_EsUltimoAdministrador(@id_usuario) = 1
                THROW 50006, N'No se puede borrar al último administrador activo.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Cuentas      WHERE id_usuario = @id_usuario)
            OR EXISTS (SELECT 1 FROM dbo.Presupuestos WHERE id_usuario = @id_usuario)
            OR EXISTS (SELECT 1 FROM dbo.MetasAhorro  WHERE id_usuario = @id_usuario)
                THROW 50004, N'No se puede borrar: el usuario tiene cuentas, presupuestos o metas. Desactívelo en su lugar.', 1;

            -- Los roles asignados son solo un enlace, se quitan junto con el usuario
            DELETE FROM dbo.UsuarioRol WHERE id_usuario = @id_usuario;
            DELETE FROM dbo.Usuarios   WHERE id_usuario = @id_usuario;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuarios_Consultar
    @id_usuario INT = NULL,
    @estado     VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT u.id_usuario, u.nombre, u.apellido, u.correo, u.estado, u.fecha_registro,
               (SELECT STRING_AGG(r.nombre, ', ')
                FROM dbo.UsuarioRol ur
                INNER JOIN dbo.Roles r ON r.id_rol = ur.id_rol
                WHERE ur.id_usuario = u.id_usuario) AS roles
        FROM dbo.Usuarios u
        WHERE (@id_usuario IS NULL OR u.id_usuario = @id_usuario)
          AND (@estado     IS NULL OR u.estado     = @estado)
        ORDER BY u.nombre, u.apellido;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ===================== USUARIOROL ===================== */
CREATE OR ALTER PROCEDURE dbo.usp_UsuarioRol_Insertar
    @id_usuario INT,
    @id_rol     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario)
                THROW 50002, N'El usuario no existe.', 1;
            IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE id_rol = @id_rol)
                THROW 50002, N'El rol no existe.', 1;
            IF EXISTS (SELECT 1 FROM dbo.UsuarioRol WHERE id_usuario = @id_usuario AND id_rol = @id_rol)
                THROW 50001, N'El usuario ya tiene ese rol.', 1;

            INSERT INTO dbo.UsuarioRol (id_usuario, id_rol) VALUES (@id_usuario, @id_rol);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UsuarioRol_Actualizar
    @id_usuario     INT,
    @id_rol_actual  INT,
    @id_rol_nuevo   INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.UsuarioRol
                           WHERE id_usuario = @id_usuario AND id_rol = @id_rol_actual)
                THROW 50002, N'El usuario no tiene el rol que se quiere cambiar.', 1;
            IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE id_rol = @id_rol_nuevo)
                THROW 50002, N'El rol nuevo no existe.', 1;
            IF EXISTS (SELECT 1 FROM dbo.UsuarioRol
                       WHERE id_usuario = @id_usuario AND id_rol = @id_rol_nuevo)
                THROW 50001, N'El usuario ya tiene el rol nuevo.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Roles WHERE id_rol = @id_rol_actual AND nombre = 'Administrador')
               AND dbo.fn_EsUltimoAdministrador(@id_usuario) = 1
                THROW 50006, N'No se le puede quitar el rol al último administrador activo.', 1;

            UPDATE dbo.UsuarioRol
            SET id_rol = @id_rol_nuevo
            WHERE id_usuario = @id_usuario AND id_rol = @id_rol_actual;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UsuarioRol_Eliminar
    @id_usuario INT,
    @id_rol     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.UsuarioRol
                           WHERE id_usuario = @id_usuario AND id_rol = @id_rol)
                THROW 50002, N'El usuario no tiene ese rol.', 1;

            IF (SELECT COUNT(*) FROM dbo.UsuarioRol WHERE id_usuario = @id_usuario) = 1
                THROW 50006, N'Un usuario no puede quedarse sin ningún rol.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Roles WHERE id_rol = @id_rol AND nombre = 'Administrador')
               AND dbo.fn_EsUltimoAdministrador(@id_usuario) = 1
                THROW 50006, N'No se le puede quitar el rol al último administrador activo.', 1;

            DELETE FROM dbo.UsuarioRol WHERE id_usuario = @id_usuario AND id_rol = @id_rol;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UsuarioRol_Consultar
    @id_usuario INT = NULL,
    @id_rol     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT ur.id_usuario, u.nombre, u.apellido, u.correo,
               ur.id_rol, r.nombre AS nombre_rol
        FROM dbo.UsuarioRol ur
        INNER JOIN dbo.Usuarios u ON u.id_usuario = ur.id_usuario
        INNER JOIN dbo.Roles r    ON r.id_rol     = ur.id_rol
        WHERE (@id_usuario IS NULL OR ur.id_usuario = @id_usuario)
          AND (@id_rol     IS NULL OR ur.id_rol     = @id_rol)
        ORDER BY u.nombre, r.nombre;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
