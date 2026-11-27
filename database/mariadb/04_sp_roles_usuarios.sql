/* =====================================================================
   Gravity Finance - ENTORNO LOCAL (MariaDB)
   04_sp_roles_usuarios.sql
   Equivalente de database/sql/04_sp_roles_usuarios.sql (SQL Server).
   Funcion auxiliar y procedimientos basicos de Roles, Usuarios y
   UsuarioRol (12 procedimientos + 1 funcion).
   Requiere: 01_crear_tablas.sql
   ===================================================================== */
SET NAMES utf8mb4;

DELIMITER $$

/* Funcion auxiliar: ¿es el ultimo administrador activo? */
DROP FUNCTION IF EXISTS fn_EsUltimoAdministrador$$
CREATE FUNCTION fn_EsUltimoAdministrador(p_id_usuario INT)
RETURNS TINYINT(1)
READS SQL DATA
BEGIN
    DECLARE v_resultado TINYINT(1) DEFAULT 0;

    IF EXISTS (SELECT 1
               FROM UsuarioRol ur
               INNER JOIN Roles r    ON r.id_rol = ur.id_rol
               INNER JOIN Usuarios u ON u.id_usuario = ur.id_usuario
               WHERE ur.id_usuario = p_id_usuario
                 AND r.nombre = 'Administrador' AND u.estado = 'ACTIVO')
       AND NOT EXISTS (SELECT 1
               FROM UsuarioRol ur
               INNER JOIN Roles r    ON r.id_rol = ur.id_rol
               INNER JOIN Usuarios u ON u.id_usuario = ur.id_usuario
               WHERE ur.id_usuario <> p_id_usuario
                 AND r.nombre = 'Administrador' AND u.estado = 'ACTIVO') THEN
        SET v_resultado = 1;
    END IF;

    RETURN v_resultado;
END$$

/* ===================== ROLES ===================== */
DROP PROCEDURE IF EXISTS usp_Roles_Insertar$$
CREATE PROCEDURE usp_Roles_Insertar(
    IN  p_nombre      VARCHAR(30),
    IN  p_descripcion VARCHAR(150),
    OUT p_id_rol      INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF CHAR_LENGTH(TRIM(p_nombre)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El nombre del rol no puede estar vacío.';
    END IF;

    START TRANSACTION;
        IF EXISTS (SELECT 1 FROM Roles WHERE nombre = p_nombre) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya existe un rol con ese nombre.';
        END IF;

        INSERT INTO Roles (nombre, descripcion)
        VALUES (TRIM(p_nombre), p_descripcion);

        SET p_id_rol = LAST_INSERT_ID();
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Roles_Actualizar$$
CREATE PROCEDURE usp_Roles_Actualizar(
    IN p_id_rol      INT,
    IN p_nombre      VARCHAR(30),
    IN p_descripcion VARCHAR(150)
)
BEGIN
    DECLARE v_nombre_actual VARCHAR(30) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF CHAR_LENGTH(TRIM(p_nombre)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El nombre del rol no puede estar vacío.';
    END IF;

    START TRANSACTION;
        SELECT nombre INTO v_nombre_actual FROM Roles WHERE id_rol = p_id_rol;

        IF v_nombre_actual IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El rol no existe.';
        END IF;

        IF v_nombre_actual IN ('Administrador','Usuario') AND v_nombre_actual <> p_nombre THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'Los roles Administrador y Usuario no se pueden renombrar.';
        END IF;

        IF EXISTS (SELECT 1 FROM Roles WHERE nombre = p_nombre AND id_rol <> p_id_rol) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya existe otro rol con ese nombre.';
        END IF;

        UPDATE Roles
        SET nombre = TRIM(p_nombre),
            descripcion = p_descripcion
        WHERE id_rol = p_id_rol;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Roles_Eliminar$$
CREATE PROCEDURE usp_Roles_Eliminar(
    IN p_id_rol INT
)
BEGIN
    DECLARE v_nombre_actual VARCHAR(30) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        SELECT nombre INTO v_nombre_actual FROM Roles WHERE id_rol = p_id_rol;

        IF v_nombre_actual IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El rol no existe.';
        END IF;

        IF v_nombre_actual IN ('Administrador','Usuario') THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'Los roles Administrador y Usuario no se pueden borrar.';
        END IF;

        IF EXISTS (SELECT 1 FROM UsuarioRol WHERE id_rol = p_id_rol) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50004, MESSAGE_TEXT = 'No se puede borrar: hay usuarios con ese rol.';
        END IF;

        DELETE FROM Roles WHERE id_rol = p_id_rol;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Roles_Consultar$$
CREATE PROCEDURE usp_Roles_Consultar(
    IN p_id_rol INT
)
BEGIN
    SELECT r.id_rol, r.nombre, r.descripcion,
           (SELECT COUNT(*) FROM UsuarioRol ur WHERE ur.id_rol = r.id_rol) AS cantidad_usuarios
    FROM Roles r
    WHERE (p_id_rol IS NULL OR r.id_rol = p_id_rol)
    ORDER BY r.nombre;
END$$

/* ===================== USUARIOS =====================
   La contrasena llega YA protegida (la protege Laravel con Hash::make).
   La consulta nunca devuelve contrasena_hash. */
DROP PROCEDURE IF EXISTS usp_Usuarios_Insertar$$
CREATE PROCEDURE usp_Usuarios_Insertar(
    IN  p_nombre          VARCHAR(60),
    IN  p_apellido        VARCHAR(60),
    IN  p_correo          VARCHAR(120),
    IN  p_contrasena_hash VARCHAR(255),
    IN  p_estado          VARCHAR(10),     -- NULL = 'ACTIVO'
    OUT p_id_usuario      INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_estado = IFNULL(p_estado, 'ACTIVO');

    IF CHAR_LENGTH(TRIM(p_nombre)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El nombre no puede estar vacío.';
    END IF;
    IF p_correo NOT LIKE '%_@_%._%' OR p_correo LIKE '% %' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El correo no tiene un formato válido.';
    END IF;
    IF CHAR_LENGTH(p_contrasena_hash) < 8 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'La contraseña protegida no es válida.';
    END IF;
    IF p_estado NOT IN ('ACTIVO','INACTIVO') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El estado debe ser ACTIVO o INACTIVO.';
    END IF;

    START TRANSACTION;
        IF EXISTS (SELECT 1 FROM Usuarios WHERE correo = p_correo) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya existe un usuario con ese correo.';
        END IF;

        INSERT INTO Usuarios (nombre, apellido, correo, contrasena_hash, estado)
        VALUES (TRIM(p_nombre), p_apellido, p_correo, p_contrasena_hash, p_estado);

        SET p_id_usuario = LAST_INSERT_ID();
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Usuarios_Actualizar$$
CREATE PROCEDURE usp_Usuarios_Actualizar(
    IN p_id_usuario INT,
    IN p_nombre     VARCHAR(60),
    IN p_apellido   VARCHAR(60),
    IN p_correo     VARCHAR(120),
    IN p_estado     VARCHAR(10)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF CHAR_LENGTH(TRIM(p_nombre)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El nombre no puede estar vacío.';
    END IF;
    IF p_correo NOT LIKE '%_@_%._%' OR p_correo LIKE '% %' THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El correo no tiene un formato válido.';
    END IF;
    IF p_estado NOT IN ('ACTIVO','INACTIVO') THEN
        SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50003, MESSAGE_TEXT = 'El estado debe ser ACTIVO o INACTIVO.';
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE id_usuario = p_id_usuario) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El usuario no existe.';
        END IF;

        IF EXISTS (SELECT 1 FROM Usuarios WHERE correo = p_correo AND id_usuario <> p_id_usuario) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'Ya existe otro usuario con ese correo.';
        END IF;

        IF p_estado = 'INACTIVO' AND fn_EsUltimoAdministrador(p_id_usuario) = 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'No se puede desactivar al último administrador activo.';
        END IF;

        UPDATE Usuarios
        SET nombre   = TRIM(p_nombre),
            apellido = p_apellido,
            correo   = p_correo,
            estado   = p_estado
        WHERE id_usuario = p_id_usuario;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Usuarios_Eliminar$$
CREATE PROCEDURE usp_Usuarios_Eliminar(
    IN p_id_usuario INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE id_usuario = p_id_usuario) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El usuario no existe.';
        END IF;

        IF fn_EsUltimoAdministrador(p_id_usuario) = 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'No se puede borrar al último administrador activo.';
        END IF;

        IF EXISTS (SELECT 1 FROM Cuentas      WHERE id_usuario = p_id_usuario)
        OR EXISTS (SELECT 1 FROM Presupuestos WHERE id_usuario = p_id_usuario)
        OR EXISTS (SELECT 1 FROM MetasAhorro  WHERE id_usuario = p_id_usuario) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50004, MESSAGE_TEXT = 'No se puede borrar: el usuario tiene cuentas, presupuestos o metas. Desactívelo en su lugar.';
        END IF;

        -- Los roles asignados son solo un enlace, se quitan junto con el usuario
        DELETE FROM UsuarioRol WHERE id_usuario = p_id_usuario;
        DELETE FROM Usuarios   WHERE id_usuario = p_id_usuario;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_Usuarios_Consultar$$
CREATE PROCEDURE usp_Usuarios_Consultar(
    IN p_id_usuario INT,
    IN p_estado     VARCHAR(10)
)
BEGIN
    SELECT u.id_usuario, u.nombre, u.apellido, u.correo, u.estado, u.fecha_registro,
           (SELECT GROUP_CONCAT(r.nombre SEPARATOR ', ')
            FROM UsuarioRol ur
            INNER JOIN Roles r ON r.id_rol = ur.id_rol
            WHERE ur.id_usuario = u.id_usuario) AS roles
    FROM Usuarios u
    WHERE (p_id_usuario IS NULL OR u.id_usuario = p_id_usuario)
      AND (p_estado     IS NULL OR u.estado     = p_estado)
    ORDER BY u.nombre, u.apellido;
END$$

/* ===================== USUARIOROL ===================== */
DROP PROCEDURE IF EXISTS usp_UsuarioRol_Insertar$$
CREATE PROCEDURE usp_UsuarioRol_Insertar(
    IN p_id_usuario INT,
    IN p_id_rol     INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE id_usuario = p_id_usuario) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El usuario no existe.';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM Roles WHERE id_rol = p_id_rol) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El rol no existe.';
        END IF;
        IF EXISTS (SELECT 1 FROM UsuarioRol WHERE id_usuario = p_id_usuario AND id_rol = p_id_rol) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'El usuario ya tiene ese rol.';
        END IF;

        INSERT INTO UsuarioRol (id_usuario, id_rol) VALUES (p_id_usuario, p_id_rol);
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_UsuarioRol_Actualizar$$
CREATE PROCEDURE usp_UsuarioRol_Actualizar(
    IN p_id_usuario    INT,
    IN p_id_rol_actual INT,
    IN p_id_rol_nuevo  INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM UsuarioRol
                       WHERE id_usuario = p_id_usuario AND id_rol = p_id_rol_actual) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El usuario no tiene el rol que se quiere cambiar.';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM Roles WHERE id_rol = p_id_rol_nuevo) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El rol nuevo no existe.';
        END IF;
        IF EXISTS (SELECT 1 FROM UsuarioRol
                   WHERE id_usuario = p_id_usuario AND id_rol = p_id_rol_nuevo) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50001, MESSAGE_TEXT = 'El usuario ya tiene el rol nuevo.';
        END IF;

        IF EXISTS (SELECT 1 FROM Roles WHERE id_rol = p_id_rol_actual AND nombre = 'Administrador')
           AND fn_EsUltimoAdministrador(p_id_usuario) = 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'No se le puede quitar el rol al último administrador activo.';
        END IF;

        UPDATE UsuarioRol
        SET id_rol = p_id_rol_nuevo
        WHERE id_usuario = p_id_usuario AND id_rol = p_id_rol_actual;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_UsuarioRol_Eliminar$$
CREATE PROCEDURE usp_UsuarioRol_Eliminar(
    IN p_id_usuario INT,
    IN p_id_rol     INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM UsuarioRol
                       WHERE id_usuario = p_id_usuario AND id_rol = p_id_rol) THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50002, MESSAGE_TEXT = 'El usuario no tiene ese rol.';
        END IF;

        IF (SELECT COUNT(*) FROM UsuarioRol WHERE id_usuario = p_id_usuario) = 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'Un usuario no puede quedarse sin ningún rol.';
        END IF;

        IF EXISTS (SELECT 1 FROM Roles WHERE id_rol = p_id_rol AND nombre = 'Administrador')
           AND fn_EsUltimoAdministrador(p_id_usuario) = 1 THEN
            SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50006, MESSAGE_TEXT = 'No se le puede quitar el rol al último administrador activo.';
        END IF;

        DELETE FROM UsuarioRol WHERE id_usuario = p_id_usuario AND id_rol = p_id_rol;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS usp_UsuarioRol_Consultar$$
CREATE PROCEDURE usp_UsuarioRol_Consultar(
    IN p_id_usuario INT,
    IN p_id_rol     INT
)
BEGIN
    SELECT ur.id_usuario, u.nombre, u.apellido, u.correo,
           ur.id_rol, r.nombre AS nombre_rol
    FROM UsuarioRol ur
    INNER JOIN Usuarios u ON u.id_usuario = ur.id_usuario
    INNER JOIN Roles r    ON r.id_rol     = ur.id_rol
    WHERE (p_id_usuario IS NULL OR ur.id_usuario = p_id_usuario)
      AND (p_id_rol     IS NULL OR ur.id_rol     = p_id_rol)
    ORDER BY u.nombre, r.nombre;
END$$

DELIMITER ;
