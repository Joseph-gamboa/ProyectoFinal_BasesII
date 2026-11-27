/* =====================================================================
   Gravity Finance - ENTORNO LOCAL (MariaDB)
   05_sp_transferencias_registrar.sql
   Equivalente de database/sql/05_sp_transferencias_registrar.sql.
   PROCEDIMIENTO NO BASICO 1: registrar una transferencia entre cuentas.
   Codigos de error: 50002 no existe, 50003 valor invalido,
   50005 usuario invalido, 50006 cambio no permitido,
   50007 saldo insuficiente, 50008 cuenta ajena, 50009 fallo al actualizar
   ===================================================================== */
SET NAMES utf8mb4;

DELIMITER $$

DROP PROCEDURE IF EXISTS usp_Transferencias_Registrar$$
CREATE PROCEDURE usp_Transferencias_Registrar(
    IN  p_id_usuario        INT,
    IN  p_id_cuenta_origen  INT,
    IN  p_id_cuenta_destino INT,
    IN  p_monto             DECIMAL(14,2),
    IN  p_descripcion       VARCHAR(150),
    OUT p_id_transferencia  INT
)
BEGIN
    DECLARE v_cuentas        INT DEFAULT 0;
    DECLARE v_moneda_origen  CHAR(3);
    DECLARE v_moneda_destino CHAR(3);
    DECLARE v_saldo_origen   DECIMAL(14,2);
    DECLARE v_tipo_origen    VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El monto debe ser mayor a cero.';
    END IF;
    IF p_id_cuenta_origen = p_id_cuenta_destino THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'La cuenta de origen y la de destino deben ser distintas.';
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios
                       WHERE id_usuario = p_id_usuario AND estado = 'ACTIVO') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005, MESSAGE_TEXT = 'El usuario no existe o no está activo.';
        END IF;

        -- Se bloquean las dos cuentas (siempre en el mismo orden, para evitar bloqueos cruzados)
        SELECT COUNT(*) INTO v_cuentas FROM (
            SELECT id_cuenta FROM Cuentas
            WHERE id_cuenta IN (p_id_cuenta_origen, p_id_cuenta_destino)
            ORDER BY id_cuenta
            FOR UPDATE
        ) AS bloqueadas;

        IF v_cuentas <> 2 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'Alguna de las dos cuentas no existe.';
        END IF;

        IF EXISTS (SELECT 1 FROM Cuentas
                   WHERE id_cuenta IN (p_id_cuenta_origen, p_id_cuenta_destino)
                     AND id_usuario <> p_id_usuario) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50008, MESSAGE_TEXT = 'Las dos cuentas deben pertenecer al usuario.';
        END IF;

        IF EXISTS (SELECT 1 FROM Cuentas
                   WHERE id_cuenta IN (p_id_cuenta_origen, p_id_cuenta_destino)
                     AND estado <> 'ACTIVA') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'Una de las cuentas está cerrada.';
        END IF;

        SELECT moneda, saldo, tipo_cuenta INTO v_moneda_origen, v_saldo_origen, v_tipo_origen
        FROM Cuentas WHERE id_cuenta = p_id_cuenta_origen;

        SELECT moneda INTO v_moneda_destino
        FROM Cuentas WHERE id_cuenta = p_id_cuenta_destino;

        IF v_moneda_origen <> v_moneda_destino THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'Las cuentas deben tener la misma moneda; no se hace conversión.';
        END IF;

        -- Las tarjetas pueden quedar en negativo (representan deuda)
        IF v_tipo_origen <> 'TARJETA' AND v_saldo_origen < p_monto THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50007, MESSAGE_TEXT = 'Saldo insuficiente en la cuenta de origen.';
        END IF;

        INSERT INTO Transferencias (id_cuenta_origen, id_cuenta_destino, monto, descripcion)
        VALUES (p_id_cuenta_origen, p_id_cuenta_destino, p_monto, p_descripcion);

        SET p_id_transferencia = LAST_INSERT_ID();

        UPDATE Cuentas SET saldo = saldo - p_monto WHERE id_cuenta = p_id_cuenta_origen;
        IF ROW_COUNT() <> 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50009, MESSAGE_TEXT = 'No se pudo actualizar el saldo de la cuenta de origen.';
        END IF;

        UPDATE Cuentas SET saldo = saldo + p_monto WHERE id_cuenta = p_id_cuenta_destino;
        IF ROW_COUNT() <> 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50009, MESSAGE_TEXT = 'No se pudo actualizar el saldo de la cuenta de destino.';
        END IF;
    COMMIT;

    -- Resultado: los saldos ya actualizados
    SELECT p_id_transferencia AS id_transferencia,
           (SELECT saldo FROM Cuentas WHERE id_cuenta = p_id_cuenta_origen)  AS saldo_origen,
           (SELECT saldo FROM Cuentas WHERE id_cuenta = p_id_cuenta_destino) AS saldo_destino;
END$$

DELIMITER ;
