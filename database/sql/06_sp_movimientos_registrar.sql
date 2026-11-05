/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   06_sp_movimientos_registrar.sql
   PROCEDIMIENTO NO BASICO 2: registrar un movimiento (ingreso o gasto),
   actualizar el saldo y avisar del estado del presupuesto.
   Requiere: 01_crear_tablas.sql
   Codigos de error: 50002 no existe, 50003 valor invalido,
   50005 usuario invalido, 50006 cambio no permitido,
   50007 saldo insuficiente, 50008 cuenta ajena, 50009 fallo al actualizar
   ===================================================================== */
USE GravityFinance;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Movimientos_Registrar
    @id_usuario      INT,
    @id_cuenta       INT,
    @id_categoria    INT,
    @tipo_movimiento VARCHAR(7),
    @monto           DECIMAL(14,2),
    @detalle         NVARCHAR(80),         -- fuente (ingreso) o comercio (gasto)
    @metodo_pago     VARCHAR(13) = NULL,   -- solo para gastos
    @fecha           DATE = NULL,
    @descripcion     NVARCHAR(150) = NULL,
    @id_movimiento   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET @fecha = ISNULL(@fecha, CAST(SYSDATETIME() AS DATE));

        IF @monto IS NULL OR @monto <= 0
            THROW 50003, N'El monto debe ser mayor a cero.', 1;
        IF @tipo_movimiento NOT IN ('INGRESO','GASTO')
            THROW 50003, N'El tipo de movimiento debe ser INGRESO o GASTO.', 1;
        IF @fecha > CAST(SYSDATETIME() AS DATE)
            THROW 50003, N'La fecha del movimiento no puede ser futura.', 1;
        IF @detalle IS NULL OR LEN(LTRIM(RTRIM(@detalle))) = 0
            THROW 50003, N'Indique la fuente del ingreso o el comercio del gasto.', 1;
        IF @tipo_movimiento = 'GASTO'
           AND (@metodo_pago IS NULL OR @metodo_pago NOT IN ('EFECTIVO','TARJETA','TRANSFERENCIA'))
            THROW 50003, N'Un gasto necesita método de pago: EFECTIVO, TARJETA o TRANSFERENCIA.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios
                           WHERE id_usuario = @id_usuario AND estado = 'ACTIVO')
                THROW 50005, N'El usuario no existe o no está activo.', 1;

            -- Se lee y se bloquea la cuenta hasta que termine la transacción
            DECLARE @dueno INT, @estado_cuenta VARCHAR(10),
                    @tipo_cuenta VARCHAR(10), @saldo DECIMAL(14,2);

            SELECT @dueno = id_usuario, @estado_cuenta = estado,
                   @tipo_cuenta = tipo_cuenta, @saldo = saldo
            FROM dbo.Cuentas WITH (UPDLOCK, ROWLOCK)
            WHERE id_cuenta = @id_cuenta;

            IF @dueno IS NULL
                THROW 50002, N'La cuenta no existe.', 1;
            IF @dueno <> @id_usuario
                THROW 50008, N'La cuenta no pertenece al usuario.', 1;
            IF @estado_cuenta <> 'ACTIVA'
                THROW 50006, N'La cuenta está cerrada.', 1;

            DECLARE @tipo_categoria VARCHAR(7);
            SELECT @tipo_categoria = tipo_categoria
            FROM dbo.Categorias WHERE id_categoria = @id_categoria;

            IF @tipo_categoria IS NULL
                THROW 50002, N'La categoría no existe.', 1;
            IF @tipo_categoria <> @tipo_movimiento
                THROW 50006, N'La categoría no corresponde al tipo de movimiento.', 1;

            -- Las tarjetas pueden quedar en negativo (representan deuda)
            IF @tipo_movimiento = 'GASTO' AND @tipo_cuenta <> 'TARJETA' AND @saldo < @monto
                THROW 50007, N'Saldo insuficiente en la cuenta.', 1;

            INSERT INTO dbo.Movimientos (id_cuenta, id_categoria, tipo_movimiento, monto, fecha, descripcion)
            VALUES (@id_cuenta, @id_categoria, @tipo_movimiento, @monto, @fecha, @descripcion);

            SET @id_movimiento = SCOPE_IDENTITY();

            IF @tipo_movimiento = 'INGRESO'
                INSERT INTO dbo.Ingresos (id_movimiento, fuente)
                VALUES (@id_movimiento, LTRIM(RTRIM(@detalle)));
            ELSE
                INSERT INTO dbo.Gastos (id_movimiento, comercio, metodo_pago)
                VALUES (@id_movimiento, LTRIM(RTRIM(@detalle)), @metodo_pago);

            UPDATE dbo.Cuentas
            SET saldo = CASE WHEN @tipo_movimiento = 'INGRESO' THEN saldo + @monto
                             ELSE saldo - @monto END
            WHERE id_cuenta = @id_cuenta;
            IF @@ROWCOUNT <> 1
                THROW 50009, N'No se pudo actualizar el saldo de la cuenta.', 1;

            -- Aviso de presupuesto (solo para gastos): avisa, no bloquea
            DECLARE @alerta VARCHAR(20) = 'NO_APLICA',
                    @porcentaje DECIMAL(6,1) = NULL,
                    @id_presupuesto INT, @limite DECIMAL(14,2), @gastado DECIMAL(14,2);

            IF @tipo_movimiento = 'GASTO'
            BEGIN
                SELECT @id_presupuesto = id_presupuesto, @limite = monto_limite
                FROM dbo.Presupuestos
                WHERE id_usuario = @id_usuario AND id_categoria = @id_categoria
                  AND mes = MONTH(@fecha) AND anio = YEAR(@fecha);

                IF @id_presupuesto IS NULL
                    SET @alerta = 'SIN_PRESUPUESTO';
                ELSE
                BEGIN
                    SELECT @gastado = SUM(m.monto)
                    FROM dbo.Movimientos m
                    INNER JOIN dbo.Cuentas cu ON cu.id_cuenta = m.id_cuenta
                    WHERE cu.id_usuario = @id_usuario
                      AND m.id_categoria = @id_categoria
                      AND m.tipo_movimiento = 'GASTO'
                      AND m.estado = 'ACTIVO'
                      AND MONTH(m.fecha) = MONTH(@fecha)
                      AND YEAR(m.fecha)  = YEAR(@fecha);

                    SET @porcentaje = @gastado * 100.0 / @limite;
                    SET @alerta = CASE WHEN @gastado > @limite        THEN 'EXCEDIDO'
                                       WHEN @gastado >= @limite * 0.8 THEN 'CERCA_DEL_LIMITE'
                                       ELSE 'OK' END;
                END
            END
        COMMIT TRANSACTION;

        SELECT @id_movimiento AS id_movimiento,
               (SELECT saldo FROM dbo.Cuentas WHERE id_cuenta = @id_cuenta) AS saldo_nuevo,
               @alerta AS alerta_presupuesto,
               @porcentaje AS porcentaje_presupuesto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
