/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   08_sp_reporte_resumen.sql
   PROCEDIMIENTO DE REPORTE: resumen financiero mensual de un usuario.
   Requiere: 01_crear_tablas.sql
   Codigos de error: 50003 valor invalido, 50005 usuario invalido
   ===================================================================== */
USE GravityFinance;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Reporte_ResumenFinanciero
    @id_usuario INT,
    @mes        TINYINT  = NULL,   -- si no se indica, el mes actual
    @anio       SMALLINT = NULL    -- si no se indica, el año actual
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET @mes  = ISNULL(@mes,  MONTH(SYSDATETIME()));
        SET @anio = ISNULL(@anio, YEAR(SYSDATETIME()));

        IF @mes NOT BETWEEN 1 AND 12
            THROW 50003, N'El mes debe estar entre 1 y 12.', 1;
        IF @anio NOT BETWEEN 2000 AND 2100
            THROW 50003, N'El año debe estar entre 2000 y 2100.', 1;

        DECLARE @desde DATE = DATEFROMPARTS(@anio, @mes, 1);
        DECLARE @hasta DATE = DATEADD(MONTH, 1, @desde);

        -- Las cuatro partes del reporte leen una misma "foto" de los datos
        SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios
                           WHERE id_usuario = @id_usuario AND estado = 'ACTIVO')
                THROW 50005, N'El usuario no existe o no está activo.', 1;

            -- 1) Ingresos, gastos y balance del mes, por moneda
            SELECT cu.moneda,
                   COUNT(m.id_movimiento) AS cantidad_movimientos,
                   ISNULL(SUM(CASE WHEN m.tipo_movimiento = 'INGRESO' THEN m.monto END), 0) AS total_ingresos,
                   ISNULL(SUM(CASE WHEN m.tipo_movimiento = 'GASTO'   THEN m.monto END), 0) AS total_gastos,
                   ISNULL(SUM(CASE WHEN m.tipo_movimiento = 'INGRESO' THEN m.monto
                                   WHEN m.tipo_movimiento = 'GASTO'   THEN -m.monto END), 0) AS balance_del_mes
            FROM dbo.Cuentas cu
            LEFT JOIN dbo.Movimientos m
                   ON m.id_cuenta = cu.id_cuenta
                  AND m.estado = 'ACTIVO'
                  AND m.fecha >= @desde AND m.fecha < @hasta
            WHERE cu.id_usuario = @id_usuario
            GROUP BY cu.moneda
            ORDER BY cu.moneda;

            -- 2) Gastos del mes por categoría contra su presupuesto (solo cuentas en colones)
            SELECT c.nombre_categoria,
                   SUM(m.monto)      AS total_gastado,
                   p.monto_limite    AS presupuesto,
                   CAST(SUM(m.monto) * 100.0 / p.monto_limite AS DECIMAL(6,1)) AS porcentaje_presupuesto,
                   CASE WHEN p.monto_limite IS NULL              THEN 'SIN_PRESUPUESTO'
                        WHEN SUM(m.monto) > p.monto_limite       THEN 'EXCEDIDO'
                        WHEN SUM(m.monto) >= p.monto_limite*0.8  THEN 'CERCA_DEL_LIMITE'
                        ELSE 'OK' END AS alerta
            FROM dbo.Movimientos m
            INNER JOIN dbo.Cuentas cu    ON cu.id_cuenta = m.id_cuenta
            INNER JOIN dbo.Categorias c  ON c.id_categoria = m.id_categoria
            LEFT JOIN dbo.Presupuestos p ON p.id_usuario = cu.id_usuario
                                        AND p.id_categoria = m.id_categoria
                                        AND p.mes = @mes AND p.anio = @anio
            WHERE cu.id_usuario = @id_usuario
              AND cu.moneda = 'CRC'
              AND m.tipo_movimiento = 'GASTO'
              AND m.estado = 'ACTIVO'
              AND m.fecha >= @desde AND m.fecha < @hasta
            GROUP BY c.nombre_categoria, p.monto_limite
            ORDER BY total_gastado DESC;

            -- 3) Saldos actuales de las cuentas activas
            SELECT nombre_cuenta, tipo_cuenta, moneda, saldo
            FROM dbo.Cuentas
            WHERE id_usuario = @id_usuario AND estado = 'ACTIVA'
            ORDER BY nombre_cuenta;

            -- 4) Metas de ahorro: avance y lo aportado durante el mes
            SELECT ms.nombre_meta,
                   ms.monto_objetivo,
                   ms.monto_actual,
                   ms.monto_objetivo - ms.monto_actual AS faltante,
                   CAST(ms.monto_actual * 100.0 / ms.monto_objetivo AS DECIMAL(5,1)) AS porcentaje_avance,
                   ISNULL((SELECT SUM(a.monto)
                           FROM dbo.AportesMeta a
                           WHERE a.id_meta = ms.id_meta
                             AND a.fecha >= @desde AND a.fecha < @hasta), 0) AS aportado_en_el_mes,
                   ms.fecha_limite,
                   ms.estado
            FROM dbo.MetasAhorro ms
            WHERE ms.id_usuario = @id_usuario
            ORDER BY ms.estado, ms.fecha_limite, ms.nombre_meta;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
