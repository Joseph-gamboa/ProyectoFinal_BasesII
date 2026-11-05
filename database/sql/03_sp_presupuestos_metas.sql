/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   03_sp_presupuestos_metas.sql
   Procedimientos basicos de Presupuestos y MetasAhorro (8 procedimientos).
   Requiere: 01_crear_tablas.sql
   Codigos de error: 50001 duplicado, 50002 no existe,
   50003 valor invalido, 50004 tiene datos relacionados,
   50005 usuario invalido, 50006 cambio no permitido
   ===================================================================== */
USE GravityFinance;
GO

/* ===================== PRESUPUESTOS ===================== */
CREATE OR ALTER PROCEDURE dbo.usp_Presupuestos_Insertar
    @id_usuario     INT,
    @id_categoria   INT,
    @monto_limite   DECIMAL(14,2),
    @mes            TINYINT,
    @anio           SMALLINT,
    @id_presupuesto INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto_limite <= 0
            THROW 50003, N'El monto límite debe ser mayor a cero.', 1;
        IF @mes NOT BETWEEN 1 AND 12
            THROW 50003, N'El mes debe estar entre 1 y 12.', 1;
        IF @anio NOT BETWEEN 2000 AND 2100
            THROW 50003, N'El año debe estar entre 2000 y 2100.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario AND estado = 'ACTIVO')
                THROW 50005, N'El usuario no existe o no está activo.', 1;

            IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE id_categoria = @id_categoria)
                THROW 50002, N'La categoría no existe.', 1;

            IF NOT EXISTS (SELECT 1 FROM dbo.Categorias
                           WHERE id_categoria = @id_categoria AND tipo_categoria = 'GASTO')
                THROW 50003, N'Solo se pueden crear presupuestos para categorías de gasto.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Presupuestos
                       WHERE id_usuario = @id_usuario AND id_categoria = @id_categoria
                         AND mes = @mes AND anio = @anio)
                THROW 50001, N'Ya existe un presupuesto para esa categoría en ese mes.', 1;

            INSERT INTO dbo.Presupuestos (id_usuario, id_categoria, monto_limite, mes, anio)
            VALUES (@id_usuario, @id_categoria, @monto_limite, @mes, @anio);

            SET @id_presupuesto = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Presupuestos_Actualizar
    @id_presupuesto INT,
    @monto_limite   DECIMAL(14,2),
    @mes            TINYINT,
    @anio           SMALLINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto_limite <= 0
            THROW 50003, N'El monto límite debe ser mayor a cero.', 1;
        IF @mes NOT BETWEEN 1 AND 12
            THROW 50003, N'El mes debe estar entre 1 y 12.', 1;
        IF @anio NOT BETWEEN 2000 AND 2100
            THROW 50003, N'El año debe estar entre 2000 y 2100.', 1;

        BEGIN TRANSACTION;
            DECLARE @id_usuario INT, @id_categoria INT;

            SELECT @id_usuario = id_usuario, @id_categoria = id_categoria
            FROM dbo.Presupuestos
            WHERE id_presupuesto = @id_presupuesto;

            IF @id_usuario IS NULL
                THROW 50002, N'El presupuesto no existe.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Presupuestos
                       WHERE id_usuario = @id_usuario AND id_categoria = @id_categoria
                         AND mes = @mes AND anio = @anio
                         AND id_presupuesto <> @id_presupuesto)
                THROW 50001, N'Ya existe otro presupuesto para esa categoría en ese mes.', 1;

            UPDATE dbo.Presupuestos
            SET monto_limite = @monto_limite,
                mes          = @mes,
                anio         = @anio
            WHERE id_presupuesto = @id_presupuesto;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Presupuestos_Eliminar
    @id_presupuesto INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Presupuestos WHERE id_presupuesto = @id_presupuesto)
                THROW 50002, N'El presupuesto no existe.', 1;

            DELETE FROM dbo.Presupuestos WHERE id_presupuesto = @id_presupuesto;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Presupuestos_Consultar
    @id_usuario     INT,
    @id_presupuesto INT = NULL,
    @mes            TINYINT = NULL,
    @anio           SMALLINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT p.id_presupuesto,
               p.id_categoria,
               c.nombre_categoria,
               p.monto_limite,
               p.mes,
               p.anio,
               ISNULL((SELECT SUM(m.monto)
                       FROM dbo.Movimientos m
                       INNER JOIN dbo.Cuentas cu ON cu.id_cuenta = m.id_cuenta
                       WHERE cu.id_usuario = p.id_usuario
                         AND m.id_categoria = p.id_categoria
                         AND m.tipo_movimiento = 'GASTO'
                         AND m.estado = 'ACTIVO'
                         AND MONTH(m.fecha) = p.mes
                         AND YEAR(m.fecha)  = p.anio), 0) AS monto_gastado
        FROM dbo.Presupuestos p
        INNER JOIN dbo.Categorias c ON c.id_categoria = p.id_categoria
        WHERE p.id_usuario = @id_usuario
          AND (@id_presupuesto IS NULL OR p.id_presupuesto = @id_presupuesto)
          AND (@mes  IS NULL OR p.mes  = @mes)
          AND (@anio IS NULL OR p.anio = @anio)
        ORDER BY p.anio DESC, p.mes DESC, c.nombre_categoria;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* =====================================================
   METAS DE AHORRO: el monto ahorrado NO se edita aqui;
   solo cambia con los aportes
   ===================================================== */
CREATE OR ALTER PROCEDURE dbo.usp_MetasAhorro_Insertar
    @id_usuario     INT,
    @nombre_meta    NVARCHAR(80),
    @monto_objetivo DECIMAL(14,2),
    @fecha_limite   DATE = NULL,
    @id_meta        INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto_objetivo <= 0
            THROW 50003, N'El monto objetivo debe ser mayor a cero.', 1;
        IF @fecha_limite IS NOT NULL AND @fecha_limite <= CAST(SYSDATETIME() AS DATE)
            THROW 50003, N'La fecha límite debe ser posterior a hoy.', 1;

        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE id_usuario = @id_usuario AND estado = 'ACTIVO')
                THROW 50005, N'El usuario no existe o no está activo.', 1;

            IF EXISTS (SELECT 1 FROM dbo.MetasAhorro
                       WHERE id_usuario = @id_usuario
                         AND nombre_meta = @nombre_meta
                         AND estado = 'EN_CURSO')
                THROW 50001, N'Ya tiene una meta en curso con ese nombre.', 1;

            INSERT INTO dbo.MetasAhorro (id_usuario, nombre_meta, monto_objetivo, fecha_limite)
            VALUES (@id_usuario, @nombre_meta, @monto_objetivo, @fecha_limite);

            SET @id_meta = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_MetasAhorro_Actualizar
    @id_meta        INT,
    @nombre_meta    NVARCHAR(80),
    @monto_objetivo DECIMAL(14,2),
    @fecha_limite   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto_objetivo <= 0
            THROW 50003, N'El monto objetivo debe ser mayor a cero.', 1;
        IF @fecha_limite IS NOT NULL AND @fecha_limite <= CAST(SYSDATETIME() AS DATE)
            THROW 50003, N'La fecha límite debe ser posterior a hoy.', 1;

        BEGIN TRANSACTION;
            DECLARE @id_usuario INT, @estado VARCHAR(10), @monto_actual DECIMAL(14,2);

            SELECT @id_usuario = id_usuario, @estado = estado, @monto_actual = monto_actual
            FROM dbo.MetasAhorro
            WHERE id_meta = @id_meta;

            IF @id_usuario IS NULL
                THROW 50002, N'La meta no existe.', 1;

            IF @estado <> 'EN_CURSO'
                THROW 50006, N'Solo se pueden modificar metas que estén en curso.', 1;

            IF @monto_objetivo < @monto_actual
                THROW 50003, N'El objetivo no puede ser menor a lo que ya se ha ahorrado.', 1;

            IF EXISTS (SELECT 1 FROM dbo.MetasAhorro
                       WHERE id_usuario = @id_usuario
                         AND nombre_meta = @nombre_meta
                         AND estado = 'EN_CURSO'
                         AND id_meta <> @id_meta)
                THROW 50001, N'Ya tiene otra meta en curso con ese nombre.', 1;

            UPDATE dbo.MetasAhorro
            SET nombre_meta    = @nombre_meta,
                monto_objetivo = @monto_objetivo,
                fecha_limite   = @fecha_limite
            WHERE id_meta = @id_meta;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_MetasAhorro_Eliminar
    @id_meta INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            IF NOT EXISTS (SELECT 1 FROM dbo.MetasAhorro WHERE id_meta = @id_meta)
                THROW 50002, N'La meta no existe.', 1;

            IF EXISTS (SELECT 1 FROM dbo.AportesMeta WHERE id_meta = @id_meta)
                THROW 50004, N'No se puede borrar: la meta ya tiene aportes.', 1;

            DELETE FROM dbo.MetasAhorro WHERE id_meta = @id_meta;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_MetasAhorro_Consultar
    @id_usuario INT,
    @id_meta    INT = NULL,
    @estado     VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT id_meta,
               id_usuario,
               nombre_meta,
               monto_objetivo,
               monto_actual,
               CAST(monto_actual * 100.0 / monto_objetivo AS DECIMAL(5,1)) AS porcentaje_avance,
               fecha_limite,
               estado
        FROM dbo.MetasAhorro
        WHERE id_usuario = @id_usuario
          AND (@id_meta IS NULL OR id_meta = @id_meta)
          AND (@estado  IS NULL OR estado  = @estado)
        ORDER BY estado, fecha_limite, nombre_meta;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
