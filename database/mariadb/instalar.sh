#!/usr/bin/env bash
# Gravity Finance - instala la base LOCAL en MariaDB (solo desarrollo, NO es la base oficial).
#
# Uso (desde la carpeta del proyecto):
#   bash database/mariadb/instalar.sh                 # usuario root, sin contraseña
#   DB_USER=gravity DB_PASS=secreto bash database/mariadb/instalar.sh
#   RECREAR=1 bash database/mariadb/instalar.sh       # borra la base y la crea de nuevo
#
# Variables opcionales: DB_NAME (GravityFinance), DB_USER (root), DB_PASS, DB_HOST, DB_PORT
set -euo pipefail

cd "$(dirname "$0")"

DB_NAME="${DB_NAME:-GravityFinance}"
DB_USER="${DB_USER:-root}"

CLIENTE=$(command -v mariadb || command -v mysql || true)
if [ -z "$CLIENTE" ]; then
  echo "No encontré el cliente de MariaDB. En Mac: brew install mariadb && brew services start mariadb" >&2
  exit 1
fi

# Sin DB_HOST/DB_PORT se usa la conexión local por defecto (socket), que es lo que funciona con
# el root sin contraseña de una instalación nueva. Solo se fuerza TCP si usted los indica.
ARGS=(-u "$DB_USER" --default-character-set=utf8mb4)
[ -n "${DB_HOST:-}" ] && ARGS+=(-h "$DB_HOST")
[ -n "${DB_PORT:-}" ] && ARGS+=(-P "$DB_PORT")
[ -n "${DB_PASS:-}" ] && ARGS+=(-p"$DB_PASS")

if [ "${RECREAR:-0}" = "1" ]; then
  echo "Borrando la base $DB_NAME ..."
  "$CLIENTE" "${ARGS[@]}" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
fi

"$CLIENTE" "${ARGS[@]}" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

for f in 01_crear_tablas.sql 02_sp_categorias_cuentas.sql 03_sp_presupuestos_metas.sql \
         04_sp_roles_usuarios.sql 05_sp_transferencias_registrar.sql 06_sp_movimientos_registrar.sql \
         07_sp_metas_aportar.sql 08_sp_reporte_resumen.sql 09_triggers.sql 10_deudas.sql; do
  # 01 solo se ejecuta si todavía no hay tablas (los demás se pueden repetir)
  if [ "$f" = "01_crear_tablas.sql" ]; then
    EXISTE=$("$CLIENTE" "${ARGS[@]}" -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='Usuarios'")
    if [ "$EXISTE" != "0" ]; then echo "• $f  (omitido: las tablas ya existen; use RECREAR=1 para empezar de cero)"; continue; fi
  fi
  echo "• $f"
  "$CLIENTE" "${ARGS[@]}" "$DB_NAME" < "$f"
done

echo
"$CLIENTE" "${ARGS[@]}" -N -B "$DB_NAME" -e "
  SELECT CONCAT(COUNT(*), ' tablas')        FROM information_schema.tables   WHERE table_schema='$DB_NAME' AND table_type='BASE TABLE';
  SELECT CONCAT(COUNT(*), ' procedimientos') FROM information_schema.routines WHERE routine_schema='$DB_NAME' AND routine_type='PROCEDURE';
  SELECT CONCAT(COUNT(*), ' triggers')       FROM information_schema.triggers WHERE trigger_schema='$DB_NAME';"
echo "Listo. Ahora configure su .env con las líneas de .env.mariadb.example"
