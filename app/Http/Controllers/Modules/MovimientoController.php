<?php

namespace App\Http\Controllers\Modules;

use App\Http\Controllers\Concerns\EjecutaProcedimientos;
use App\Http\Controllers\Controller;
use App\Services\AuditoriaService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

abstract class MovimientoController extends Controller
{
    use EjecutaProcedimientos;

    abstract protected function tipo(): string;

    abstract protected function modulo(): string;

    abstract protected function textos(): array;

    abstract protected function reglasPropias(): array;

    abstract protected function detalle(array $datos): string;

    protected function metodoPago(array $datos): ?string
    {
        return null;
    }

    abstract protected function conDetalle(Builder $consulta): Builder;

    public function index(Request $request)
    {
        $idUsuario = Auth::id();

        $filtros = $request->validate([
            'id_cuenta' => ['nullable', 'integer'],
            'desde'     => ['nullable', 'date'],
            'hasta'     => ['nullable', 'date', 'after_or_equal:desde'],
        ]);

        $consulta = DB::table('Movimientos as m')
            ->join('Cuentas as c', 'c.id_cuenta', '=', 'm.id_cuenta')
            ->join('Categorias as cat', 'cat.id_categoria', '=', 'm.id_categoria')
            ->where('c.id_usuario', $idUsuario)
            ->where('m.tipo_movimiento', $this->tipo())
            ->when($filtros['id_cuenta'] ?? null, fn ($q, $v) => $q->where('m.id_cuenta', $v))
            ->when($filtros['desde'] ?? null, fn ($q, $v) => $q->where('m.fecha', '>=', $v))
            ->when($filtros['hasta'] ?? null, fn ($q, $v) => $q->where('m.fecha', '<=', $v))
            ->select(
                'm.id_movimiento', 'm.fecha', 'm.monto', 'm.descripcion', 'm.estado',
                'c.nombre_cuenta', 'c.moneda', 'cat.nombre_categoria'
            );

        $movimientos = $this->conDetalle($consulta)
            ->orderByDesc('m.fecha')
            ->orderByDesc('m.id_movimiento')
            ->paginate(15)
            ->withQueryString();

        $totalesMes = DB::table('Movimientos as m')
            ->join('Cuentas as c', 'c.id_cuenta', '=', 'm.id_cuenta')
            ->where('c.id_usuario', $idUsuario)
            ->where('m.tipo_movimiento', $this->tipo())
            ->where('m.estado', 'ACTIVO')
            ->whereRaw($this->bd()->condicionMesActual('m.fecha'))
            ->groupBy('c.moneda')
            ->selectRaw('c.moneda, SUM(m.monto) AS total')
            ->pluck('total', 'moneda');

        $cuentas = DB::table('Cuentas')
            ->where('id_usuario', $idUsuario)
            ->orderBy('nombre_cuenta')
            ->get(['id_cuenta', 'nombre_cuenta', 'moneda', 'estado']);

        $categorias = collect($this->bd()->consultar('usp_Categorias_Consultar', [
            'id_categoria'   => null,
            'tipo_categoria' => $this->tipo(),
        ]));

        return view('modulos.movimientos', [
            'tipo'        => $this->tipo(),
            'modulo'      => $this->modulo(),
            't'           => $this->textos(),
            'movimientos' => $movimientos,
            'totalesMes'  => $totalesMes,
            'cuentas'     => $cuentas,
            'categorias'  => $categorias,
            'filtros'     => $filtros,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $datos = $request->validate(array_merge([
            'id_cuenta'    => ['required', 'integer'],
            'id_categoria' => ['required', 'integer'],
            'monto'        => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
            'fecha'        => ['nullable', 'date', 'before_or_equal:today'],
            'descripcion'  => ['nullable', 'string', 'max:150'],
        ], $this->reglasPropias()));

        return $this->ejecutar(function () use ($datos) {
            $detalle = trim($this->detalle($datos));

            $fila = $this->bd()->registrar('usp_Movimientos_Registrar', [
                'id_usuario'      => Auth::id(),
                'id_cuenta'       => $datos['id_cuenta'],
                'id_categoria'    => $datos['id_categoria'],
                'tipo_movimiento' => $this->tipo(),
                'monto'           => $datos['monto'],
                'detalle'         => $detalle,
                'metodo_pago'     => $this->metodoPago($datos),
                'fecha'           => $datos['fecha'] ?? null,
                'descripcion'     => $datos['descripcion'] ?? null,
            ], 'id_movimiento');

            AuditoriaService::registrar(
                'CREAR', 'movimientos', $fila->id_movimiento ?? null,
                ucfirst(strtolower($this->tipo())) . " de {$datos['monto']}: {$detalle}",
                null,
                [
                    'id_cuenta'    => (int) $datos['id_cuenta'],
                    'id_categoria' => (int) $datos['id_categoria'],
                    'monto'        => (float) $datos['monto'],
                    'detalle'      => $detalle,
                    'fecha'        => $datos['fecha'] ?? now()->toDateString(),
                ]
            );

            return match ($fila->alerta_presupuesto ?? null) {
                'EXCEDIDO'         => 'Atención: con este gasto superaste el presupuesto de la categoría.',
                'CERCA_DEL_LIMITE' => 'Atención: ya usaste ' . number_format((float) $fila->porcentaje_presupuesto, 1)
                                      . '% del presupuesto de la categoría.',
                default            => null,
            };
        }, $this->textos()['exito_crear']);
    }

    public function destroy(int $id): RedirectResponse
    {
        $mov = DB::table('Movimientos as m')
            ->join('Cuentas as c', 'c.id_cuenta', '=', 'm.id_cuenta')
            ->where('m.id_movimiento', $id)
            ->where('c.id_usuario', Auth::id())
            ->where('m.tipo_movimiento', $this->tipo())
            ->first(['m.id_movimiento', 'm.monto', 'm.estado', 'm.id_cuenta']);

        abort_if($mov === null, 404);

        if ($mov->estado === 'ANULADO') {
            return back()->with('error', 'Este movimiento ya está anulado.');
        }

        return $this->ejecutar(function () use ($id, $mov) {
            // SQL Server: el DELETE lo convierte en anulación el trigger. MariaDB: usp_Movimientos_Anular.
            $this->bd()->anularMovimiento($id);

            AuditoriaService::registrar(
                'ANULAR', 'movimientos', $id,
                ucfirst(strtolower($this->tipo())) . " anulado (monto {$mov->monto})",
                ['estado' => 'ACTIVO', 'monto' => (float) $mov->monto],
                ['estado' => 'ANULADO']
            );
        }, $this->textos()['exito_anular']);
    }
}
