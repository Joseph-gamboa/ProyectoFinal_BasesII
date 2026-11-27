/* =====================================================================
   Gravity Finance - IF0010 Bases de Datos II
   Indices para consultas frecuentes. Ejecutar despues de 01 a 09
   y de 10_deudas.sql.
   Se puede repetir: conserva los indices que ya tienen estos nombres.
   No modifica datos ni procedimientos.
   ===================================================================== */
USE GravityFinance;
GO

SET XACT_ABORT ON;

BEGIN TRY
    IF OBJECT_ID(N'dbo.Deudas', N'U') IS NULL
       OR OBJECT_ID(N'dbo.PagosDeuda', N'U') IS NULL
        THROW 50100, N'Ejecute 10_deudas.sql antes de 10_indices.sql.', 1;

    BEGIN TRANSACTION;

    -- Listados y reporte: movimientos de una cuenta por periodo.
    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.Movimientos')
                     AND name = N'IX_Movimientos_Cuenta_Fecha')
        CREATE NONCLUSTERED INDEX IX_Movimientos_Cuenta_Fecha
        ON dbo.Movimientos (id_cuenta, fecha);

    -- Historial: transferencias de las cuentas del usuario por fecha.
    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.Transferencias')
                     AND name = N'IX_Transferencias_Origen_Fecha')
        CREATE NONCLUSTERED INDEX IX_Transferencias_Origen_Fecha
        ON dbo.Transferencias (id_cuenta_origen, fecha);

    -- Consulta de metas propias y filtro opcional por estado.
    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.MetasAhorro')
                     AND name = N'IX_MetasAhorro_Usuario_Estado')
        CREATE NONCLUSTERED INDEX IX_MetasAhorro_Usuario_Estado
        ON dbo.MetasAhorro (id_usuario, estado);

    -- Reporte mensual: suma de aportes de cada meta en un periodo.
    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.AportesMeta')
                     AND name = N'IX_AportesMeta_Meta_Fecha')
        CREATE NONCLUSTERED INDEX IX_AportesMeta_Meta_Fecha
        ON dbo.AportesMeta (id_meta, fecha);

    -- Listado de deudas del usuario y busquedas de deudas vigentes.
    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.Deudas')
                     AND name = N'IX_Deudas_Usuario_Estado')
        CREATE NONCLUSTERED INDEX IX_Deudas_Usuario_Estado
        ON dbo.Deudas (id_usuario, estado);

    -- Antes de eliminar una deuda, se comprueba si tiene pagos.
    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.PagosDeuda')
                     AND name = N'IX_PagosDeuda_Deuda')
        CREATE NONCLUSTERED INDEX IX_PagosDeuda_Deuda
        ON dbo.PagosDeuda (id_deuda);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Comprobacion de los seis indices adicionales.
SELECT t.name AS tabla, i.name AS indice, i.type_desc AS tipo,
       i.is_disabled AS deshabilitado
FROM sys.tables AS t
INNER JOIN sys.indexes AS i ON i.object_id = t.object_id
WHERE t.schema_id = SCHEMA_ID(N'dbo')
  AND i.name IN (N'IX_Movimientos_Cuenta_Fecha',
                 N'IX_Transferencias_Origen_Fecha',
                 N'IX_MetasAhorro_Usuario_Estado',
                 N'IX_AportesMeta_Meta_Fecha',
                 N'IX_Deudas_Usuario_Estado',
                 N'IX_PagosDeuda_Deuda')
ORDER BY t.name;
GO
