/* =====================================================================
   Gravity Finance - ENTORNO LOCAL (MariaDB)
   07_sp_metas_aportar.sql
   Equivalente de database/sql/07_sp_metas_aportar.sql.
   PROCEDIMIENTO NO BASICO 3: aportar dinero a una meta de ahorro.
   (Marcar la meta como CUMPLIDA lo hace el trigger de 09_triggers.sql)
   Codigos de error: 50002 no existe, 50003 valor invalido,
   50005 usuario invalido, 50006 cambio no permitido,
   50007 saldo insuficiente, 50008 cuenta o meta ajena,
   50009 fallo al actualizar
   ===================================================================== */
SET NAMES utf8mb4;

DELIMITER $$

DROP PROCEDURE IF EXISTS usp_MetasAhorro_Aportar$$
CREATE PROCEDURE usp_MetasAhorro_Aportar(
    IN  p_id_usuario INT,
    IN  p_id_meta    INT,
    IN  p_id_cuenta  INT,
    IN  p_monto      DECIMAL(14,2),
    OUT p_id_aporte  INT
)
BEGIN
    DECLARE v_dueno_meta   INT DEFAULT NULL;
    DECLARE v_estado_meta  VARCHAR(10);
    DECLARE v_objetivo     DECIMAL(14,2);
    DECLARE v_acumulado    DECIMAL(14,2);
    DECLARE v_dueno_cuenta INT DEFAULT NULL;
    DECLARE v_estado_cta   VARCHAR(10);
    DECLARE v_tipo_cuenta  VARCHAR(10);
    DECLARE v_moneda       CHAR(3);
    DECLARE v_saldo        DECIMAL(14,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El monto del aporte debe ser mayor a cero.';
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios
                       WHERE id_usuario = p_id_usuario AND estado = 'ACTIVO') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005, MESSAGE_TEXT = 'El usuario no existe o no está activo.';
        END IF;

        -- Se lee y se bloquea la meta hasta que termine la transacción
        SELECT id_usuario, estado, monto_objetivo, monto_actual
          INTO v_dueno_meta, v_estado_meta, v_objetivo, v_acumulado
        FROM MetasAhorro
        WHERE id_meta = p_id_meta
        FOR UPDATE;

        IF v_dueno_meta IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La meta no existe.';
        END IF;
        IF v_dueno_meta <> p_id_usuario THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50008, MESSAGE_TEXT = 'La meta no pertenece al usuario.';
        END IF;
        IF v_estado_meta <> 'EN_CURSO' THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'Solo se puede aportar a metas que estén en curso.';
        END IF;
        IF v_acumulado + p_monto > v_objetivo THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El aporte supera lo que le falta a la meta.';
        END IF;

        -- Se lee y se bloquea la cuenta
        SELECT id_usuario, estado, tipo_cuenta, moneda, saldo
          INTO v_dueno_cuenta, v_estado_cta, v_tipo_cuenta, v_moneda, v_saldo
        FROM Cuentas
        WHERE id_cuenta = p_id_cuenta
        FOR UPDATE;

        IF v_dueno_cuenta IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La cuenta no existe.';
        END IF;
        IF v_dueno_cuenta <> p_id_usuario THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50008, MESSAGE_TEXT = 'La cuenta no pertenece al usuario.';
        END IF;
        IF v_estado_cta <> 'ACTIVA' THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'La cuenta está cerrada.';
        END IF;
        IF v_tipo_cuenta = 'TARJETA' THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'No se puede aportar a una meta desde una tarjeta.';
        END IF;
        IF v_moneda <> 'CRC' THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'Las metas se manejan en colones: use una cuenta en CRC.';
        END IF;
        IF v_saldo < p_monto THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50007, MESSAGE_TEXT = 'Saldo insuficiente en la cuenta.';
        END IF;

        INSERT INTO AportesMeta (id_meta, id_cuenta, monto)
        VALUES (p_id_meta, p_id_cuenta, p_monto);

        SET p_id_aporte = LAST_INSERT_ID();

        UPDATE Cuentas SET saldo = saldo - p_monto WHERE id_cuenta = p_id_cuenta;
        IF ROW_COUNT() <> 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50009, MESSAGE_TEXT = 'No se pudo actualizar el saldo de la cuenta.';
        END IF;

        UPDATE MetasAhorro SET monto_actual = monto_actual + p_monto WHERE id_meta = p_id_meta;
        IF ROW_COUNT() <> 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50009, MESSAGE_TEXT = 'No se pudo actualizar el avance de la meta.';
        END IF;
    COMMIT;

    -- Resultado: cómo quedó todo después del aporte
    SELECT p_id_aporte AS id_aporte,
           (SELECT saldo FROM Cuentas WHERE id_cuenta = p_id_cuenta) AS saldo_cuenta,
           m.monto_actual,
           m.monto_objetivo - m.monto_actual AS faltante,
           CAST(m.monto_actual * 100.0 / m.monto_objetivo AS DECIMAL(5,1)) AS porcentaje_avance
    FROM MetasAhorro m
    WHERE m.id_meta = p_id_meta;
END$$

DELIMITER ;
