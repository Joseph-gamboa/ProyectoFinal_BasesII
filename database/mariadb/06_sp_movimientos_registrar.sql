/* =====================================================================
   Gravity Finance - ENTORNO LOCAL (MariaDB)
   06_sp_movimientos_registrar.sql
   Equivalente de database/sql/06_sp_movimientos_registrar.sql.
   PROCEDIMIENTO NO BASICO 2: registrar un movimiento (ingreso o gasto),
   actualizar el saldo y avisar del estado del presupuesto.
   Incluye ademas usp_Movimientos_Anular, que en MariaDB hace el trabajo
   del trigger INSTEAD OF DELETE de SQL Server (ver 09_triggers.sql).
   Codigos de error: 50002 no existe, 50003 valor invalido,
   50005 usuario invalido, 50006 cambio no permitido,
   50007 saldo insuficiente, 50008 cuenta ajena, 50009 fallo al actualizar,
   50010 la anulacion dejaria saldo negativo
   ===================================================================== */
SET NAMES utf8mb4;

DELIMITER $$

DROP PROCEDURE IF EXISTS usp_Movimientos_Registrar$$
CREATE PROCEDURE usp_Movimientos_Registrar(
    IN  p_id_usuario      INT,
    IN  p_id_cuenta       INT,
    IN  p_id_categoria    INT,
    IN  p_tipo_movimiento VARCHAR(7),
    IN  p_monto           DECIMAL(14,2),
    IN  p_detalle         VARCHAR(80),     -- fuente (ingreso) o comercio (gasto)
    IN  p_metodo_pago     VARCHAR(13),     -- solo para gastos (NULL en ingresos)
    IN  p_fecha           DATE,            -- NULL = hoy
    IN  p_descripcion     VARCHAR(150),
    OUT p_id_movimiento   INT
)
BEGIN
    DECLARE v_dueno          INT DEFAULT NULL;
    DECLARE v_estado_cuenta  VARCHAR(10);
    DECLARE v_tipo_cuenta    VARCHAR(10);
    DECLARE v_saldo          DECIMAL(14,2);
    DECLARE v_tipo_categoria VARCHAR(7) DEFAULT NULL;
    DECLARE v_alerta         VARCHAR(20) DEFAULT 'NO_APLICA';
    DECLARE v_porcentaje     DECIMAL(6,1) DEFAULT NULL;
    DECLARE v_id_presupuesto INT DEFAULT NULL;
    DECLARE v_limite         DECIMAL(14,2) DEFAULT NULL;
    DECLARE v_gastado        DECIMAL(14,2) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_fecha = IFNULL(p_fecha, CURRENT_DATE);

    IF p_monto IS NULL OR p_monto <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El monto debe ser mayor a cero.';
    END IF;
    IF p_tipo_movimiento NOT IN ('INGRESO','GASTO') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El tipo de movimiento debe ser INGRESO o GASTO.';
    END IF;
    IF p_fecha > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'La fecha del movimiento no puede ser futura.';
    END IF;
    IF p_detalle IS NULL OR CHAR_LENGTH(TRIM(p_detalle)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'Indique la fuente del ingreso o el comercio del gasto.';
    END IF;
    IF p_tipo_movimiento = 'GASTO'
       AND (p_metodo_pago IS NULL OR p_metodo_pago NOT IN ('EFECTIVO','TARJETA','TRANSFERENCIA')) THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'Un gasto necesita método de pago: EFECTIVO, TARJETA o TRANSFERENCIA.';
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios
                       WHERE id_usuario = p_id_usuario AND estado = 'ACTIVO') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005, MESSAGE_TEXT = 'El usuario no existe o no está activo.';
        END IF;

        -- Se lee y se bloquea la cuenta hasta que termine la transacción
        SELECT id_usuario, estado, tipo_cuenta, saldo
          INTO v_dueno, v_estado_cuenta, v_tipo_cuenta, v_saldo
        FROM Cuentas
        WHERE id_cuenta = p_id_cuenta
        FOR UPDATE;

        IF v_dueno IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La cuenta no existe.';
        END IF;
        IF v_dueno <> p_id_usuario THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50008, MESSAGE_TEXT = 'La cuenta no pertenece al usuario.';
        END IF;
        IF v_estado_cuenta <> 'ACTIVA' THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'La cuenta está cerrada.';
        END IF;

        SELECT tipo_categoria INTO v_tipo_categoria
        FROM Categorias WHERE id_categoria = p_id_categoria;

        IF v_tipo_categoria IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La categoría no existe.';
        END IF;
        IF v_tipo_categoria <> p_tipo_movimiento THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'La categoría no corresponde al tipo de movimiento.';
        END IF;

        -- Las tarjetas pueden quedar en negativo (representan deuda)
        IF p_tipo_movimiento = 'GASTO' AND v_tipo_cuenta <> 'TARJETA' AND v_saldo < p_monto THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50007, MESSAGE_TEXT = 'Saldo insuficiente en la cuenta.';
        END IF;

        INSERT INTO Movimientos (id_cuenta, id_categoria, tipo_movimiento, monto, fecha, descripcion)
        VALUES (p_id_cuenta, p_id_categoria, p_tipo_movimiento, p_monto, p_fecha, p_descripcion);

        SET p_id_movimiento = LAST_INSERT_ID();

        IF p_tipo_movimiento = 'INGRESO' THEN
            INSERT INTO Ingresos (id_movimiento, fuente)
            VALUES (p_id_movimiento, TRIM(p_detalle));
        ELSE
            INSERT INTO Gastos (id_movimiento, comercio, metodo_pago)
            VALUES (p_id_movimiento, TRIM(p_detalle), p_metodo_pago);
        END IF;

        UPDATE Cuentas
        SET saldo = CASE WHEN p_tipo_movimiento = 'INGRESO' THEN saldo + p_monto
                         ELSE saldo - p_monto END
        WHERE id_cuenta = p_id_cuenta;
        IF ROW_COUNT() <> 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50009, MESSAGE_TEXT = 'No se pudo actualizar el saldo de la cuenta.';
        END IF;

        -- Aviso de presupuesto (solo para gastos): avisa, no bloquea
        IF p_tipo_movimiento = 'GASTO' THEN
            SELECT id_presupuesto, monto_limite INTO v_id_presupuesto, v_limite
            FROM Presupuestos
            WHERE id_usuario = p_id_usuario AND id_categoria = p_id_categoria
              AND mes = MONTH(p_fecha) AND anio = YEAR(p_fecha);

            IF v_id_presupuesto IS NULL THEN
                SET v_alerta = 'SIN_PRESUPUESTO';
            ELSE
                SELECT SUM(m.monto) INTO v_gastado
                FROM Movimientos m
                INNER JOIN Cuentas cu ON cu.id_cuenta = m.id_cuenta
                WHERE cu.id_usuario = p_id_usuario
                  AND m.id_categoria = p_id_categoria
                  AND m.tipo_movimiento = 'GASTO'
                  AND m.estado = 'ACTIVO'
                  AND MONTH(m.fecha) = MONTH(p_fecha)
                  AND YEAR(m.fecha)  = YEAR(p_fecha);

                SET v_porcentaje = v_gastado * 100.0 / v_limite;
                SET v_alerta = CASE WHEN v_gastado > v_limite        THEN 'EXCEDIDO'
                                    WHEN v_gastado >= v_limite * 0.8 THEN 'CERCA_DEL_LIMITE'
                                    ELSE 'OK' END;
            END IF;
        END IF;
    COMMIT;

    SELECT p_id_movimiento AS id_movimiento,
           (SELECT saldo FROM Cuentas WHERE id_cuenta = p_id_cuenta) AS saldo_nuevo,
           v_alerta     AS alerta_presupuesto,
           v_porcentaje AS porcentaje_presupuesto;
END$$

/* =====================================================
   ANULAR un movimiento (devuelve el dinero a la cuenta).
   En SQL Server esto lo hace el trigger INSTEAD OF DELETE cuando se
   ejecuta DELETE sobre Movimientos. MariaDB no tiene triggers
   INSTEAD OF, asi que aqui es un procedimiento explicito y Laravel lo
   llama cuando trabaja con MariaDB. La logica es la misma.
   ===================================================== */
DROP PROCEDURE IF EXISTS usp_Movimientos_Anular$$
CREATE PROCEDURE usp_Movimientos_Anular(
    IN p_id_movimiento INT
)
BEGIN
    DECLARE v_id_cuenta INT DEFAULT NULL;
    DECLARE v_tipo      VARCHAR(7);
    DECLARE v_monto     DECIMAL(14,2);
    DECLARE v_estado    VARCHAR(8);
    DECLARE v_ajuste    DECIMAL(14,2);
    DECLARE v_tipo_cta  VARCHAR(10);
    DECLARE v_saldo     DECIMAL(14,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        SELECT id_cuenta, tipo_movimiento, monto, estado
          INTO v_id_cuenta, v_tipo, v_monto, v_estado
        FROM Movimientos
        WHERE id_movimiento = p_id_movimiento
        FOR UPDATE;

        -- Igual que en SQL Server: si no existe o ya esta anulado, no pasa nada
        IF v_id_cuenta IS NOT NULL AND v_estado = 'ACTIVO' THEN
            SET v_ajuste = CASE WHEN v_tipo = 'INGRESO' THEN -v_monto ELSE v_monto END;

            SELECT tipo_cuenta, saldo INTO v_tipo_cta, v_saldo
            FROM Cuentas WHERE id_cuenta = v_id_cuenta
            FOR UPDATE;

            -- Una cuenta que no sea tarjeta no puede quedar en negativo
            IF v_tipo_cta <> 'TARJETA' AND v_saldo + v_ajuste < 0 THEN
                SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50010, MESSAGE_TEXT = 'No se puede anular: la cuenta quedaría con saldo negativo.';
            END IF;

            UPDATE Cuentas SET saldo = saldo + v_ajuste WHERE id_cuenta = v_id_cuenta;
            UPDATE Movimientos SET estado = 'ANULADO'
            WHERE id_movimiento = p_id_movimiento AND estado = 'ACTIVO';
        END IF;
    COMMIT;
END$$

DELIMITER ;
