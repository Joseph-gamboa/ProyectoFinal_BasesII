/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   10_deudas.sql (MariaDB)
   Equivalente funcional de database/sql/10_deudas.sql.
   Modulo de Deudas: 2 tablas, 5 procedimientos y 1 trigger.
   Requiere: 01_crear_tablas.sql. EJECUTAR DESPUES DE 09_triggers.sql.
   Codigos de error: 50001 duplicado, 50002 no existe, 50003 valor invalido,
   50004 tiene datos relacionados, 50005 usuario invalido,
   50006 cambio no permitido, 50007 saldo insuficiente,
   50008 cuenta o deuda ajena, 50009 fallo al actualizar.

   Nota MariaDB:
   - El trigger se implementa BEFORE UPDATE porque MariaDB no permite
     que un trigger AFTER UPDATE vuelva a actualizar la misma tabla.
   - Los procedimientos usan parametros posicionales en el mismo orden
     que sus equivalentes SQL Server.
   ===================================================================== */

USE GravityFinance;
SET NAMES utf8mb4;

DELIMITER $$

/* ===== TABLAS ===== */
CREATE TABLE IF NOT EXISTS Deudas (
    id_deuda          INT NOT NULL AUTO_INCREMENT,
    id_usuario        INT NOT NULL,
    nombre_deuda      VARCHAR(80) NOT NULL,
    acreedor          VARCHAR(80) NOT NULL,
    monto_total       DECIMAL(14,2) NOT NULL,
    saldo_pendiente   DECIMAL(14,2) NOT NULL,
    fecha_vencimiento DATE NULL,
    estado            VARCHAR(10) NOT NULL DEFAULT 'VIGENTE',
    PRIMARY KEY (id_deuda),
    CONSTRAINT FK_Deudas_Usuarios
        FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario),
    CONSTRAINT CK_Deudas_total CHECK (monto_total > 0),
    CONSTRAINT CK_Deudas_saldo
        CHECK (saldo_pendiente >= 0 AND saldo_pendiente <= monto_total),
    CONSTRAINT CK_Deudas_estado CHECK (estado IN ('VIGENTE','PAGADA')),
    INDEX IX_Deudas_usuario_estado (id_usuario, estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci$$

CREATE TABLE IF NOT EXISTS PagosDeuda (
    id_pago   INT NOT NULL AUTO_INCREMENT,
    id_deuda  INT NOT NULL,
    id_cuenta INT NOT NULL,
    monto     DECIMAL(14,2) NOT NULL,
    fecha     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_pago),
    CONSTRAINT FK_Pagos_Deudas
        FOREIGN KEY (id_deuda) REFERENCES Deudas (id_deuda),
    CONSTRAINT FK_Pagos_Cuentas
        FOREIGN KEY (id_cuenta) REFERENCES Cuentas (id_cuenta),
    CONSTRAINT CK_Pagos_monto CHECK (monto > 0),
    INDEX IX_PagosDeuda_deuda (id_deuda)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci$$

/* ===== INSERTAR ===== */
DROP PROCEDURE IF EXISTS usp_Deudas_Insertar$$
CREATE PROCEDURE usp_Deudas_Insertar(
    IN p_id_usuario INT,
    IN p_nombre_deuda VARCHAR(80),
    IN p_acreedor VARCHAR(80),
    IN p_monto_total DECIMAL(14,2),
    IN p_fecha_vencimiento DATE,
    OUT p_id_deuda INT
)
BEGIN
    DECLARE v_estado_usuario VARCHAR(20) DEFAULT NULL;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_id_deuda = NULL;

    IF p_monto_total IS NULL OR p_monto_total <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003,
            MESSAGE_TEXT = 'El monto de la deuda debe ser mayor a cero.';
    END IF;

    IF p_fecha_vencimiento IS NOT NULL AND p_fecha_vencimiento <= CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003,
            MESSAGE_TEXT = 'La fecha de vencimiento debe ser posterior a hoy.';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_existe
    FROM Usuarios
    WHERE id_usuario = p_id_usuario;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005,
            MESSAGE_TEXT = 'El usuario no existe o no está activo.';
    END IF;

    SELECT estado INTO v_estado_usuario
    FROM Usuarios
    WHERE id_usuario = p_id_usuario
    FOR UPDATE;

    IF v_estado_usuario <> 'ACTIVO' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005,
            MESSAGE_TEXT = 'El usuario no existe o no está activo.';
    END IF;

    SELECT COUNT(*) INTO v_existe
    FROM Deudas
    WHERE id_usuario = p_id_usuario
      AND nombre_deuda = p_nombre_deuda
      AND estado = 'VIGENTE';

    IF v_existe > 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001,
            MESSAGE_TEXT = 'Ya tiene una deuda vigente con ese nombre.';
    END IF;

    INSERT INTO Deudas
        (id_usuario, nombre_deuda, acreedor, monto_total, saldo_pendiente, fecha_vencimiento)
    VALUES
        (p_id_usuario, p_nombre_deuda, p_acreedor, p_monto_total, p_monto_total, p_fecha_vencimiento);

    SET p_id_deuda = LAST_INSERT_ID();

    COMMIT;
END$$

/* ===== ACTUALIZAR (lo ya pagado no se toca) ===== */
DROP PROCEDURE IF EXISTS usp_Deudas_Actualizar$$
CREATE PROCEDURE usp_Deudas_Actualizar(
    IN p_id_deuda INT,
    IN p_nombre_deuda VARCHAR(80),
    IN p_acreedor VARCHAR(80),
    IN p_monto_total DECIMAL(14,2),
    IN p_fecha_vencimiento DATE
)
BEGIN
    DECLARE v_id_usuario INT DEFAULT NULL;
    DECLARE v_estado VARCHAR(10) DEFAULT NULL;
    DECLARE v_total_actual DECIMAL(14,2) DEFAULT NULL;
    DECLARE v_saldo DECIMAL(14,2) DEFAULT NULL;
    DECLARE v_pagado DECIMAL(14,2) DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto_total IS NULL OR p_monto_total <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003,
            MESSAGE_TEXT = 'El monto de la deuda debe ser mayor a cero.';
    END IF;

    IF p_fecha_vencimiento IS NOT NULL AND p_fecha_vencimiento <= CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003,
            MESSAGE_TEXT = 'La fecha de vencimiento debe ser posterior a hoy.';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_existe
    FROM Deudas
    WHERE id_deuda = p_id_deuda;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002,
            MESSAGE_TEXT = 'La deuda no existe.';
    END IF;

    SELECT id_usuario, estado, monto_total, saldo_pendiente
      INTO v_id_usuario, v_estado, v_total_actual, v_saldo
    FROM Deudas
    WHERE id_deuda = p_id_deuda
    FOR UPDATE;

    IF v_estado <> 'VIGENTE' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006,
            MESSAGE_TEXT = 'Solo se pueden modificar deudas vigentes.';
    END IF;

    SET v_pagado = v_total_actual - v_saldo;

    IF p_monto_total < v_pagado THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003,
            MESSAGE_TEXT = 'El monto total no puede ser menor a lo que ya se ha pagado.';
    END IF;

    SELECT COUNT(*) INTO v_existe
    FROM Deudas
    WHERE id_usuario = v_id_usuario
      AND nombre_deuda = p_nombre_deuda
      AND estado = 'VIGENTE'
      AND id_deuda <> p_id_deuda;

    IF v_existe > 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001,
            MESSAGE_TEXT = 'Ya tiene otra deuda vigente con ese nombre.';
    END IF;

    UPDATE Deudas
    SET nombre_deuda = p_nombre_deuda,
        acreedor = p_acreedor,
        monto_total = p_monto_total,
        saldo_pendiente = p_monto_total - v_pagado,
        fecha_vencimiento = p_fecha_vencimiento
    WHERE id_deuda = p_id_deuda;

    COMMIT;
END$$

/* ===== ELIMINAR (solo si no tiene pagos) ===== */
DROP PROCEDURE IF EXISTS usp_Deudas_Eliminar$$
CREATE PROCEDURE usp_Deudas_Eliminar(IN p_id_deuda INT)
BEGIN
    DECLARE v_id_deuda INT DEFAULT NULL;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_id_deuda = NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id_deuda INTO v_id_deuda
    FROM Deudas
    WHERE id_deuda = p_id_deuda
    FOR UPDATE;

    IF v_id_deuda IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002,
            MESSAGE_TEXT = 'La deuda no existe.';
    END IF;

    SELECT COUNT(*) INTO v_existe
    FROM PagosDeuda
    WHERE id_deuda = p_id_deuda;

    IF v_existe > 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50004,
            MESSAGE_TEXT = 'No se puede borrar: la deuda ya tiene pagos.';
    END IF;

    DELETE FROM Deudas WHERE id_deuda = p_id_deuda;

    COMMIT;
END$$

/* ===== CONSULTAR ===== */
DROP PROCEDURE IF EXISTS usp_Deudas_Consultar$$
CREATE PROCEDURE usp_Deudas_Consultar(
    IN p_id_usuario INT,
    IN p_id_deuda INT,
    IN p_estado VARCHAR(10)
)
BEGIN
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
           CASE
               WHEN estado = 'VIGENTE' AND fecha_vencimiento < CURDATE()
               THEN 1 ELSE 0
           END AS vencida
    FROM Deudas
    WHERE id_usuario = p_id_usuario
      AND (p_id_deuda IS NULL OR id_deuda = p_id_deuda)
      AND (p_estado IS NULL OR estado = p_estado)
    ORDER BY CASE WHEN estado = 'VIGENTE' THEN 0 ELSE 1 END,
             CASE WHEN fecha_vencimiento IS NULL THEN 1 ELSE 0 END,
             fecha_vencimiento,
             nombre_deuda;
END$$

/* ===== PAGAR ===== */
DROP PROCEDURE IF EXISTS usp_Deudas_Pagar$$
CREATE PROCEDURE usp_Deudas_Pagar(
    IN p_id_usuario INT,
    IN p_id_deuda INT,
    IN p_id_cuenta INT,
    IN p_monto DECIMAL(14,2),
    OUT p_id_pago INT
)
BEGIN
    DECLARE v_estado_usuario VARCHAR(20) DEFAULT NULL;
    DECLARE v_dueno_deuda INT DEFAULT NULL;
    DECLARE v_estado_deuda VARCHAR(10) DEFAULT NULL;
    DECLARE v_pendiente DECIMAL(14,2) DEFAULT NULL;
    DECLARE v_dueno_cuenta INT DEFAULT NULL;
    DECLARE v_estado_cuenta VARCHAR(10) DEFAULT NULL;
    DECLARE v_tipo_cuenta VARCHAR(20) DEFAULT NULL;
    DECLARE v_moneda CHAR(3) DEFAULT NULL;
    DECLARE v_saldo DECIMAL(14,2) DEFAULT NULL;
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_id_pago = NULL;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003,
            MESSAGE_TEXT = 'El monto del pago debe ser mayor a cero.';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_existe
    FROM Usuarios
    WHERE id_usuario = p_id_usuario;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005,
            MESSAGE_TEXT = 'El usuario no existe o no está activo.';
    END IF;

    SELECT estado INTO v_estado_usuario
    FROM Usuarios
    WHERE id_usuario = p_id_usuario
    FOR UPDATE;

    IF v_estado_usuario <> 'ACTIVO' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005,
            MESSAGE_TEXT = 'El usuario no existe o no está activo.';
    END IF;

    SELECT COUNT(*) INTO v_existe
    FROM Deudas
    WHERE id_deuda = p_id_deuda;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002,
            MESSAGE_TEXT = 'La deuda no existe.';
    END IF;

    SELECT id_usuario, estado, saldo_pendiente
      INTO v_dueno_deuda, v_estado_deuda, v_pendiente
    FROM Deudas
    WHERE id_deuda = p_id_deuda
    FOR UPDATE;

    IF v_dueno_deuda <> p_id_usuario THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50008,
            MESSAGE_TEXT = 'La deuda no pertenece al usuario.';
    END IF;

    IF v_estado_deuda <> 'VIGENTE' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006,
            MESSAGE_TEXT = 'Solo se puede pagar una deuda vigente.';
    END IF;

    IF p_monto > v_pendiente THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003,
            MESSAGE_TEXT = 'El pago supera lo que falta por pagar.';
    END IF;

    SELECT COUNT(*) INTO v_existe
    FROM Cuentas
    WHERE id_cuenta = p_id_cuenta;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002,
            MESSAGE_TEXT = 'La cuenta no existe.';
    END IF;

    SELECT id_usuario, estado, tipo_cuenta, moneda, saldo
      INTO v_dueno_cuenta, v_estado_cuenta, v_tipo_cuenta, v_moneda, v_saldo
    FROM Cuentas
    WHERE id_cuenta = p_id_cuenta
    FOR UPDATE;

    IF v_dueno_cuenta <> p_id_usuario THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50008,
            MESSAGE_TEXT = 'La cuenta no pertenece al usuario.';
    END IF;

    IF v_estado_cuenta <> 'ACTIVA' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006,
            MESSAGE_TEXT = 'La cuenta está cerrada.';
    END IF;

    IF v_tipo_cuenta = 'TARJETA' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006,
            MESSAGE_TEXT = 'No se puede pagar una deuda desde una tarjeta.';
    END IF;

    IF v_moneda <> 'CRC' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006,
            MESSAGE_TEXT = 'Las deudas se manejan en colones: use una cuenta en CRC.';
    END IF;

    IF v_saldo < p_monto THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50007,
            MESSAGE_TEXT = 'Saldo insuficiente en la cuenta.';
    END IF;

    INSERT INTO PagosDeuda (id_deuda, id_cuenta, monto)
    VALUES (p_id_deuda, p_id_cuenta, p_monto);

    SET p_id_pago = LAST_INSERT_ID();

    UPDATE Cuentas
    SET saldo = saldo - p_monto
    WHERE id_cuenta = p_id_cuenta;

    IF ROW_COUNT() <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50009,
            MESSAGE_TEXT = 'No se pudo actualizar el saldo de la cuenta.';
    END IF;

    UPDATE Deudas
    SET saldo_pendiente = saldo_pendiente - p_monto
    WHERE id_deuda = p_id_deuda;

    IF ROW_COUNT() <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50009,
            MESSAGE_TEXT = 'No se pudo actualizar la deuda.';
    END IF;

    COMMIT;
END$$

/* ===== TRIGGER: marcar la deuda como pagada al llegar a cero ===== */
DROP TRIGGER IF EXISTS trg_Deudas_MarcarPagada$$
CREATE TRIGGER trg_Deudas_MarcarPagada
BEFORE UPDATE ON Deudas
FOR EACH ROW
BEGIN
    IF NEW.saldo_pendiente = 0 AND OLD.estado = 'VIGENTE' THEN
        SET NEW.estado = 'PAGADA';
    END IF;
END$$

DELIMITER ;
