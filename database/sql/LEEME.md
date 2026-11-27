# Base de datos de Gravity Finance (SQL Server)

Scripts de la parte SQL del Proyecto Final de IF0010 Bases de Datos II.

## Antes de empezar

Cada integrante necesita, en su propio SQL Server:

1. La base `GravityFinance` creada y el usuario `laravel_app` (paso 6 de la guía de conexiones).
2. El proyecto conectado a SQL Server y a MongoDB (guía de conexiones).

## Cómo ejecutarlos

Abrir cada archivo en SQL Server Management Studio y ejecutarlo con F5,
**en este orden** (de arriba abajo):

| Orden | Archivo | Qué hace |
|-------|---------|----------|
| 1 | `01_crear_tablas.sql` | Crea las 13 tablas y los datos iniciales. **Solo una vez.** |
| 2 | `02_sp_categorias_cuentas.sql` | Procedimientos básicos de Categorías y Cuentas |
| 3 | `03_sp_presupuestos_metas.sql` | Procedimientos básicos de Presupuestos y Metas de ahorro |
| 4 | `04_sp_roles_usuarios.sql` | Procedimientos básicos de Roles, Usuarios y UsuarioRol |
| 5 | `05_sp_transferencias_registrar.sql` | Procedimiento grande 1: registrar una transferencia |
| 6 | `06_sp_movimientos_registrar.sql` | Procedimiento grande 2: registrar un movimiento |
| 7 | `07_sp_metas_aportar.sql` | Procedimiento grande 3: aportar a una meta de ahorro |
| 8 | `08_sp_reporte_resumen.sql` | Procedimiento de reporte mensual |
| 9 | `09_triggers.sql` | Los 3 triggers especiales (después de los procedimientos) |
| 10 | `10_deudas.sql` | Agrega Deudas y PagosDeuda, sus 5 procedimientos y su trigger |
| 11 | `10_indices.sql` | Índices adicionales para las consultas frecuentes de las 15 tablas |

Los archivos de los pasos 2 al 11 se pueden volver a ejecutar sin problema.
El archivo 01 no: si hay que repetirlo, primero se borra y se vuelve a crear la base.

Aunque los dos últimos archivos comienzan con `10_`, ejecutar primero
`10_deudas.sql` y después `10_indices.sql`, siguiendo la tabla.

## Comprobar que quedó bien

```sql
SELECT name FROM sys.tables ORDER BY name;      -- deben salir 15 tablas
SELECT name FROM sys.procedures ORDER BY name;  -- deben salir 37 procedimientos
SELECT name FROM sys.triggers ORDER BY name;    -- deben salir 4 triggers
```

`10_indices.sql` conserva los índices que ya existen con los mismos nombres,
incluido `IX_Movimientos_Cuenta_Fecha` si se creó manualmente.
Su consulta final debe mostrar 6 índices, todos con `deshabilitado = 0`.

## Importante

- No guardar contraseñas en estos archivos. La contraseña de `laravel_app` va solo en el `.env` de cada quien.
- Después de crear los triggers, borrar un movimiento (`DELETE`) ya no lo elimina: lo marca como
  `ANULADO` y devuelve el dinero a la cuenta.
