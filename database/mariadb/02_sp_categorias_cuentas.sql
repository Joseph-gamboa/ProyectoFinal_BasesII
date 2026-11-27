/* =====================================================================
   Gravity Finance - ENTORNO LOCAL (MariaDB)
   02_sp_categorias_cuentas.sql
   Equivalente de database/sql/02_sp_categorias_cuentas.sql (SQL Server).
   Procedimientos basicos de Categorias y Cuentas (8 procedimientos).
   Mismos nombres y mismo ORDEN de parametros que en SQL Server
   (MariaDB no tiene parametros con valor por defecto: Laravel siempre
   los envia todos, usando NULL cuando no aplican).
   Codigos de error propios (MYSQL_ERRNO): 50001 duplicado, 50002 no existe,
   50003 valor invalido, 50004 tiene datos relacionados,
   50005 usuario invalido, 50006 cambio no permitido
   Plantilla: el EXIT HANDLER hace ROLLBACK y relanza el mismo error
   (equivale al BEGIN CATCH ... ROLLBACK; THROW; de SQL Server).
   ===================================================================== */
SET NAMES utf8mb4;

DELIMITER $$

/* ===================== CATEGORIAS ===================== */
DROP PROCEDURE IF EXISTS usp_Categorias_Insertar$$
CREATE PROCEDURE usp_Categorias_Insertar(
    IN  p_nombre_categoria VARCHAR(50),
    IN  p_tipo_categoria   VARCHAR(7),
    OUT p_id_categoria     INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_tipo_categoria NOT IN ('INGRESO','GASTO') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El tipo de categoría debe ser INGRESO o GASTO.';
    END IF;

    START TRANSACTION;
        IF EXISTS (SELECT 1 FROM Categorias WHERE nombre_categoria = p_nombre_categoria) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya existe una categoría con ese nombre.';
        END IF;

        INSERT INTO Categorias (nombre_categoria, tipo_categoria)
        VALUES (p_nombre_categoria, p_tipo_categoria);

        SET p_id_categoria = LAST_INSERT_ID();
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Categorias_Actualizar$$
CREATE PROCEDURE usp_Categorias_Actualizar(
    IN p_id_categoria     INT,
    IN p_nombre_categoria VARCHAR(50),
    IN p_tipo_categoria   VARCHAR(7)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_tipo_categoria NOT IN ('INGRESO','GASTO') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El tipo de categoría debe ser INGRESO o GASTO.';
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Categorias WHERE id_categoria = p_id_categoria) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La categoría no existe.';
        END IF;

        IF EXISTS (SELECT 1 FROM Categorias
                   WHERE nombre_categoria = p_nombre_categoria AND id_categoria <> p_id_categoria) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya existe otra categoría con ese nombre.';
        END IF;

        -- No se puede cambiar de INGRESO a GASTO (o al revés) si ya tiene movimientos
        IF EXISTS (SELECT 1 FROM Categorias
                   WHERE id_categoria = p_id_categoria AND tipo_categoria <> p_tipo_categoria)
           AND EXISTS (SELECT 1 FROM Movimientos WHERE id_categoria = p_id_categoria) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'No se puede cambiar el tipo: la categoría ya tiene movimientos.';
        END IF;

        UPDATE Categorias
        SET nombre_categoria = p_nombre_categoria,
            tipo_categoria   = p_tipo_categoria
        WHERE id_categoria = p_id_categoria;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Categorias_Eliminar$$
CREATE PROCEDURE usp_Categorias_Eliminar(
    IN p_id_categoria INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Categorias WHERE id_categoria = p_id_categoria) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La categoría no existe.';
        END IF;

        IF EXISTS (SELECT 1 FROM Movimientos  WHERE id_categoria = p_id_categoria)
        OR EXISTS (SELECT 1 FROM Presupuestos WHERE id_categoria = p_id_categoria) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50004, MESSAGE_TEXT = 'No se puede borrar: la categoría tiene movimientos o presupuestos.';
        END IF;

        DELETE FROM Categorias WHERE id_categoria = p_id_categoria;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Categorias_Consultar$$
CREATE PROCEDURE usp_Categorias_Consultar(
    IN p_id_categoria   INT,
    IN p_tipo_categoria VARCHAR(7)
)
BEGIN
    SELECT id_categoria, nombre_categoria, tipo_categoria
    FROM Categorias
    WHERE (p_id_categoria   IS NULL OR id_categoria   = p_id_categoria)
      AND (p_tipo_categoria IS NULL OR tipo_categoria = p_tipo_categoria)
    ORDER BY tipo_categoria, nombre_categoria;
END$$

/* =====================================================
   CUENTAS: el saldo NO se edita aqui; solo cambia con
   movimientos, transferencias y aportes a metas
   ===================================================== */
DROP PROCEDURE IF EXISTS usp_Cuentas_Insertar$$
CREATE PROCEDURE usp_Cuentas_Insertar(
    IN  p_id_usuario    INT,
    IN  p_nombre_cuenta VARCHAR(60),
    IN  p_tipo_cuenta   VARCHAR(10),
    IN  p_moneda        CHAR(3),          -- NULL = 'CRC'
    IN  p_saldo_inicial DECIMAL(14,2),    -- NULL = 0
    OUT p_id_cuenta     INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_moneda        = IFNULL(p_moneda, 'CRC');
    SET p_saldo_inicial = IFNULL(p_saldo_inicial, 0);

    IF p_tipo_cuenta NOT IN ('EFECTIVO','BANCO','TARJETA') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El tipo de cuenta debe ser EFECTIVO, BANCO o TARJETA.';
    END IF;
    IF p_moneda NOT IN ('CRC','USD') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'La moneda debe ser CRC o USD.';
    END IF;
    IF p_saldo_inicial < 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El saldo inicial no puede ser negativo.';
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE id_usuario = p_id_usuario AND estado = 'ACTIVO') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005, MESSAGE_TEXT = 'El usuario no existe o no está activo.';
        END IF;

        IF EXISTS (SELECT 1 FROM Cuentas
                   WHERE id_usuario = p_id_usuario AND nombre_cuenta = p_nombre_cuenta) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'El usuario ya tiene una cuenta con ese nombre.';
        END IF;

        INSERT INTO Cuentas (id_usuario, nombre_cuenta, tipo_cuenta, moneda, saldo)
        VALUES (p_id_usuario, p_nombre_cuenta, p_tipo_cuenta, p_moneda, p_saldo_inicial);

        SET p_id_cuenta = LAST_INSERT_ID();
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Cuentas_Actualizar$$
CREATE PROCEDURE usp_Cuentas_Actualizar(
    IN p_id_cuenta     INT,
    IN p_nombre_cuenta VARCHAR(60),
    IN p_tipo_cuenta   VARCHAR(10),
    IN p_moneda        CHAR(3),
    IN p_estado        VARCHAR(10)
)
BEGIN
    DECLARE v_id_usuario INT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_tipo_cuenta NOT IN ('EFECTIVO','BANCO','TARJETA') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El tipo de cuenta debe ser EFECTIVO, BANCO o TARJETA.';
    END IF;
    IF p_moneda NOT IN ('CRC','USD') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'La moneda debe ser CRC o USD.';
    END IF;
    IF p_estado NOT IN ('ACTIVA','CERRADA') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El estado debe ser ACTIVA o CERRADA.';
    END IF;

    START TRANSACTION;
        SELECT id_usuario INTO v_id_usuario FROM Cuentas WHERE id_cuenta = p_id_cuenta;

        IF v_id_usuario IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La cuenta no existe.';
        END IF;

        IF EXISTS (SELECT 1 FROM Cuentas
                   WHERE id_usuario = v_id_usuario
                     AND nombre_cuenta = p_nombre_cuenta
                     AND id_cuenta <> p_id_cuenta) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'El usuario ya tiene otra cuenta con ese nombre.';
        END IF;

        -- No se cambia la moneda si la cuenta ya tiene movimientos
        IF EXISTS (SELECT 1 FROM Cuentas WHERE id_cuenta = p_id_cuenta AND moneda <> p_moneda)
           AND EXISTS (SELECT 1 FROM Movimientos WHERE id_cuenta = p_id_cuenta) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'No se puede cambiar la moneda: la cuenta ya tiene movimientos.';
        END IF;

        UPDATE Cuentas
        SET nombre_cuenta = p_nombre_cuenta,
            tipo_cuenta   = p_tipo_cuenta,
            moneda        = p_moneda,
            estado        = p_estado
        WHERE id_cuenta = p_id_cuenta;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Cuentas_Eliminar$$
CREATE PROCEDURE usp_Cuentas_Eliminar(
    IN p_id_cuenta INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Cuentas WHERE id_cuenta = p_id_cuenta) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La cuenta no existe.';
        END IF;

        IF EXISTS (SELECT 1 FROM Movimientos    WHERE id_cuenta = p_id_cuenta)
        OR EXISTS (SELECT 1 FROM Transferencias WHERE id_cuenta_origen = p_id_cuenta
                                                   OR id_cuenta_destino = p_id_cuenta)
        OR EXISTS (SELECT 1 FROM AportesMeta    WHERE id_cuenta = p_id_cuenta) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50004, MESSAGE_TEXT = 'No se puede borrar: la cuenta tiene movimientos, transferencias o aportes. Ciérrela en su lugar.';
        END IF;

        DELETE FROM Cuentas WHERE id_cuenta = p_id_cuenta;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Cuentas_Consultar$$
CREATE PROCEDURE usp_Cuentas_Consultar(
    IN p_id_usuario INT,
    IN p_id_cuenta  INT
)
BEGIN
    SELECT id_cuenta, id_usuario, nombre_cuenta, tipo_cuenta, moneda, saldo, estado
    FROM Cuentas
    WHERE id_usuario = p_id_usuario
      AND (p_id_cuenta IS NULL OR id_cuenta = p_id_cuenta)
    ORDER BY nombre_cuenta;
END$$

DELIMITER ;
