<?php

namespace App\Http\Controllers;

use Carbon\Carbon;

class DashboardController extends Controller
{
    public function index()
    {
        // Datos ficticios para visualizar el diseño mientras se desarrolla la base de datos.
        $hoy = Carbon::today();
        $inicio = $hoy->copy()->subMonths(5)->startOfMonth();
        $etiquetas = [];

        for ($i = 0; $i < 6; $i++) {
            $etiquetas[] = ucfirst($inicio->copy()->addMonths($i)->locale('es')->translatedFormat('M'));
        }

        $ingresosMes = 850000;
        $gastosMes = 325000;
        $balance = 2450000;
        $ahorros = 680000;

        $ultimos = collect([
            (object) ['tipo_transaccion' => 'INGRESO', 'monto' => 450000, 'fecha' => $hoy->copy()->subDays(1), 'descripcion' => 'Salario mensual', 'categoria' => 'Trabajo'],
            (object) ['tipo_transaccion' => 'GASTO', 'monto' => 85000, 'fecha' => $hoy->copy()->subDays(2), 'descripcion' => 'Compra de supermercado', 'categoria' => 'Alimentación'],
            (object) ['tipo_transaccion' => 'GASTO', 'monto' => 25000, 'fecha' => $hoy->copy()->subDays(4), 'descripcion' => 'Servicio de internet', 'categoria' => 'Servicios'],
            (object) ['tipo_transaccion' => 'INGRESO', 'monto' => 120000, 'fecha' => $hoy->copy()->subDays(6), 'descripcion' => 'Proyecto freelance', 'categoria' => 'Otros ingresos'],
        ]);

        $porCategoria = collect([
            (object) ['nombre' => 'Alimentación', 'total' => 125000],
            (object) ['nombre' => 'Transporte', 'total' => 80000],
            (object) ['nombre' => 'Servicios', 'total' => 65000],
            (object) ['nombre' => 'Entretenimiento', 'total' => 35000],
        ]);

        $metas = collect([
            (object) ['nombre' => 'Viaje', 'monto_objetivo' => 500000, 'monto_actual' => 350000],
            (object) ['nombre' => 'Fondo de emergencia', 'monto_objetivo' => 1000000, 'monto_actual' => 330000],
        ]);

        return view('dashboard', [
            'balance' => $balance,
            'ingresosMes' => $ingresosMes,
            'gastosMes' => $gastosMes,
            'ahorros' => $ahorros,
            'porCategoria' => $porCategoria,
            'maxCategoria' => (float) ($porCategoria->max('total') ?? 0),
            'ultimos' => $ultimos,
            'metas' => $metas,
            'mesActual' => ucfirst($hoy->locale('es')->translatedFormat('F Y')),
            'grafico' => [
                'etiquetas' => $etiquetas,
                'ingresos' => [520000, 680000, 610000, 790000, 720000, $ingresosMes],
                'gastos' => [310000, 420000, 380000, 460000, 290000, $gastosMes],
            ],
        ]);
    }
}
