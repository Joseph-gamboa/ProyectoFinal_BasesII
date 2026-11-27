<?php

namespace App\Http\Controllers\Modules;

use App\Http\Controllers\Controller;
use App\Services\Database\Procedimientos;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
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
            $error = app(Procedimientos::class)->mensajeDeError($e);
        }

        return view('modulos.reportes', compact('mes', 'anio', 'balances', 'presupuestos', 'cuentas', 'metas', 'error'));
    }

    private function resumen(int $mes, int $anio): array
    {
        return app(Procedimientos::class)->conjuntos('usp_Reporte_ResumenFinanciero', [
            'id_usuario' => Auth::id(),
            'mes'        => $mes,
            'anio'       => $anio,
        ]);
    }
}
