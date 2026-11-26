USE GravityFinance;
GO

-- Tablas utilizadas para listar ingresos y gastos
GRANT SELECT ON OBJECT::dbo.Movimientos TO rol_operaciones;
GRANT SELECT ON OBJECT::dbo.Cuentas TO rol_operaciones;
GRANT SELECT ON OBJECT::dbo.Categorias TO rol_operaciones;
GRANT SELECT ON OBJECT::dbo.Ingresos TO rol_operaciones;
GRANT SELECT ON OBJECT::dbo.Gastos TO rol_operaciones;

-- Tabla utilizada para listar transferencias
GRANT SELECT ON OBJECT::dbo.Transferencias TO rol_operaciones;
GO