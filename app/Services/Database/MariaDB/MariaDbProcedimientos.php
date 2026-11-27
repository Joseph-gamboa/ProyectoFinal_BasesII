<?php

namespace App\Services\Database\MariaDB;

use App\Services\Database\Procedimientos;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use PDO;
use PDOException;

class MariaDbProcedimientos implements Procedimientos
{

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

        if (! empty($conjuntos[0])) {
            return $conjuntos[0][0];
        }

        $fila = DB::connection()->selectOne('SELECT ' . self::SALIDA . ' AS ' . $salida);

        return $fila;
    }

    public function conjuntos(string $procedimiento, array $parametros = []): array
    {
        return $this->ejecutarCall($procedimiento, $parametros);
    }

    public function anularMovimiento(int $idMovimiento): void
    {
        $this->ejecutarCall('usp_Movimientos_Anular', ['id_movimiento' => $idMovimiento]);
    }

    public function condicionMesActual(string $columna): string
    {
        return "YEAR({$columna}) = YEAR(CURDATE()) AND MONTH({$columna}) = MONTH(CURDATE())";
    }

    public function mensajeDeError(\Throwable $e): string
    {
        $texto = $e->getPrevious()?->getMessage() ?? $e->getMessage();

        if (preg_match('/SQLSTATE\[45000\]:[^:]*:\s*\d+\s+(.+)$/s', $texto, $m)) {
            return trim($m[1]);
        }

        return 'No se pudo completar la operación. Intente de nuevo.';
    }

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

                if ($st->columnCount() > 0 && $st->getColumnMeta(0) !== false) {
                    $conjuntos[] = $st->fetchAll(PDO::FETCH_OBJ);
                }
            } while ($st->nextRowset());

            $st->closeCursor();

            return $conjuntos;
        } catch (PDOException $e) {

            throw new QueryException(DB::connection()->getName(), $sql, $valores, $e);
        }
    }
}
