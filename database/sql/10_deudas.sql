/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   10_deudas.sql
   Modulo de Deudas: 2 tablas, 5 procedimientos y 1 trigger.
   Requiere: 01_crear_tablas.sql. EJECUTAR DESPUES DE 09_triggers.sql.
   Codigos de error: 50001 duplicado, 50002 no existe, 50003 valor invalido,
   50004 tiene datos relacionados, 50005 usuario invalido,
   50006 cambio no permitido, 50007 saldo insuficiente,
   50008 cuenta o deuda ajena, 50009 fallo al actualizar
   ===================================================================== */
USE GravityFinance;
GO

/* ===== TABLAS ===== */
IF OBJECT_ID('dbo.Deudas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Deudas (
        id_deuda          INT IDENTITY(1,1) NOT NULL,
        id_usuario        INT NOT NULL,
        nombre_deuda      NVARCHAR(80) NOT NULL,
        acreedor          NVARCHAR(80) NOT NULL,
        monto_total       DECIMAL(14,2) NOT NULL,
        saldo_pendiente   DECIMAL(14,2) NOT NULL,
        fecha_vencimiento DATE NULL,
        estado            VARCHAR(10) NOT NULL CONSTRAINT DF_Deudas_estado DEFAULT 'VIGENTE',
        CONSTRAINT PK_Deudas PRIMARY KEY (id_deuda),
        CONSTRAINT FK_Deudas_Usuarios FOREIGN KEY (id_usuario) REFERENCES dbo.Usuarios (id_usuario),
        CONSTRAINT CK_Deudas_total  CHECK (monto_total > 0),
        CONSTRAINT CK_Deudas_saldo  CHECK (saldo_pendiente >= 0 AND saldo_pendiente <= monto_total),
        CONSTRAINT CK_Deudas_estado CHECK (estado IN ('VIGENTE','PAGADA'))
    );
END
GO

IF OBJECT_ID('dbo.PagosDeuda', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PagosDeuda (
        id_pago   INT IDENTITY(1,1) NOT NULL,
        id_deuda  INT NOT NULL,
        id_cuenta INT NOT NULL,
        monto     DECIMAL(14,2) NOT NULL,
        fecha     DATETIME2(0) NOT NULL CONSTRAINT DF_PagosDeuda_fecha DEFAULT SYSDATETIME(),
        CONSTRAINT PK_PagosDeuda PRIMARY KEY (id_pago),
        CONSTRAINT FK_Pagos_Deudas  FOREIGN KEY (id_deuda)  REFERENCES dbo.Deudas (id_deuda),
        CONSTRAINT FK_Pagos_Cuentas FOREIGN KEY (id_cuenta) REFERENCES dbo.Cuentas (id_cuenta),
        CONSTRAINT CK_Pagos_monto CHECK (monto > 0)
    );
END
GO

/* ===== INSERTAR ===== */
CREATE OR ALTER PROCEDURE dbo.usp_Deudas_Insertar
    @id_usuario        INT,
    @nombre_deuda      NVARCHAR(80),
    @acreedor          NVARCHAR(80),
    @monto_total       DECIMAL(14,2),
    @fecha_vencimiento DATE = NULL,
    @id_deuda          INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto_total IS NULL OR @monto_total <= 0
            THROW 50003, N'El monto de la deuda debe ser mayor a cero.', 1;
        IF @fecha_vencimiento IS NOT NULL AND @fecha_vencimiento <= CAST(SYSDATETIME() AS DATE)
            THROW 50003, N'La fecha de vencimiento debe ser posterior a hoy.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario AND estado = 'ACTIVO')
                THROW 50005, N'El usuario no existe o no está activo.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Deudas
                       WHERE id_usuario = @id_usuario
                         AND nombre_deuda = @nombre_deuda
                         AND estado = 'VIGENTE')
                THROW 50001, N'Ya tiene una deuda vigente con ese nombre.', 1;

            INSERT INTO dbo.Deudas (id_usuario, nombre_deuda, acreedor, monto_total, saldo_pendiente, fecha_vencimiento)
            VALUES (@id_usuario, @nombre_deuda, @acreedor, @monto_total, @monto_total, @fecha_vencimiento);

            SET @id_deuda = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ===== ACTUALIZAR (lo ya pagado no se toca) ===== */
CREATE OR ALTER PROCEDURE dbo.usp_Deudas_Actualizar
    @id_deuda          INT,
    @nombre_deuda      NVARCHAR(80),
    @acreedor          NVARCHAR(80),
    @monto_total       DECIMAL(14,2),
    @fecha_vencimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto_total IS NULL OR @monto_total <= 0
            THROW 50003, N'El monto de la deuda debe ser mayor a cero.', 1;
        IF @fecha_vencimiento IS NOT NULL AND @fecha_vencimiento <= CAST(SYSDATETIME() AS DATE)
            THROW 50003, N'La fecha de vencimiento debe ser posterior a hoy.', 1;

        BEGIN TRANSACTION;
            DECLARE @id_usuario INT, @estado VARCHAR(10), @total_actual DECIMAL(14,2), @saldo DECIMAL(14,2);

            SELECT @id_usuario = id_usuario, @estado = estado,
                   @total_actual = monto_total, @saldo = saldo_pendiente
            FROM dbo.Deudas WITH (UPDLOCK, ROWLOCK)
            WHERE id_deuda = @id_deuda;

            IF @id_usuario IS NULL
                THROW 50002, N'La deuda no existe.', 1;
            IF @estado <> 'VIGENTE'
                THROW 50006, N'Solo se pueden modificar deudas vigentes.', 1;

            DECLARE @pagado DECIMAL(14,2) = @total_actual - @saldo;

            IF @monto_total < @pagado
                THROW 50003, N'El monto total no puede ser menor a lo que ya se ha pagado.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Deudas
                       WHERE id_usuario = @id_usuario
                         AND nombre_deuda = @nombre_deuda
                         AND estado = 'VIGENTE'
                         AND id_deuda <> @id_deuda)
                THROW 50001, N'Ya tiene otra deuda vigente con ese nombre.', 1;

            UPDATE dbo.Deudas
            SET nombre_deuda      = @nombre_deuda,
                acreedor          = @acreedor,
                monto_total       = @monto_total,
                saldo_pendiente   = @monto_total - @pagado,
                fecha_vencimiento = @fecha_vencimiento
            WHERE id_deuda = @id_deuda;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ===== ELIMINAR (solo si no tiene pagos) ===== */
CREATE OR ALTER PROCEDURE dbo.usp_Deudas_Eliminar
    @id_deuda INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Deudas WHERE id_deuda = @id_deuda)
                THROW 50002, N'La deuda no existe.', 1;

            IF EXISTS (SELECT 1 FROM dbo.PagosDeuda WHERE id_deuda = @id_deuda)
                THROW 50004, N'No se puede borrar: la deuda ya tiene pagos.', 1;

            DELETE FROM dbo.Deudas WHERE id_deuda = @id_deuda;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ===== CONSULTAR ===== */
CREATE OR ALTER PROCEDURE dbo.usp_Deudas_Consultar
    @id_usuario INT,
    @id_deuda   INT = NULL,
    @estado     VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT id_deuda,
               id_usuario,
               nombre_deuda,
               acreedor,
               monto_total,
               saldo_pendiente,
               monto_total - saldo_pendiente AS monto_pagado,
               CAST((monto_total - saldo_pendiente) * 100.0 / monto_total AS DECIMAL(5,1)) AS porcentaje_pagado,
               fecha_vencimiento,
               estado,
               CASE WHEN estado = 'VIGENTE' AND fecha_vencimiento < CAST(SYSDATETIME() AS DATE)
                    THEN 1 ELSE 0 END AS vencida
        FROM dbo.Deudas
        WHERE id_usuario = @id_usuario
          AND (@id_deuda IS NULL OR id_deuda = @id_deuda)
          AND (@estado   IS NULL OR estado   = @estado)
        ORDER BY CASE WHEN estado = 'VIGENTE' THEN 0 ELSE 1 END,
                 CASE WHEN fecha_vencimiento IS NULL THEN 1 ELSE 0 END,
                 fecha_vencimiento,
                 nombre_deuda;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ===== PAGAR (procedimiento grande del modulo) ===== */
CREATE OR ALTER PROCEDURE dbo.usp_Deudas_Pagar
    @id_usuario INT,
    @id_deuda   INT,
    @id_cuenta  INT,
    @monto      DECIMAL(14,2),
    @id_pago    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto IS NULL OR @monto <= 0
            THROW 50003, N'El monto del pago debe ser mayor a cero.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario AND estado = 'ACTIVO')
                THROW 50005, N'El usuario no existe o no está activo.', 1;

            DECLARE @dueno_deuda INT, @estado_deuda VARCHAR(10), @pendiente DECIMAL(14,2);

            SELECT @dueno_deuda = id_usuario, @estado_deuda = estado, @pendiente = saldo_pendiente
            FROM dbo.Deudas WITH (UPDLOCK, ROWLOCK)
            WHERE id_deuda = @id_deuda;

            IF @dueno_deuda IS NULL
                THROW 50002, N'La deuda no existe.', 1;
            IF @dueno_deuda <> @id_usuario
                THROW 50008, N'La deuda no pertenece al usuario.', 1;
            IF @estado_deuda <> 'VIGENTE'
                THROW 50006, N'Solo se puede pagar una deuda vigente.', 1;
            IF @monto > @pendiente
                THROW 50003, N'El pago supera lo que falta por pagar.', 1;

            DECLARE @dueno_cuenta INT, @estado_cuenta VARCHAR(10),
                    @tipo_cuenta VARCHAR(10), @moneda CHAR(3), @saldo DECIMAL(14,2);

            SELECT @dueno_cuenta = id_usuario, @estado_cuenta = estado,
                   @tipo_cuenta = tipo_cuenta, @moneda = moneda, @saldo = saldo
            FROM dbo.Cuentas WITH (UPDLOCK, ROWLOCK)
            WHERE id_cuenta = @id_cuenta;

            IF @dueno_cuenta IS NULL
                THROW 50002, N'La cuenta no existe.', 1;
            IF @dueno_cuenta <> @id_usuario
                THROW 50008, N'La cuenta no pertenece al usuario.', 1;
            IF @estado_cuenta <> 'ACTIVA'
                THROW 50006, N'La cuenta está cerrada.', 1;
            IF @tipo_cuenta = 'TARJETA'
                THROW 50006, N'No se puede pagar una deuda desde una tarjeta.', 1;
            IF @moneda <> 'CRC'
                THROW 50006, N'Las deudas se manejan en colones: use una cuenta en CRC.', 1;
            IF @saldo < @monto
                THROW 50007, N'Saldo insuficiente en la cuenta.', 1;

            INSERT INTO dbo.PagosDeuda (id_deuda, id_cuenta, monto)
            VALUES (@id_deuda, @id_cuenta, @monto);

            SET @id_pago = SCOPE_IDENTITY();

            UPDATE dbo.Cuentas SET saldo = saldo - @monto WHERE id_cuenta = @id_cuenta;
            IF @@ROWCOUNT <> 1
                THROW 50009, N'No se pudo actualizar el saldo de la cuenta.', 1;

            UPDATE dbo.Deudas SET saldo_pendiente = saldo_pendiente - @monto WHERE id_deuda = @id_deuda;
            IF @@ROWCOUNT <> 1
                THROW 50009, N'No se pudo actualizar la deuda.', 1;
        COMMIT TRANSACTION;

        SELECT @id_pago AS id_pago,
               (SELECT saldo FROM dbo.Cuentas WHERE id_cuenta = @id_cuenta) AS saldo_cuenta,
               d.saldo_pendiente,
               CAST((d.monto_total - d.saldo_pendiente) * 100.0 / d.monto_total AS DECIMAL(5,1)) AS porcentaje_pagado
        FROM dbo.Deudas d
        WHERE d.id_deuda = @id_deuda;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ===== TRIGGER: marcar la deuda como pagada al llegar a cero ===== */
CREATE OR ALTER TRIGGER dbo.trg_Deudas_MarcarPagada
ON dbo.Deudas
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT UPDATE(saldo_pendiente) RETURN;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    BEGIN TRY
        UPDATE d
        SET d.estado = 'PAGADA'
        FROM dbo.Deudas d
        INNER JOIN inserted i ON i.id_deuda = d.id_deuda
        WHERE i.estado = 'VIGENTE'
          AND i.saldo_pendiente = 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
