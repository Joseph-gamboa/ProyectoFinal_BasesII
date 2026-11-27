<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index()
    {
        $idUsuario = Auth::id();
        $hoy = Carbon::today();
        $inicioMes = $hoy->copy()->startOfMonth();
        $inicioGrafico = $hoy->copy()->subMonths(5)->startOfMonth();

        $movimientos = fn () => DB::table('Movimientos as m')
            ->join('Cuentas as cu', 'cu.id_cuenta', '=', 'm.id_cuenta')
            ->where('cu.id_usuario', $idUsuario)
            ->where('m.estado', 'ACTIVO');

        $balance = (float) DB::table('Cuentas')
            ->where('id_usuario', $idUsuario)
            ->where('moneda', 'CRC')
            ->where('estado', 'ACTIVA')
            ->sum('saldo');

        $balanceUsd = (float) DB::table('Cuentas')
            ->where('id_usuario', $idUsuario)
            ->where('moneda', 'USD')
            ->where('estado', 'ACTIVA')
            ->sum('saldo');

        $ahorros = (float) DB::table('MetasAhorro')
            ->where('id_usuario', $idUsuario)
            ->where('estado', '<>', 'CANCELADA')
            ->sum('monto_actual');

        $filas = $movimientos()
            ->where('m.fecha', '>=', $inicioGrafico->toDateString())
            ->get([
                'm.fecha',
                'm.tipo_movimiento',
                'm.monto',
                'cu.moneda'
            ]);

        $etiquetas = [];
        $ingresosCRC = [];
        $gastosCRC = [];
        $ingresosUSD = [];
        $gastosUSD = [];

        for ($i = 0; $i < 6; $i++) {
            $mes = $inicioGrafico->copy()->addMonths($i);
            $clave = $mes->format('Y-m');

            $delMes = $filas->filter(
                fn ($f) => substr((string) $f->fecha, 0, 7) === $clave
            );

            $delCRC = $delMes->where('moneda', 'CRC');
            $delUSD = $delMes->where('moneda', 'USD');

            $etiquetas[] = ucfirst(
                $mes->locale('es')->translatedFormat('M')
            );

            $ingresosCRC[] = (float) $delCRC
                ->where('tipo_movimiento', 'INGRESO')->sum('monto');

            $gastosCRC[] = (float) $delCRC
                ->where('tipo_movimiento', 'GASTO')->sum('monto');

            $ingresosUSD[] = (float) $delUSD
                ->where('tipo_movimiento', 'INGRESO')->sum('monto');

            $gastosUSD[] = (float) $delUSD
                ->where('tipo_movimiento', 'GASTO')->sum('monto');
        }

        $movimientosMes = $filas->filter(
            fn ($f) => substr((string) $f->fecha, 0, 7) === $hoy->format('Y-m')
        );

        $mesCRC = $movimientosMes->where('moneda', 'CRC');
        $mesUSD = $movimientosMes->where('moneda', 'USD');

        $ingresosMesCRC = (float) $mesCRC
            ->where('tipo_movimiento', 'INGRESO')->sum('monto');

        $gastosMesCRC = (float) $mesCRC
            ->where('tipo_movimiento', 'GASTO')->sum('monto');

        $ingresosMesUSD = (float) $mesUSD
            ->where('tipo_movimiento', 'INGRESO')->sum('monto');

        $gastosMesUSD = (float) $mesUSD
            ->where('tipo_movimiento', 'GASTO')->sum('monto');

        $porCategoria = $movimientos()
            ->join('Categorias as c', 'c.id_categoria', '=', 'm.id_categoria')
            ->where('m.tipo_movimiento', 'GASTO')
            ->where('m.fecha', '>=', $inicioMes->toDateString())
            ->groupBy('c.nombre_categoria', 'cu.moneda')
            ->selectRaw(
                'c.nombre_categoria as nombre, cu.moneda as moneda, SUM(m.monto) as total'
            )
            ->orderByDesc('total')
            ->get()
            ->map(fn ($f) => (object) [
                'nombre' => $f->nombre,
                'moneda' => $f->moneda,
                'total' => (float) $f->total,
            ]);

        $maxCategoriaPorMoneda = [
            'CRC' => (float) ($porCategoria->where('moneda', 'CRC')->max('total') ?? 0),
            'USD' => (float) ($porCategoria->where('moneda', 'USD')->max('total') ?? 0),
        ];

        $ultimos = $movimientos()
            ->join('Categorias as c', 'c.id_categoria', '=', 'm.id_categoria')
            ->leftJoin('Ingresos as i', 'i.id_movimiento', '=', 'm.id_movimiento')
            ->leftJoin('Gastos as g', 'g.id_movimiento', '=', 'm.id_movimiento')
            ->orderByDesc('m.fecha')
            ->orderByDesc('m.id_movimiento')
            ->limit(5)
            ->selectRaw(
                'm.tipo_movimiento, m.monto, m.fecha, cu.moneda,
                 c.nombre_categoria,
                 COALESCE(m.descripcion, g.comercio, i.fuente) as descripcion'
            )
            ->get()
            ->map(fn ($f) => (object) [
                'tipo_transaccion' => $f->tipo_movimiento,
                'monto' => (float) $f->monto,
                'moneda' => $f->moneda,
                'fecha' => Carbon::parse($f->fecha),
                'descripcion' => $f->descripcion,
                'categoria' => $f->nombre_categoria,
            ]);

        $metas = DB::table('MetasAhorro')
            ->where('id_usuario', $idUsuario)
            ->where('estado', 'EN_CURSO')
            ->orderBy('nombre_meta')
            ->limit(4)
            ->get(['nombre_meta', 'monto_objetivo', 'monto_actual'])
            ->map(fn ($f) => (object) [
                'nombre' => $f->nombre_meta,
                'monto_objetivo' => (float) $f->monto_objetivo,
                'monto_actual' => (float) $f->monto_actual,
            ]);

        return view('dashboard', [
            'balance' => $balance,
            'balanceUsd' => $balanceUsd,

            'ingresosMesCRC' => $ingresosMesCRC,
            'gastosMesCRC' => $gastosMesCRC,
            'ingresosMesUSD' => $ingresosMesUSD,
            'gastosMesUSD' => $gastosMesUSD,

            'ahorros' => $ahorros,
            'porCategoria' => $porCategoria,
            'maxCategoriaPorMoneda' => $maxCategoriaPorMoneda,
            'ultimos' => $ultimos,
            'metas' => $metas,

            'mesActual' => ucfirst(
                $hoy->locale('es')->translatedFormat('F Y')
            ),

            'grafico' => [
                'etiquetas' => $etiquetas,
                'ingresosCRC' => $ingresosCRC,
                'gastosCRC' => $gastosCRC,
                'ingresosUSD' => $ingresosUSD,
                'gastosUSD' => $gastosUSD,
            ],
        ]);
    }
}
