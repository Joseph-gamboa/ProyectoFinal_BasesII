<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use PDO;

class DashboardController extends Controller
{
    public function index()
    {
        $usuario = Auth::id();
        $hoy = Carbon::today();
        $desdeMes = $hoy->copy()->startOfMonth();
        $hastaMes = $desdeMes->copy()->addMonth();
        $inicioGrafico = $desdeMes->copy()->subMonths(5);

        // Reutiliza el reporte que ya funciona y filtra por usuario
        [$balances, $presupuestos, $cuentas, $metasReporte] =
            $this->resumen($usuario, $hoy->month, $hoy->year);

        $resumenCRC = collect($balances)->firstWhere('moneda', 'CRC');

        $ingresosMes = (float) ($resumenCRC->total_ingresos ?? 0);
        $gastosMes = (float) ($resumenCRC->total_gastos ?? 0);

        $balance = (float) collect($cuentas)
            ->where('moneda', 'CRC')
            ->sum('saldo');

        $porCategoria = collect($presupuestos)->map(
            fn ($categoria) => (object) [
                'nombre' => $categoria->nombre_categoria,
                'total' => (float) $categoria->total_gastado,
            ]
        );

        $metas = collect($metasReporte)->map(
            fn ($meta) => (object) [
                'nombre' => $meta->nombre_meta,
                'monto_objetivo' => (float) $meta->monto_objetivo,
                'monto_actual' => (float) $meta->monto_actual,
            ]
        );

        $ahorros = (float) $metas->sum('monto_actual');

        // Movimientos activos en colones del usuario conectado
        $ultimos = collect(DB::select(
            "
            SELECT TOP (5)
                m.tipo_movimiento AS tipo_transaccion,
                m.monto,
                m.fecha,
                cat.nombre_categoria AS categoria,
                cat.nombre_categoria AS descripcion
            FROM dbo.Movimientos AS m
            INNER JOIN dbo.Cuentas AS cu
                ON cu.id_cuenta = m.id_cuenta
            INNER JOIN dbo.Categorias AS cat
                ON cat.id_categoria = m.id_categoria
            WHERE cu.id_usuario = ?
              AND cu.moneda = 'CRC'
              AND m.estado = 'ACTIVO'
              AND m.tipo_movimiento IN ('INGRESO', 'GASTO')
            ORDER BY m.fecha DESC, m.id_movimiento DESC
            ",
            [$usuario]
        ));

        // Totales reales de los últimos seis meses, solo en colones
        $totales = collect(DB::select(
            "
            SELECT
                YEAR(m.fecha) AS anio,
                MONTH(m.fecha) AS mes,
                SUM(
                    CASE WHEN m.tipo_movimiento = 'INGRESO'
                         THEN m.monto ELSE 0 END
                ) AS ingresos,
                SUM(
                    CASE WHEN m.tipo_movimiento = 'GASTO'
                         THEN m.monto ELSE 0 END
                ) AS gastos
            FROM dbo.Movimientos AS m
            INNER JOIN dbo.Cuentas AS cu
                ON cu.id_cuenta = m.id_cuenta
            WHERE cu.id_usuario = ?
              AND cu.moneda = 'CRC'
              AND m.estado = 'ACTIVO'
              AND m.tipo_movimiento IN ('INGRESO', 'GASTO')
              AND m.fecha >= ?
              AND m.fecha < ?
            GROUP BY YEAR(m.fecha), MONTH(m.fecha)
            ",
            [
                $usuario,
                $inicioGrafico->toDateString(),
                $hastaMes->toDateString(),
            ]
        ))->keyBy(
            fn ($fila) => sprintf('%04d-%02d', $fila->anio, $fila->mes)
        );

        $grafico = [
            'etiquetas' => [],
            'ingresos' => [],
            'gastos' => [],
        ];

        for ($i = 0; $i < 6; $i++) {
            $fecha = $inicioGrafico->copy()->addMonths($i);
            $fila = $totales->get($fecha->format('Y-m'));

            $grafico['etiquetas'][] = ucfirst(
                $fecha->locale('es')->translatedFormat('M')
            );
            $grafico['ingresos'][] = (float) ($fila->ingresos ?? 0);
            $grafico['gastos'][] = (float) ($fila->gastos ?? 0);
        }

        return view('dashboard', [
            'balance' => $balance,
            'ingresosMes' => $ingresosMes,
            'gastosMes' => $gastosMes,
            'ahorros' => $ahorros,
            'porCategoria' => $porCategoria,
            'maxCategoria' => (float) ($porCategoria->max('total') ?? 0),
            'ultimos' => $ultimos,
            'metas' => $metas,
            'mesActual' => ucfirst(
                $hoy->copy()->locale('es')->translatedFormat('F Y')
            ),
            'grafico' => $grafico,
        ]);
    }

    private function resumen(int $usuario, int $mes, int $anio): array
    {
        $st = DB::connection()->getPdo()->prepare(
            'EXEC dbo.usp_Reporte_ResumenFinanciero
                @id_usuario = ?, @mes = ?, @anio = ?'
        );

        try {
            $st->execute([$usuario, $mes, $anio]);

            $conjuntos = [];

            do {
                if ($st->columnCount() > 0) {
                    $conjuntos[] = $st->fetchAll(PDO::FETCH_OBJ);
                }
            } while ($st->nextRowset());

            return array_pad($conjuntos, 4, []);
        } finally {
            $st->closeCursor();
        }
    }
}