/* =====================================================================
   Gravity Finance - ENTORNO LOCAL (MariaDB)
   03_sp_presupuestos_metas.sql
   Equivalente de database/sql/03_sp_presupuestos_metas.sql (SQL Server).
   Procedimientos basicos de Presupuestos y MetasAhorro (8 procedimientos).
   Requiere: 01_crear_tablas.sql
   ===================================================================== */
SET NAMES utf8mb4;

DELIMITER $$

/* ===================== PRESUPUESTOS ===================== */
DROP PROCEDURE IF EXISTS usp_Presupuestos_Insertar$$
CREATE PROCEDURE usp_Presupuestos_Insertar(
    IN  p_id_usuario     INT,
    IN  p_id_categoria   INT,
    IN  p_monto_limite   DECIMAL(14,2),
    IN  p_mes            INT,
    IN  p_anio           INT,
    OUT p_id_presupuesto INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto_limite <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El monto límite debe ser mayor a cero.';
    END IF;
    IF p_mes NOT BETWEEN 1 AND 12 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El mes debe estar entre 1 y 12.';
    END IF;
    IF p_anio NOT BETWEEN 2000 AND 2100 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El año debe estar entre 2000 y 2100.';
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE id_usuario = p_id_usuario AND estado = 'ACTIVO') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005, MESSAGE_TEXT = 'El usuario no existe o no está activo.';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM Categorias WHERE id_categoria = p_id_categoria) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La categoría no existe.';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM Categorias
                       WHERE id_categoria = p_id_categoria AND tipo_categoria = 'GASTO') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'Solo se pueden crear presupuestos para categorías de gasto.';
        END IF;

        IF EXISTS (SELECT 1 FROM Presupuestos
                   WHERE id_usuario = p_id_usuario AND id_categoria = p_id_categoria
                     AND mes = p_mes AND anio = p_anio) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya existe un presupuesto para esa categoría en ese mes.';
        END IF;

        INSERT INTO Presupuestos (id_usuario, id_categoria, monto_limite, mes, anio)
        VALUES (p_id_usuario, p_id_categoria, p_monto_limite, p_mes, p_anio);

        SET p_id_presupuesto = LAST_INSERT_ID();
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Presupuestos_Actualizar$$
CREATE PROCEDURE usp_Presupuestos_Actualizar(
    IN p_id_presupuesto INT,
    IN p_monto_limite   DECIMAL(14,2),
    IN p_mes            INT,
    IN p_anio           INT
)
BEGIN
    DECLARE v_id_usuario   INT DEFAULT NULL;
    DECLARE v_id_categoria INT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto_limite <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El monto límite debe ser mayor a cero.';
    END IF;
    IF p_mes NOT BETWEEN 1 AND 12 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El mes debe estar entre 1 y 12.';
    END IF;
    IF p_anio NOT BETWEEN 2000 AND 2100 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El año debe estar entre 2000 y 2100.';
    END IF;

    START TRANSACTION;
        SELECT id_usuario, id_categoria INTO v_id_usuario, v_id_categoria
        FROM Presupuestos
        WHERE id_presupuesto = p_id_presupuesto;

        IF v_id_usuario IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El presupuesto no existe.';
        END IF;

        IF EXISTS (SELECT 1 FROM Presupuestos
                   WHERE id_usuario = v_id_usuario AND id_categoria = v_id_categoria
                     AND mes = p_mes AND anio = p_anio
                     AND id_presupuesto <> p_id_presupuesto) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya existe otro presupuesto para esa categoría en ese mes.';
        END IF;

        UPDATE Presupuestos
        SET monto_limite = p_monto_limite,
            mes          = p_mes,
            anio         = p_anio
        WHERE id_presupuesto = p_id_presupuesto;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Presupuestos_Eliminar$$
CREATE PROCEDURE usp_Presupuestos_Eliminar(
    IN p_id_presupuesto INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Presupuestos WHERE id_presupuesto = p_id_presupuesto) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El presupuesto no existe.';
        END IF;

        DELETE FROM Presupuestos WHERE id_presupuesto = p_id_presupuesto;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Presupuestos_Consultar$$
CREATE PROCEDURE usp_Presupuestos_Consultar(
    IN p_id_usuario     INT,
    IN p_id_presupuesto INT,
    IN p_mes            INT,
    IN p_anio           INT
)
BEGIN
    SELECT p.id_presupuesto,
           p.id_categoria,
           c.nombre_categoria,
           p.monto_limite,
           p.mes,
           p.anio,
           IFNULL((SELECT SUM(m.monto)
                   FROM Movimientos m
                   INNER JOIN Cuentas cu ON cu.id_cuenta = m.id_cuenta
                   WHERE cu.id_usuario = p.id_usuario
                     AND m.id_categoria = p.id_categoria
                     AND m.tipo_movimiento = 'GASTO'
                     AND m.estado = 'ACTIVO'
                     AND MONTH(m.fecha) = p.mes
                     AND YEAR(m.fecha)  = p.anio), 0) AS monto_gastado
    FROM Presupuestos p
    INNER JOIN Categorias c ON c.id_categoria = p.id_categoria
    WHERE p.id_usuario = p_id_usuario
      AND (p_id_presupuesto IS NULL OR p.id_presupuesto = p_id_presupuesto)
      AND (p_mes  IS NULL OR p.mes  = p_mes)
      AND (p_anio IS NULL OR p.anio = p_anio)
    ORDER BY p.anio DESC, p.mes DESC, c.nombre_categoria;
END$$

/* =====================================================
   METAS DE AHORRO: el monto ahorrado NO se edita aqui;
   solo cambia con los aportes
   ===================================================== */
DROP PROCEDURE IF EXISTS usp_MetasAhorro_Insertar$$
CREATE PROCEDURE usp_MetasAhorro_Insertar(
    IN  p_id_usuario     INT,
    IN  p_nombre_meta    VARCHAR(80),
    IN  p_monto_objetivo DECIMAL(14,2),
    IN  p_fecha_limite   DATE,
    OUT p_id_meta        INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto_objetivo <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El monto objetivo debe ser mayor a cero.';
    END IF;
    IF p_fecha_limite IS NOT NULL AND p_fecha_limite <= CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'La fecha límite debe ser posterior a hoy.';
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE id_usuario = p_id_usuario AND estado = 'ACTIVO') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50005, MESSAGE_TEXT = 'El usuario no existe o no está activo.';
        END IF;

        IF EXISTS (SELECT 1 FROM MetasAhorro
                   WHERE id_usuario = p_id_usuario
                     AND nombre_meta = p_nombre_meta
                     AND estado = 'EN_CURSO') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya tiene una meta en curso con ese nombre.';
        END IF;

        INSERT INTO MetasAhorro (id_usuario, nombre_meta, monto_objetivo, fecha_limite)
        VALUES (p_id_usuario, p_nombre_meta, p_monto_objetivo, p_fecha_limite);

        SET p_id_meta = LAST_INSERT_ID();
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_MetasAhorro_Actualizar$$
CREATE PROCEDURE usp_MetasAhorro_Actualizar(
    IN p_id_meta        INT,
    IN p_nombre_meta    VARCHAR(80),
    IN p_monto_objetivo DECIMAL(14,2),
    IN p_fecha_limite   DATE
)
BEGIN
    DECLARE v_id_usuario   INT DEFAULT NULL;
    DECLARE v_estado       VARCHAR(10);
    DECLARE v_monto_actual DECIMAL(14,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_monto_objetivo <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El monto objetivo debe ser mayor a cero.';
    END IF;
    IF p_fecha_limite IS NOT NULL AND p_fecha_limite <= CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'La fecha límite debe ser posterior a hoy.';
    END IF;

    START TRANSACTION;
        SELECT id_usuario, estado, monto_actual INTO v_id_usuario, v_estado, v_monto_actual
        FROM MetasAhorro
        WHERE id_meta = p_id_meta;

        IF v_id_usuario IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La meta no existe.';
        END IF;

        IF v_estado <> 'EN_CURSO' THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'Solo se pueden modificar metas que estén en curso.';
        END IF;

        IF p_monto_objetivo < v_monto_actual THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El objetivo no puede ser menor a lo que ya se ha ahorrado.';
        END IF;

        IF EXISTS (SELECT 1 FROM MetasAhorro
                   WHERE id_usuario = v_id_usuario
                     AND nombre_meta = p_nombre_meta
                     AND estado = 'EN_CURSO'
                     AND id_meta <> p_id_meta) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya tiene otra meta en curso con ese nombre.';
        END IF;

        UPDATE MetasAhorro
        SET nombre_meta    = p_nombre_meta,
            monto_objetivo = p_monto_objetivo,
            fecha_limite   = p_fecha_limite
        WHERE id_meta = p_id_meta;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_MetasAhorro_Eliminar$$
CREATE PROCEDURE usp_MetasAhorro_Eliminar(
    IN p_id_meta INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM MetasAhorro WHERE id_meta = p_id_meta) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'La meta no existe.';
        END IF;

        IF EXISTS (SELECT 1 FROM AportesMeta WHERE id_meta = p_id_meta) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50004, MESSAGE_TEXT = 'No se puede borrar: la meta ya tiene aportes.';
        END IF;

        DELETE FROM MetasAhorro WHERE id_meta = p_id_meta;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_MetasAhorro_Consultar$$
CREATE PROCEDURE usp_MetasAhorro_Consultar(
    IN p_id_usuario INT,
    IN p_id_meta    INT,
    IN p_estado     VARCHAR(10)
)
BEGIN
    SELECT id_meta,
           id_usuario,
           nombre_meta,
           monto_objetivo,
           monto_actual,
           CAST(monto_actual * 100.0 / monto_objetivo AS DECIMAL(5,1)) AS porcentaje_avance,
           fecha_limite,
           estado
    FROM MetasAhorro
    WHERE id_usuario = p_id_usuario
      AND (p_id_meta IS NULL OR id_meta = p_id_meta)
      AND (p_estado  IS NULL OR estado  = p_estado)
    ORDER BY estado, fecha_limite, nombre_meta;
END$$

DELIMITER ;
