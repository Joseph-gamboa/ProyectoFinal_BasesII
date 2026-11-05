/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   05_sp_transferencias_registrar.sql
   PROCEDIMIENTO NO BASICO 1: registrar una transferencia entre cuentas.
   Requiere: 01_crear_tablas.sql
   Codigos de error: 50002 no existe, 50003 valor invalido,
   50005 usuario invalido, 50006 cambio no permitido,
   50007 saldo insuficiente, 50008 cuenta ajena, 50009 fallo al actualizar
   ===================================================================== */
USE GravityFinance;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Transferencias_Registrar
    @id_usuario        INT,
    @id_cuenta_origen  INT,
    @id_cuenta_destino INT,
    @monto             DECIMAL(14,2),
    @descripcion       NVARCHAR(150) = NULL,
    @id_transferencia  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto IS NULL OR @monto <= 0
            THROW 50003, N'El monto debe ser mayor a cero.', 1;
        IF @id_cuenta_origen = @id_cuenta_destino
            THROW 50003, N'La cuenta de origen y la de destino deben ser distintas.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios
                           WHERE id_usuario = @id_usuario AND estado = 'ACTIVO')
                THROW 50005, N'El usuario no existe o no está activo.', 1;

            -- Se leen y se bloquean las dos cuentas hasta que termine la transacción
            DECLARE @cuentas TABLE (
                id_cuenta   INT PRIMARY KEY,
                id_usuario  INT,
                tipo_cuenta VARCHAR(10),
                moneda      CHAR(3),
                saldo       DECIMAL(14,2),
                estado      VARCHAR(10)
            );

            INSERT INTO @cuentas (id_cuenta, id_usuario, tipo_cuenta, moneda, saldo, estado)
            SELECT id_cuenta, id_usuario, tipo_cuenta, moneda, saldo, estado
            FROM dbo.Cuentas WITH (UPDLOCK, ROWLOCK)
            WHERE id_cuenta IN (@id_cuenta_origen, @id_cuenta_destino);

            IF (SELECT COUNT(*) FROM @cuentas) <> 2
                THROW 50002, N'Alguna de las dos cuentas no existe.', 1;

            IF EXISTS (SELECT 1 FROM @cuentas WHERE id_usuario <> @id_usuario)
                THROW 50008, N'Las dos cuentas deben pertenecer al usuario.', 1;

            IF EXISTS (SELECT 1 FROM @cuentas WHERE estado <> 'ACTIVA')
                THROW 50006, N'Una de las cuentas está cerrada.', 1;

            DECLARE @moneda_origen  CHAR(3),
                    @moneda_destino CHAR(3),
                    @saldo_origen   DECIMAL(14,2),
                    @tipo_origen    VARCHAR(10);

            SELECT @moneda_origen = moneda, @saldo_origen = saldo, @tipo_origen = tipo_cuenta
            FROM @cuentas WHERE id_cuenta = @id_cuenta_origen;

            SELECT @moneda_destino = moneda
            FROM @cuentas WHERE id_cuenta = @id_cuenta_destino;

            IF @moneda_origen <> @moneda_destino
                THROW 50006, N'Las cuentas deben tener la misma moneda; no se hace conversión.', 1;

            -- Las tarjetas pueden quedar en negativo (representan deuda)
            IF @tipo_origen <> 'TARJETA' AND @saldo_origen < @monto
                THROW 50007, N'Saldo insuficiente en la cuenta de origen.', 1;

            INSERT INTO dbo.Transferencias (id_cuenta_origen, id_cuenta_destino, monto, descripcion)
            VALUES (@id_cuenta_origen, @id_cuenta_destino, @monto, @descripcion);

            SET @id_transferencia = SCOPE_IDENTITY();

            UPDATE dbo.Cuentas SET saldo = saldo - @monto WHERE id_cuenta = @id_cuenta_origen;
            IF @@ROWCOUNT <> 1
                THROW 50009, N'No se pudo actualizar el saldo de la cuenta de origen.', 1;

            UPDATE dbo.Cuentas SET saldo = saldo + @monto WHERE id_cuenta = @id_cuenta_destino;
            IF @@ROWCOUNT <> 1
                THROW 50009, N'No se pudo actualizar el saldo de la cuenta de destino.', 1;
        COMMIT TRANSACTION;

        -- Resultado: los saldos ya actualizados
        SELECT @id_transferencia AS id_transferencia,
               (SELECT saldo FROM dbo.Cuentas WHERE id_cuenta = @id_cuenta_origen)  AS saldo_origen,
               (SELECT saldo FROM dbo.Cuentas WHERE id_cuenta = @id_cuenta_destino) AS saldo_destino;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
