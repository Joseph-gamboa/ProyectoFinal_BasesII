<?php

namespace App\Http\Controllers\Modules;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use PDO;
use PDOException;

class ReporteController extends Controller
{
    public function index(Request $request)
    {
        $f = $request->validate([
            'mes'  => ['nullable', 'integer', 'between:1,12'],
            'anio' => ['nullable', 'integer', 'between:2000,2100'],
        ]);

        $mes  = (int) ($f['mes']  ?? now()->month);
        $anio = (int) ($f['anio'] ?? now()->year);

        $balances = $presupuestos = $cuentas = $metas = [];
        $error = null;

        try {
            [$balances, $presupuestos, $cuentas, $metas] = array_pad($this->resumen($mes, $anio), 4, []);
        } catch (PDOException $e) {
            $error = preg_match('/\[SQL Server\](.+)$/s', $e->getMessage(), $m)
                ? trim($m[1])
                : 'No se pudo generar el reporte. Intente de nuevo.';
        }

        return view('modulos.reportes', compact('mes', 'anio', 'balances', 'presupuestos', 'cuentas', 'metas', 'error'));
    }

    private function resumen(int $mes, int $anio): array
    {
        $st = DB::connection()->getPdo()->prepare(
            'EXEC dbo.usp_Reporte_ResumenFinanciero @id_usuario = ?, @mes = ?, @anio = ?'
        );
        $st->execute([Auth::id(), $mes, $anio]);

        $conjuntos = [];
        do {
            $conjuntos[] = $st->columnCount() > 0 ? $st->fetchAll(PDO::FETCH_OBJ) : [];
        } while ($st->nextRowset());

        return $conjuntos;
    }
}
