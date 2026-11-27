# Gravity Finance — entorno local con MariaDB

> **Solo para desarrollo local** (por ejemplo, un Mac donde no se puede instalar SQL Server).
> La base de datos **oficial** del proyecto sigue siendo SQL Server (`database/sql/`).
> Nada de lo que hay aquí cambia lo que usan los demás integrantes.

## Cómo funciona

El código de Laravel no sabe qué motor tiene debajo. Todos los controladores llaman a los
procedimientos almacenados a través de una sola interfaz, `App\Services\Database\Procedimientos`,
y el `.env` de cada persona decide cuál implementación se usa:

| `DB_CONNECTION` | Implementación                                    | Quién la usa      |
|-----------------|---------------------------------------------------|-------------------|
| `sqlsrv`        | `Services/Database/SqlServer/SqlServerProcedimientos` | todo el equipo (oficial) |
| `mariadb`       | `Services/Database/MariaDB/MariaDbProcedimientos`     | solo desarrollo local    |

MongoDB (auditoría) es el mismo en los dos casos.

## Instalación en el Mac

```bash
brew install mariadb
brew services start mariadb

# desde la carpeta del proyecto:
bash database/mariadb/instalar.sh          # crea la base GravityFinance con todo
cp .env.mariadb.example .env               # (o copie solo las líneas DB_* a su .env actual)
php artisan key:generate                   # solo si APP_KEY está vacío
php artisan serve
```

- `RECREAR=1 bash database/mariadb/instalar.sh` borra la base y la crea de cero.
- Si usa un usuario distinto de `root` o tiene contraseña:
  `DB_USER=gravity DB_PASS=secreto bash database/mariadb/instalar.sh` (y lo mismo en el `.env`).
- **No** hace falta `php artisan migrate`: las tablas las crea `01_crear_tablas.sql`.

## Qué hay en esta carpeta

Es el mismo contenido que `database/sql/`, traducido, con los **mismos nombres de tablas, columnas y
procedimientos**, el **mismo orden de parámetros** y los **mismos códigos y mensajes de error**
(50001–50010), así que la aplicación muestra los mismos avisos que con SQL Server.

| Archivo | Equivale a |
|---------|-----------|
| `01_crear_tablas.sql` | `01_crear_tablas.sql` (13 tablas + 2 roles + 9 categorías) |
| `02_…` a `04_…` | procedimientos básicos de categorías, cuentas, presupuestos, metas, roles, usuarios |
| `05_…`, `06_…`, `07_…` | transferir, registrar movimiento, aportar a meta |
| `08_sp_reporte_resumen.sql` | reporte mensual (4 conjuntos de resultados) |
| `09_triggers.sql` | los 3 triggers (con las adaptaciones de abajo) |
| `instalar.sh` | ejecuta todo en orden |

## Diferencias que hay que conocer

1. **Anular un movimiento.** SQL Server usa un trigger `INSTEAD OF DELETE`; MariaDB no tiene ese tipo.
   Aquí la anulación es el procedimiento `usp_Movimientos_Anular`, y Laravel lo llama solo cuando el
   motor es MariaDB (`anularMovimiento()`). Un `DELETE` directo sobre `Movimientos` se **rechaza** con el
   error 50011 en lugar de borrar sin devolver el dinero. Para el usuario de la aplicación el resultado es idéntico.
2. **Bitácora:** dos triggers (INSERT y UPDATE) en lugar de uno con tres eventos. El de DELETE no existe
   porque ningún DELETE llega a ejecutarse en ninguno de los dos motores. En `usuario_bd` queda el usuario de MariaDB.
3. **Meta cumplida:** es un trigger `BEFORE UPDATE` (MariaDB no deja que un trigger `AFTER` modifique su propia tabla). Mismo resultado.
4. **Mayúsculas y tildes:** la comparación de textos de MariaDB (`utf8mb4_unicode_ci`) ignora tildes, la de SQL Server
   por defecto no. Ejemplo: en MariaDB «Alimentacion» y «Alimentación» cuentan como duplicado; en SQL Server no.
5. **Parámetros:** MariaDB no tiene parámetros opcionales. Por eso cada llamada desde Laravel envía **todos**
   los parámetros (con `NULL` cuando no aplican).

## Regla para el equipo

Si alguien cambia o agrega un procedimiento en `database/sql/`, hay que reflejarlo aquí (mismo nombre,
mismo orden de parámetros) y agregarlo a la llamada correspondiente. Si no, el entorno de MariaDB se desactualiza
(y solo afecta a quien lo use; SQL Server no se toca).

## Problemas comunes

- `Access denied for user 'root'@'localhost'` al conectar Laravel por TCP: cree un usuario propio
  (`CREATE USER 'gravity'@'127.0.0.1' IDENTIFIED BY '...'; GRANT ALL ON GravityFinance.* TO 'gravity'@'127.0.0.1';`)
  y póngalo en `DB_USERNAME`/`DB_PASSWORD`.
- `could not find driver`: falta la extensión `pdo_mysql` de PHP (viene con PHP de Homebrew; revise `php -m | grep -i mysql`).
- `You do not have the SUPER privilege and binary logging is enabled` al crear `fn_EsUltimoAdministrador`:
  ejecute `SET GLOBAL log_bin_trust_function_creators = 1;` y repita.
