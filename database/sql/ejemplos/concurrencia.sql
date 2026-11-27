/*
   Gravity Finance - ejemplo de concurrencia.
   Abrir este archivo en dos consultas de SSMS: A y B.
   Seleccionar y ejecutar cada paso por separado, no todo el archivo.
   Usa el procedimiento del proyecto; no crea tablas permanentes.
*/

-- Paso 1. Ejecutar en A y B antes de continuar.
-- La cuenta se crea desde la aplicacion: Efectivo, CRC, 100000 y sin movimientos.
-- Para repetir el ejemplo, crear otra cuenta y cambiar este nombre en ambas ventanas.
USE GravityFinance;
GO

IF @@TRANCOUNT <> 0
    THROW 50100, N'Use una ventana sin transacciones abiertas.', 1;

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET LOCK_TIMEOUT 60000;

DECLARE @nombreCuenta NVARCHAR(60) = N'concurrencia';

IF (SELECT COUNT(*) FROM dbo.Cuentas WHERE nombre_cuenta = @nombreCuenta) <> 1
    THROW 50100, N'Debe existir una sola cuenta con el nombre de la prueba.', 1;

IF NOT EXISTS (
    SELECT 1 FROM dbo.Cuentas
    WHERE nombre_cuenta = @nombreCuenta
      AND tipo_cuenta = 'EFECTIVO' AND moneda = 'CRC'
      AND estado = 'ACTIVA' AND saldo = 100000
)
    THROW 50100, N'La cuenta debe estar activa y tener 100000 CRC en efectivo.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.Movimientos AS m
    INNER JOIN dbo.Cuentas AS c ON c.id_cuenta = m.id_cuenta
    WHERE c.nombre_cuenta = @nombreCuenta
)
    THROW 50100, N'Use una cuenta nueva, sin movimientos.', 1;

DECLARE @categoria INT = (
    SELECT TOP (1) id_categoria
    FROM dbo.Categorias
    WHERE tipo_categoria = 'GASTO'
    ORDER BY id_categoria
);

IF @categoria IS NULL
    THROW 50100, N'Debe existir una categoria de gasto.', 1;

-- Cada ventana conserva los identificadores en su propia tabla temporal.
IF OBJECT_ID(N'tempdb..#Concurrencia') IS NOT NULL
    DROP TABLE #Concurrencia;

SELECT id_usuario, id_cuenta, @categoria AS id_categoria
INTO #Concurrencia
FROM dbo.Cuentas
WHERE nombre_cuenta = @nombreCuenta;

SELECT @@SERVERNAME AS servidor, DB_NAME() AS base,
       @@SPID AS sesion, @@TRANCOUNT AS transacciones_abiertas,
       id_usuario, id_cuenta
FROM #Concurrencia;
-- A y B deben mostrar la misma cuenta, sesiones distintas y cero transacciones.
GO

-- Paso 2. Solo en A: registrar el primer gasto y mantener abierta la transaccion.
DECLARE @usuario INT, @cuenta INT, @categoria INT, @movimiento INT;
SELECT @usuario = id_usuario, @cuenta = id_cuenta, @categoria = id_categoria
FROM #Concurrencia;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Cuentas WITH (UPDLOCK, ROWLOCK)
        WHERE id_cuenta = @cuenta AND saldo = 100000 AND estado = 'ACTIVA'
    ) OR EXISTS (SELECT 1 FROM dbo.Movimientos WHERE id_cuenta = @cuenta)
        THROW 50100, N'La cuenta de prueba ya cambio. Prepare una cuenta nueva.', 1;

    EXEC dbo.usp_Movimientos_Registrar
        @id_usuario = @usuario,
        @id_cuenta = @cuenta,
        @id_categoria = @categoria,
        @tipo_movimiento = 'GASTO',
        @monto = 80000,
        @detalle = N'Prueba de concurrencia A',
        @metodo_pago = 'EFECTIVO',
        @descripcion = N'Demostracion de concurrencia',
        @id_movimiento = @movimiento OUTPUT;

    SELECT @@SPID AS sesion_A, @@TRANCOUNT AS transaccion_abierta;
    -- El saldo es 20000; el bloqueo se conserva hasta el paso 4.
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Paso 3. Solo en B: intentar el segundo gasto antes de confirmar A.
-- B queda ejecutando. Capturar esa espera y pasar a A antes de 60 segundos.
DECLARE @usuario INT, @cuenta INT, @categoria INT, @movimiento INT;
SELECT @usuario = id_usuario, @cuenta = id_cuenta, @categoria = id_categoria
FROM #Concurrencia;

BEGIN TRY
    EXEC dbo.usp_Movimientos_Registrar
        @id_usuario = @usuario,
        @id_cuenta = @cuenta,
        @id_categoria = @categoria,
        @tipo_movimiento = 'GASTO',
        @monto = 80000,
        @detalle = N'Prueba de concurrencia B',
        @metodo_pago = 'EFECTIVO',
        @descripcion = N'Demostracion de concurrencia',
        @id_movimiento = @movimiento OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS resultado;
END CATCH;
-- Despues del paso 4, se espera el error 50007: saldo insuficiente.
-- Si aparece 1222, vencio la espera: confirmar A y repetir solo este paso.
GO

-- Paso 4. Solo en A, mientras B espera: confirmar el primer gasto.
IF @@TRANCOUNT <> 1
    THROW 50100, N'La transaccion de A no esta en el estado esperado.', 1;

COMMIT TRANSACTION;
SELECT @@TRANCOUNT AS transacciones_abiertas;
GO

-- Paso 5. Cuando B termine, ejecutar en A para comprobar el resultado.
SELECT c.nombre_cuenta,
       c.saldo,
       (SELECT COUNT(*) FROM dbo.Movimientos AS m
        WHERE m.id_cuenta = c.id_cuenta) AS movimientos_registrados
FROM dbo.Cuentas AS c
INNER JOIN #Concurrencia AS p ON p.id_cuenta = c.id_cuenta;
-- Resultado esperado: saldo 20000 y un solo movimiento registrado.
-- A confirmo su gasto; B leyo el saldo actualizado y rechazo el segundo.
GO

-- Cancelacion opcional, antes del COMMIT: detener primero la consulta de B.
-- Ejecutar este bloque en B y luego en A para descartar transacciones pendientes.
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO
