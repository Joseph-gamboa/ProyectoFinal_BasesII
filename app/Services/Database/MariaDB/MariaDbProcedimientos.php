<?php

namespace App\Services\Database\MariaDB;

use App\Services\Database\Procedimientos;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use PDO;
use PDOException;

/**
 * Implementación LOCAL (MariaDB), para desarrollar sin SQL Server.
 * Llama a los procedimientos de database/mariadb/, que son el equivalente
 * de los de database/sql/ (SQL Server): mismos nombres, mismas reglas,
 * mismos mensajes de error.
 */
class MariaDbProcedimientos implements Procedimientos
{
    /** Variable de sesión de MariaDB que recibe el parámetro OUT. */
    private const SALIDA = '@gf_salida';

    public function consultar(string $procedimiento, array $parametros = []): array
    {
        return $this->ejecutarCall($procedimiento, $parametros)[0] ?? [];
    }

    public function llamar(string $procedimiento, array $parametros = []): void
    {
        $this->ejecutarCall($procedimiento, $parametros);
    }

    public function registrar(string $procedimiento, array $parametros, string $salida): ?object
    {
        $conjuntos = $this->ejecutarCall($procedimiento, $parametros, true);

        // Si el procedimiento devolvió su propio resultado, esa es la fila.
        if (! empty($conjuntos[0])) {
            return $conjuntos[0][0];
        }

        // Si no, se lee el parámetro de salida (el id nuevo), en la misma conexión.
        $fila = DB::connection()->selectOne('SELECT ' . self::SALIDA . ' AS ' . $salida);

        return $fila;
    }

    public function conjuntos(string $procedimiento, array $parametros = []): array
    {
        return $this->ejecutarCall($procedimiento, $parametros);
    }

    public function anularMovimiento(int $idMovimiento): void
    {
        // MariaDB no tiene triggers INSTEAD OF: la anulación es un procedimiento explícito.
        $this->ejecutarCall('usp_Movimientos_Anular', ['id_movimiento' => $idMovimiento]);
    }

    public function condicionMesActual(string $columna): string
    {
        return "YEAR({$columna}) = YEAR(CURDATE()) AND MONTH({$columna}) = MONTH(CURDATE())";
    }

    public function mensajeDeError(\Throwable $e): string
    {
        $texto = $e->getPrevious()?->getMessage() ?? $e->getMessage();

        // Los procedimientos fallan con SIGNAL SQLSTATE '45000' y un código propio (50001...).
        // PDO lo entrega como: SQLSTATE[45000]: <<Unknown error>>: 50001 Mensaje...
        if (preg_match('/SQLSTATE\[45000\]:[^:]*:\s*\d+\s+(.+)$/s', $texto, $m)) {
            return trim($m[1]);
        }

        return 'No se pudo completar la operación. Intente de nuevo.';
    }

    /**
     * Ejecuta "CALL usp(?, ?, ...)" y recoge todas las tablas de resultados.
     * Se usa PDO directo para poder leer varias tablas (el reporte) y dejar
     * la conexión limpia aunque el procedimiento devuelva más de un resultado.
     *
     * @return array<int, array<int, object>>
     */
    private function ejecutarCall(string $procedimiento, array $parametros, bool $conSalida = false): array
    {
        $marcas = array_fill(0, count($parametros), '?');
        if ($conSalida) {
            $marcas[] = self::SALIDA;
        }

        $sql     = "CALL {$procedimiento}(" . implode(', ', $marcas) . ')';
        $valores = array_values($parametros);
        $pdo     = DB::connection()->getPdo();

        try {
            $st = $pdo->prepare($sql);
            $st->execute($valores);

            $conjuntos = [];
            do {
                // Tras el último SELECT, PDO deja un resultado "fantasma" (el estado del CALL)
                // sin columnas reales: se reconoce porque getColumnMeta() no devuelve nada.
                if ($st->columnCount() > 0 && $st->getColumnMeta(0) !== false) {
                    $conjuntos[] = $st->fetchAll(PDO::FETCH_OBJ);
                }
            } while ($st->nextRowset());

            $st->closeCursor();

            return $conjuntos;
        } catch (PDOException $e) {
            // Se convierte en QueryException para que los controladores lo atrapen igual que antes.
            throw new QueryException(DB::connection()->getName(), $sql, $valores, $e);
        }
    }
}
