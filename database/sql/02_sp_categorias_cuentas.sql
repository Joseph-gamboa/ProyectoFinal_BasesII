/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   02_sp_categorias_cuentas.sql
   Procedimientos basicos de Categorias y Cuentas (8 procedimientos).
   Requiere: 01_crear_tablas.sql
   Codigos de error propios: 50001 duplicado, 50002 no existe,
   50003 valor invalido, 50004 tiene datos relacionados,
   50005 usuario invalido, 50006 cambio no permitido
   ===================================================================== */
USE GravityFinance;
GO

/* ===================== CATEGORIAS ===================== */
CREATE OR ALTER PROCEDURE dbo.usp_Categorias_Insertar
    @nombre_categoria NVARCHAR(50),
    @tipo_categoria   VARCHAR(7),
    @id_categoria     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @tipo_categoria NOT IN ('INGRESO','GASTO')
            THROW 50003, N'El tipo de categoría debe ser INGRESO o GASTO.', 1;

        BEGIN TRANSACTION;
            IF EXISTS (SELECT 1 FROM dbo.Categorias WHERE nombre_categoria = @nombre_categoria)
                THROW 50001, N'Ya existe una categoría con ese nombre.', 1;

            INSERT INTO dbo.Categorias (nombre_categoria, tipo_categoria)
            VALUES (@nombre_categoria, @tipo_categoria);

            SET @id_categoria = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Categorias_Actualizar
    @id_categoria     INT,
    @nombre_categoria NVARCHAR(50),
    @tipo_categoria   VARCHAR(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @tipo_categoria NOT IN ('INGRESO','GASTO')
            THROW 50003, N'El tipo de categoría debe ser INGRESO o GASTO.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE id_categoria = @id_categoria)
                THROW 50002, N'La categoría no existe.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Categorias
                       WHERE nombre_categoria = @nombre_categoria AND id_categoria <> @id_categoria)
                THROW 50001, N'Ya existe otra categoría con ese nombre.', 1;

            -- No se puede cambiar de INGRESO a GASTO (o al revés) si ya tiene movimientos
            IF EXISTS (SELECT 1 FROM dbo.Categorias
                       WHERE id_categoria = @id_categoria AND tipo_categoria <> @tipo_categoria)
               AND EXISTS (SELECT 1 FROM dbo.Movimientos WHERE id_categoria = @id_categoria)
                THROW 50006, N'No se puede cambiar el tipo: la categoría ya tiene movimientos.', 1;

            UPDATE dbo.Categorias
            SET nombre_categoria = @nombre_categoria,
                tipo_categoria   = @tipo_categoria
            WHERE id_categoria = @id_categoria;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Categorias_Eliminar
    @id_categoria INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE id_categoria = @id_categoria)
                THROW 50002, N'La categoría no existe.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Movimientos   WHERE id_categoria = @id_categoria)
            OR EXISTS (SELECT 1 FROM dbo.Presupuestos  WHERE id_categoria = @id_categoria)
                THROW 50004, N'No se puede borrar: la categoría tiene movimientos o presupuestos.', 1;

            DELETE FROM dbo.Categorias WHERE id_categoria = @id_categoria;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Categorias_Consultar
    @id_categoria   INT = NULL,
    @tipo_categoria VARCHAR(7) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT id_categoria, nombre_categoria, tipo_categoria
        FROM dbo.Categorias
        WHERE (@id_categoria   IS NULL OR id_categoria   = @id_categoria)
          AND (@tipo_categoria IS NULL OR tipo_categoria = @tipo_categoria)
        ORDER BY tipo_categoria, nombre_categoria;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* =====================================================
   CUENTAS: el saldo NO se edita aqui; solo cambia con
   movimientos, transferencias y aportes a metas
   ===================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_Cuentas_Insertar
    @id_usuario    INT,
    @nombre_cuenta NVARCHAR(60),
    @tipo_cuenta   VARCHAR(10),
    @moneda        CHAR(3) = 'CRC',
    @saldo_inicial DECIMAL(14,2) = 0,
    @id_cuenta     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @tipo_cuenta NOT IN ('EFECTIVO','BANCO','TARJETA')
            THROW 50003, N'El tipo de cuenta debe ser EFECTIVO, BANCO o TARJETA.', 1;
        IF @moneda NOT IN ('CRC','USD')
            THROW 50003, N'La moneda debe ser CRC o USD.', 1;
        IF @saldo_inicial < 0
            THROW 50003, N'El saldo inicial no puede ser negativo.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario AND estado = 'ACTIVO')
                THROW 50005, N'El usuario no existe o no está activo.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Cuentas
                       WHERE id_usuario = @id_usuario AND nombre_cuenta = @nombre_cuenta)
                THROW 50001, N'El usuario ya tiene una cuenta con ese nombre.', 1;

            INSERT INTO dbo.Cuentas (id_usuario, nombre_cuenta, tipo_cuenta, moneda, saldo)
            VALUES (@id_usuario, @nombre_cuenta, @tipo_cuenta, @moneda, @saldo_inicial);

            SET @id_cuenta = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Cuentas_Actualizar
    @id_cuenta     INT,
    @nombre_cuenta NVARCHAR(60),
    @tipo_cuenta   VARCHAR(10),
    @moneda        CHAR(3),
    @estado        VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @tipo_cuenta NOT IN ('EFECTIVO','BANCO','TARJETA')
            THROW 50003, N'El tipo de cuenta debe ser EFECTIVO, BANCO o TARJETA.', 1;
        IF @moneda NOT IN ('CRC','USD')
            THROW 50003, N'La moneda debe ser CRC o USD.', 1;
        IF @estado NOT IN ('ACTIVA','CERRADA')
            THROW 50003, N'El estado debe ser ACTIVA o CERRADA.', 1;

        BEGIN TRANSACTION;
            DECLARE @id_usuario INT;
            SELECT @id_usuario = id_usuario FROM dbo.Cuentas WHERE id_cuenta = @id_cuenta;

            IF @id_usuario IS NULL
                THROW 50002, N'La cuenta no existe.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Cuentas
                       WHERE id_usuario = @id_usuario
                         AND nombre_cuenta = @nombre_cuenta
                         AND id_cuenta <> @id_cuenta)
                THROW 50001, N'El usuario ya tiene otra cuenta con ese nombre.', 1;

            -- No se cambia la moneda si la cuenta ya tiene movimientos
            IF EXISTS (SELECT 1 FROM dbo.Cuentas WHERE id_cuenta = @id_cuenta AND moneda <> @moneda)
               AND EXISTS (SELECT 1 FROM dbo.Movimientos WHERE id_cuenta = @id_cuenta)
                THROW 50006, N'No se puede cambiar la moneda: la cuenta ya tiene movimientos.', 1;

            UPDATE dbo.Cuentas
            SET nombre_cuenta = @nombre_cuenta,
                tipo_cuenta   = @tipo_cuenta,
                moneda        = @moneda,
                estado        = @estado
            WHERE id_cuenta = @id_cuenta;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Cuentas_Eliminar
    @id_cuenta INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Cuentas WHERE id_cuenta = @id_cuenta)
                THROW 50002, N'La cuenta no existe.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Movimientos    WHERE id_cuenta = @id_cuenta)
            OR EXISTS (SELECT 1 FROM dbo.Transferencias WHERE id_cuenta_origen = @id_cuenta
                                                           OR id_cuenta_destino = @id_cuenta)
            OR EXISTS (SELECT 1 FROM dbo.AportesMeta    WHERE id_cuenta = @id_cuenta)
                THROW 50004, N'No se puede borrar: la cuenta tiene movimientos, transferencias o aportes. Ciérrela en su lugar.', 1;

            DELETE FROM dbo.Cuentas WHERE id_cuenta = @id_cuenta;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Cuentas_Consultar
    @id_usuario INT,
    @id_cuenta  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT id_cuenta, id_usuario, nombre_cuenta, tipo_cuenta, moneda, saldo, estado
        FROM dbo.Cuentas
        WHERE id_usuario = @id_usuario
          AND (@id_cuenta IS NULL OR id_cuenta = @id_cuenta)
        ORDER BY nombre_cuenta;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
