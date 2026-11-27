<?php

namespace App\Services\Database\SqlServer;

use App\Services\Database\Procedimientos;
use Illuminate\Support\Facades\DB;
use PDO;

class SqlServerProcedimientos implements Procedimientos
{
    public function consultar(string $procedimiento, array $parametros = []): array
    {
        [$exec, $valores] = $this->exec($procedimiento, $parametros);

        return DB::select($exec, $valores);
    }

    public function llamar(string $procedimiento, array $parametros = []): void
    {
        [$exec, $valores] = $this->exec($procedimiento, $parametros);

        DB::statement($exec, $valores);
    }

    public function registrar(string $procedimiento, array $parametros, string $salida): ?object
    {
        [$exec, $valores] = $this->exec($procedimiento, $parametros, $salida);

        return DB::selectOne(
            'DECLARE @id INT; ' . $exec . '; SELECT @id AS ' . $salida . ';',
            $valores
        );
    }

    public function conjuntos(string $procedimiento, array $parametros = []): array
    {
        [$exec, $valores] = $this->exec($procedimiento, $parametros);

        $st = DB::connection()->getPdo()->prepare($exec);
        $st->execute($valores);

        $conjuntos = [];
        do {
            $conjuntos[] = $st->columnCount() > 0 ? $st->fetchAll(PDO::FETCH_OBJ) : [];
        } while ($st->nextRowset());

        return $conjuntos;
    }

    public function anularMovimiento(int $idMovimiento): void
    {
        DB::statement('DELETE FROM dbo.Movimientos WHERE id_movimiento = ?', [$idMovimiento]);
    }

    public function condicionMesActual(string $columna): string
    {
        return "YEAR({$columna}) = YEAR(GETDATE()) AND MONTH({$columna}) = MONTH(GETDATE())";
    }

    public function mensajeDeError(\Throwable $e): string
    {
        $texto = $e->getPrevious()?->getMessage() ?? $e->getMessage();

        if (preg_match('/\[SQL Server\](.+)$/s', $texto, $m)) {
            return trim($m[1]);
        }

        return 'No se pudo completar la operación. Intente de nuevo.';
    }

    private function exec(string $procedimiento, array $parametros, ?string $salida = null): array
    {
        $partes  = [];
        $valores = [];

        foreach ($parametros as $nombre => $valor) {
            if ($valor === null) {
                $partes[] = "@{$nombre} = NULL";
            } else {
                $partes[]  = "@{$nombre} = ?";
                $valores[] = $valor;
            }
        }

        if ($salida !== null) {
            $partes[] = "@{$salida} = @id OUTPUT";
        }

        $exec = "EXEC dbo.{$procedimiento}" . ($partes ? ' ' . implode(', ', $partes) : '');

        return [$exec, $valores];
    }
}
