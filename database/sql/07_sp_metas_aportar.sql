/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   07_sp_metas_aportar.sql
   PROCEDIMIENTO NO BASICO 3: aportar dinero a una meta de ahorro.
   (Marcar la meta como CUMPLIDA lo hace el trigger de 09_triggers.sql)
   Requiere: 01_crear_tablas.sql
   Codigos de error: 50002 no existe, 50003 valor invalido,
   50005 usuario invalido, 50006 cambio no permitido,
   50007 saldo insuficiente, 50008 cuenta o meta ajena,
   50009 fallo al actualizar
   ===================================================================== */
USE GravityFinance;
GO

CREATE OR ALTER PROCEDURE dbo.usp_MetasAhorro_Aportar
    @id_usuario INT,
    @id_meta    INT,
    @id_cuenta  INT,
    @monto      DECIMAL(14,2),
    @id_aporte  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto IS NULL OR @monto <= 0
            THROW 50003, N'El monto del aporte debe ser mayor a cero.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios
                           WHERE id_usuario = @id_usuario AND estado = 'ACTIVO')
                THROW 50005, N'El usuario no existe o no está activo.', 1;

            -- Se lee y se bloquea la meta hasta que termine la transacción
            DECLARE @dueno_meta INT, @estado_meta VARCHAR(10),
                    @objetivo DECIMAL(14,2), @acumulado DECIMAL(14,2);

            SELECT @dueno_meta = id_usuario, @estado_meta = estado,
                   @objetivo = monto_objetivo, @acumulado = monto_actual
            FROM dbo.MetasAhorro WITH (UPDLOCK, ROWLOCK)
            WHERE id_meta = @id_meta;

            IF @dueno_meta IS NULL
                THROW 50002, N'La meta no existe.', 1;
            IF @dueno_meta <> @id_usuario
                THROW 50008, N'La meta no pertenece al usuario.', 1;
            IF @estado_meta <> 'EN_CURSO'
                THROW 50006, N'Solo se puede aportar a metas que estén en curso.', 1;
            IF @acumulado + @monto > @objetivo
                THROW 50003, N'El aporte supera lo que le falta a la meta.', 1;

            -- Se lee y se bloquea la cuenta
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
                THROW 50006, N'No se puede aportar a una meta desde una tarjeta.', 1;
            IF @moneda <> 'CRC'
                THROW 50006, N'Las metas se manejan en colones: use una cuenta en CRC.', 1;
            IF @saldo < @monto
                THROW 50007, N'Saldo insuficiente en la cuenta.', 1;

            INSERT INTO dbo.AportesMeta (id_meta, id_cuenta, monto)
            VALUES (@id_meta, @id_cuenta, @monto);

            SET @id_aporte = SCOPE_IDENTITY();

            UPDATE dbo.Cuentas SET saldo = saldo - @monto WHERE id_cuenta = @id_cuenta;
            IF @@ROWCOUNT <> 1
                THROW 50009, N'No se pudo actualizar el saldo de la cuenta.', 1;

            UPDATE dbo.MetasAhorro SET monto_actual = monto_actual + @monto WHERE id_meta = @id_meta;
            IF @@ROWCOUNT <> 1
                THROW 50009, N'No se pudo actualizar el avance de la meta.', 1;
        COMMIT TRANSACTION;

        -- Resultado: cómo quedó todo después del aporte
        SELECT @id_aporte AS id_aporte,
               (SELECT saldo FROM dbo.Cuentas WHERE id_cuenta = @id_cuenta) AS saldo_cuenta,
               m.monto_actual,
               m.monto_objetivo - m.monto_actual AS faltante,
               CAST(m.monto_actual * 100.0 / m.monto_objetivo AS DECIMAL(5,1)) AS porcentaje_avance
        FROM dbo.MetasAhorro m
        WHERE m.id_meta = @id_meta;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
