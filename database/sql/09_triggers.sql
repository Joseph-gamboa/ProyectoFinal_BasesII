/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   09_triggers.sql
   Los 3 triggers especiales. EJECUTAR AL FINAL, despues de 01 a 08.
   Requiere: 01_crear_tablas.sql
   NOTA: una vez creado el trigger 1, un DELETE sobre Movimientos ya no
   borra: solo anula el movimiento y devuelve el dinero a la cuenta.
   Codigo de error: 50010 la anulacion dejaria saldo negativo
   ===================================================================== */
USE GravityFinance;
GO

/* =====================================================
   TRIGGER 1 (INSTEAD OF): anular en lugar de borrar un movimiento
   ===================================================== */
CREATE OR ALTER TRIGGER dbo.trg_Movimientos_AnularEnLugarDeBorrar
ON dbo.Movimientos
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    BEGIN TRY
        -- Efecto neto en cada cuenta de los movimientos activos que se anulan
        DECLARE @ajustes TABLE (
            id_cuenta INT PRIMARY KEY,
            ajuste    DECIMAL(14,2) NOT NULL
        );

        INSERT INTO @ajustes (id_cuenta, ajuste)
        SELECT d.id_cuenta,
               SUM(CASE WHEN d.tipo_movimiento = 'INGRESO' THEN -d.monto ELSE d.monto END)
        FROM deleted d
        WHERE d.estado = 'ACTIVO'
        GROUP BY d.id_cuenta;

        -- Una cuenta que no sea tarjeta no puede quedar en negativo
        IF EXISTS (SELECT 1
                   FROM @ajustes a
                   INNER JOIN dbo.Cuentas c ON c.id_cuenta = a.id_cuenta
                   WHERE c.tipo_cuenta <> 'TARJETA' AND c.saldo + a.ajuste < 0)
            THROW 50010, N'No se puede anular: la cuenta quedaría con saldo negativo.', 1;

        UPDATE c
        SET c.saldo = c.saldo + a.ajuste
        FROM dbo.Cuentas c
        INNER JOIN @ajustes a ON a.id_cuenta = c.id_cuenta;

        UPDATE m
        SET m.estado = 'ANULADO'
        FROM dbo.Movimientos m
        INNER JOIN deleted d ON d.id_movimiento = m.id_movimiento
        WHERE m.estado = 'ACTIVO';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* =====================================================
   TRIGGER 2 (AFTER INSERT, UPDATE, DELETE): bitacora de movimientos
   ===================================================== */
CREATE OR ALTER TRIGGER dbo.trg_Movimientos_Bitacora
ON dbo.Movimientos
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        BEGIN
            -- UPDATE: monto de antes y de después
            INSERT INTO dbo.BitacoraMovimientos (id_movimiento, operacion, monto_anterior, monto_nuevo)
            SELECT i.id_movimiento, 'UPDATE', d.monto, i.monto
            FROM inserted i
            INNER JOIN deleted d ON d.id_movimiento = i.id_movimiento;
        END
        ELSE IF EXISTS (SELECT 1 FROM inserted)
        BEGIN
            INSERT INTO dbo.BitacoraMovimientos (id_movimiento, operacion, monto_anterior, monto_nuevo)
            SELECT i.id_movimiento, 'INSERT', NULL, i.monto
            FROM inserted i;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.BitacoraMovimientos (id_movimiento, operacion, monto_anterior, monto_nuevo)
            SELECT d.id_movimiento, 'DELETE', d.monto, NULL
            FROM deleted d;
        END
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* =====================================================
   TRIGGER 3 (AFTER UPDATE): marcar la meta como cumplida
   ===================================================== */
CREATE OR ALTER TRIGGER dbo.trg_MetasAhorro_MarcarCumplida
ON dbo.MetasAhorro
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT (UPDATE(monto_actual) OR UPDATE(monto_objetivo)) RETURN;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    BEGIN TRY
        UPDATE m
        SET m.estado = 'CUMPLIDA'
        FROM dbo.MetasAhorro m
        INNER JOIN inserted i ON i.id_meta = m.id_meta
        WHERE i.estado = 'EN_CURSO'
          AND i.monto_actual >= i.monto_objetivo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
