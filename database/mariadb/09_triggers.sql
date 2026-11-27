/* =====================================================================
   Gravity Finance - ENTORNO LOCAL (MariaDB)
   09_triggers.sql
   Equivalente de database/sql/09_triggers.sql. EJECUTAR AL FINAL.

   DIFERENCIAS CON SQL SERVER (MariaDB no tiene todo lo mismo):
   1) No existen triggers INSTEAD OF. En SQL Server, un DELETE sobre
      Movimientos se convierte en "anular" gracias al trigger 1. Aqui:
        - la anulacion la hace el procedimiento usp_Movimientos_Anular
          (archivo 06), que Laravel llama en lugar de DELETE;
        - un DELETE directo se RECHAZA con un error (en vez de borrar
          sin devolver el dinero a la cuenta).
   2) Un trigger no puede tener varios eventos: la bitacora son dos
      triggers (INSERT y UPDATE). No hay trigger de DELETE porque
      ningun DELETE llega a ejecutarse (ni en SQL Server, donde el
      INSTEAD OF lo reemplaza, ni aqui, donde se rechaza).
   3) Un trigger AFTER no puede modificar su propia tabla, asi que
      "marcar la meta como cumplida" es un trigger BEFORE UPDATE que
      ajusta la fila antes de guardarla. El resultado es el mismo.
   Codigo de error: 50010 la anulacion dejaria saldo negativo,
                    50011 borrado directo de un movimiento no permitido
   ===================================================================== */
SET NAMES utf8mb4;

DELIMITER $$

/* TRIGGER 1 (sustituto del INSTEAD OF DELETE): no se borran movimientos */
DROP TRIGGER IF EXISTS trg_Movimientos_AnularEnLugarDeBorrar$$
CREATE TRIGGER trg_Movimientos_AnularEnLugarDeBorrar
BEFORE DELETE ON Movimientos
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 50011,
        MESSAGE_TEXT = 'Un movimiento no se borra: use usp_Movimientos_Anular para anularlo y devolver el dinero a la cuenta.';
END$$

/* TRIGGER 2: bitacora de movimientos (INSERT y UPDATE) */
DROP TRIGGER IF EXISTS trg_Movimientos_Bitacora_Insert$$
CREATE TRIGGER trg_Movimientos_Bitacora_Insert
AFTER INSERT ON Movimientos
FOR EACH ROW
BEGIN
    INSERT INTO BitacoraMovimientos (id_movimiento, operacion, monto_anterior, monto_nuevo, usuario_bd)
    VALUES (NEW.id_movimiento, 'INSERT', NULL, NEW.monto, CURRENT_USER());
END$$

DROP TRIGGER IF EXISTS trg_Movimientos_Bitacora_Update$$
CREATE TRIGGER trg_Movimientos_Bitacora_Update
AFTER UPDATE ON Movimientos
FOR EACH ROW
BEGIN
    INSERT INTO BitacoraMovimientos (id_movimiento, operacion, monto_anterior, monto_nuevo, usuario_bd)
    VALUES (NEW.id_movimiento, 'UPDATE', OLD.monto, NEW.monto, CURRENT_USER());
END$$

/* TRIGGER 3: marcar la meta como cumplida */
DROP TRIGGER IF EXISTS trg_MetasAhorro_MarcarCumplida$$
CREATE TRIGGER trg_MetasAhorro_MarcarCumplida
BEFORE UPDATE ON MetasAhorro
FOR EACH ROW
BEGIN
    IF (NEW.monto_actual <> OLD.monto_actual OR NEW.monto_objetivo <> OLD.monto_objetivo)
       AND NEW.estado = 'EN_CURSO'
       AND NEW.monto_actual >= NEW.monto_objetivo THEN
        SET NEW.estado = 'CUMPLIDA';
    END IF;
END$$

DELIMITER ;
