<?php

namespace App\Services\Database;

/**
 * Contrato para llamar a los procedimientos almacenados de Gravity Finance.
 *
 * Hay una implementación por motor de base de datos:
 *   - SqlServer\SqlServerProcedimientos  (oficial: lo usa el equipo)
 *   - MariaDB\MariaDbProcedimientos      (solo para desarrollo local)
 *
 * Los controladores solo hablan con esta interfaz, así que no saben (ni les
 * importa) qué motor hay debajo. El motor se elige con DB_CONNECTION en el .env
 * (ver AppServiceProvider).
 *
 * REGLA DE LOS PARÁMETROS: cada llamada recibe un arreglo nombre => valor con
 * TODOS los parámetros de entrada del procedimiento, en el mismo orden en que
 * están declarados (NULL cuando no aplican). SQL Server los pasa por nombre;
 * MariaDB, por posición. Los nombres van sin "@" ni "p_".
 */
interface Procedimientos
{
    /** Ejecuta un procedimiento que devuelve filas y entrega la primera tabla de resultados. */
    public function consultar(string $procedimiento, array $parametros = []): array;

    /** Ejecuta un procedimiento que no devuelve nada (actualizar, eliminar). */
    public function llamar(string $procedimiento, array $parametros = []): void;

    /**
     * Ejecuta un procedimiento con un parámetro de salida (normalmente el id
     * nuevo) y devuelve una fila. Si el procedimiento devuelve su propio
     * resultado (movimientos, transferencias, aportes) esa es la fila; si no,
     * es una fila con una sola columna llamada como $salida.
     */
    public function registrar(string $procedimiento, array $parametros, string $salida): ?object;

    /** Ejecuta un procedimiento y devuelve TODAS sus tablas de resultados (el reporte). */
    public function conjuntos(string $procedimiento, array $parametros = []): array;

    /** Anula un movimiento y devuelve el dinero a la cuenta. */
    public function anularMovimiento(int $idMovimiento): void;

    /** Condición SQL "la fecha de $columna cae en el mes actual" con la sintaxis del motor. */
    public function condicionMesActual(string $columna): string;

    /** Texto legible del error que lanzó un procedimiento (el THROW / SIGNAL de la base). */
    public function mensajeDeError(\Throwable $e): string;
}
