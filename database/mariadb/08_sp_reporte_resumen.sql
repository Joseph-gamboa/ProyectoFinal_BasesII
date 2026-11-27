/* =====================================================================
   Gravity Finance - ENTORNO LOCAL (MariaDB)
   08_sp_reporte_resumen.sql
   Equivalente de database/sql/08_sp_reporte_resumen.sql.
   PROCEDIMIENTO DE REPORTE: resumen financiero mensual de un usuario.
   Devuelve 4 conjuntos de resultados, en el mismo orden que SQL Server.
   Codigos de error: 50003 valor invalido, 50005 usuario invalido
   ===================================================================== */
SET NAMES utf8mb4;

DELIMITER $$

DROP PROCEDURE IF EXISTS usp_Reporte_ResumenFinanciero$$
CREATE PROCEDURE usp_Reporte_ResumenFinanciero(
    IN p_id_usuario INT,
    IN p_mes        INT,    -- NULL = mes actual
    IN p_anio       INT     -- NULL = año actual
)
BEGIN
    DECLARE v_desde DATE;
    DECLARE v_hasta DATE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_mes  = IFNULL(p_mes,  MONTH(CURRENT_DATE));
    SET p_anio = IFNULL(p_anio, YEAR(CURRENT_DATE));

    IF p_mes NOT BETWEEN 1 AND 12 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El mes debe estar entre 1 y 12.';
    END IF;
    IF p_anio NOT BETWEEN 2000 AND 2100 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El año debe estar entre 2000 y 2100.';
    END IF;

    SET v_desde = MAKEDATE(p_anio, 1) + INTERVAL (p_mes - 1) MONTH;
    SET v_hasta = v_desde + INTERVAL 1 MONTH;

    -- Las cuatro partes del reporte leen una misma "foto" de los datos
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios
                       WHERE id_usuario = p_id_usuario AND estado = 'ACTIVO') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005, MESSAGE_TEXT = 'El usuario no existe o no está activo.';
        END IF;

        -- 1) Ingresos, gastos y balance del mes, por moneda
        SELECT cu.moneda,
               COUNT(m.id_movimiento) AS cantidad_movimientos,
               IFNULL(SUM(CASE WHEN m.tipo_movimiento = 'INGRESO' THEN m.monto END), 0) AS total_ingresos,
               IFNULL(SUM(CASE WHEN m.tipo_movimiento = 'GASTO'   THEN m.monto END), 0) AS total_gastos,
               IFNULL(SUM(CASE WHEN m.tipo_movimiento = 'INGRESO' THEN m.monto
                               WHEN m.tipo_movimiento = 'GASTO'   THEN -m.monto END), 0) AS balance_del_mes
        FROM Cuentas cu
        LEFT JOIN Movimientos m
               ON m.id_cuenta = cu.id_cuenta
              AND m.estado = 'ACTIVO'
              AND m.fecha >= v_desde AND m.fecha < v_hasta
        WHERE cu.id_usuario = p_id_usuario
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
        FROM Movimientos m
        INNER JOIN Cuentas cu    ON cu.id_cuenta = m.id_cuenta
        INNER JOIN Categorias c  ON c.id_categoria = m.id_categoria
        LEFT JOIN Presupuestos p ON p.id_usuario = cu.id_usuario
                                AND p.id_categoria = m.id_categoria
                                AND p.mes = p_mes AND p.anio = p_anio
        WHERE cu.id_usuario = p_id_usuario
          AND cu.moneda = 'CRC'
          AND m.tipo_movimiento = 'GASTO'
          AND m.estado = 'ACTIVO'
          AND m.fecha >= v_desde AND m.fecha < v_hasta
        GROUP BY c.nombre_categoria, p.monto_limite
        ORDER BY total_gastado DESC;

        -- 3) Saldos actuales de las cuentas activas
        SELECT nombre_cuenta, tipo_cuenta, moneda, saldo
        FROM Cuentas
        WHERE id_usuario = p_id_usuario AND estado = 'ACTIVA'
        ORDER BY nombre_cuenta;

        -- 4) Metas de ahorro: avance y lo aportado durante el mes
        SELECT ms.nombre_meta,
               ms.monto_objetivo,
               ms.monto_actual,
               ms.monto_objetivo - ms.monto_actual AS faltante,
               CAST(ms.monto_actual * 100.0 / ms.monto_objetivo AS DECIMAL(5,1)) AS porcentaje_avance,
               IFNULL((SELECT SUM(a.monto)
                       FROM AportesMeta a
                       WHERE a.id_meta = ms.id_meta
                         AND a.fecha >= v_desde AND a.fecha < v_hasta), 0) AS aportado_en_el_mes,
               ms.fecha_limite,
               ms.estado
        FROM MetasAhorro ms
        WHERE ms.id_usuario = p_id_usuario
        ORDER BY ms.estado, ms.fecha_limite, ms.nombre_meta;
    COMMIT;
END$$

DELIMITER ;
