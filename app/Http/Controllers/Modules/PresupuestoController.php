<?php

namespace App\Http\Controllers\Modules;

use App\Http\Controllers\Concerns\EjecutaProcedimientos;
use App\Http\Controllers\Controller;
use App\Services\AuditoriaService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class PresupuestoController extends Controller
{
    use EjecutaProcedimientos;

    public function index(Request $request)
    {
        $filtros = $request->validate([
            'mes'  => ['nullable', 'integer', 'between:1,12'],
            'anio' => ['nullable', 'integer', 'between:2000,2100'],
        ]);

        $mes  = $request->has('mes')  ? ($filtros['mes']  ?? null) : (int) now()->month;
        $anio = $request->has('anio') ? ($filtros['anio'] ?? null) : (int) now()->year;

        $presupuestos = collect($this->bd()->consultar('usp_Presupuestos_Consultar', [
            'id_usuario'     => Auth::id(),
            'id_presupuesto' => null,
            'mes'            => $mes,
            'anio'           => $anio,
        ]));

        $categorias = collect($this->bd()->consultar('usp_Categorias_Consultar', [
            'id_categoria'   => null,
            'tipo_categoria' => 'GASTO',
        ]));

        return view('modulos.presupuestos', compact('presupuestos', 'categorias', 'mes', 'anio'));
    }

    public function store(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'id_categoria' => ['required', 'integer'],
            'monto_limite' => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
            'mes'          => ['required', 'integer', 'between:1,12'],
            'anio'         => ['required', 'integer', 'between:2000,2100'],
        ]);

        return $this->ejecutar(function () use ($datos) {
            $fila = $this->bd()->registrar('usp_Presupuestos_Insertar', [
                'id_usuario'   => Auth::id(),
                'id_categoria' => $datos['id_categoria'],
                'monto_limite' => $datos['monto_limite'],
                'mes'          => $datos['mes'],
                'anio'         => $datos['anio'],
            ], 'id_presupuesto');

            AuditoriaService::registrar(
                'CREAR', 'presupuestos', $fila->id_presupuesto ?? null,
                "Presupuesto {$datos['mes']}/{$datos['anio']}: {$datos['monto_limite']}",
                null,
                [
                    'id_categoria' => (int) $datos['id_categoria'],
                    'monto_limite' => (float) $datos['monto_limite'],
                    'mes'          => (int) $datos['mes'],
                    'anio'         => (int) $datos['anio'],
                ]
            );
        }, 'Presupuesto creado correctamente.');
    }

    public function update(Request $request, int $id): RedirectResponse
    {
        $antes = $this->presupuestoDelUsuario($id);

        $datos = $request->validate([
            'monto_limite' => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
            'mes'          => ['required', 'integer', 'between:1,12'],
            'anio'         => ['required', 'integer', 'between:2000,2100'],
        ]);

        return $this->ejecutar(function () use ($id, $datos, $antes) {
            $this->bd()->llamar('usp_Presupuestos_Actualizar', [
                'id_presupuesto' => $id,
                'monto_limite'   => $datos['monto_limite'],
                'mes'            => $datos['mes'],
                'anio'           => $datos['anio'],
            ]);

            AuditoriaService::registrar(
                'EDITAR', 'presupuestos', $id,
                "Presupuesto de «{$antes->nombre_categoria}»",
                ['monto_limite' => (float) $antes->monto_limite, 'mes' => (int) $antes->mes, 'anio' => (int) $antes->anio],
                ['monto_limite' => (float) $datos['monto_limite'], 'mes' => (int) $datos['mes'], 'anio' => (int) $datos['anio']]
            );
        }, 'Presupuesto actualizado.');
    }

    public function destroy(int $id): RedirectResponse
    {
        $antes = $this->presupuestoDelUsuario($id);

        return $this->ejecutar(function () use ($id, $antes) {
            $this->bd()->llamar('usp_Presupuestos_Eliminar', ['id_presupuesto' => $id]);

            AuditoriaService::registrar(
                'ELIMINAR', 'presupuestos', $id,
                "Presupuesto de «{$antes->nombre_categoria}»",
                ['monto_limite' => (float) $antes->monto_limite, 'mes' => (int) $antes->mes, 'anio' => (int) $antes->anio],
                null
            );
        }, 'Presupuesto eliminado.');
    }

    private function presupuestoDelUsuario(int $id): object
    {
        $presupuesto = collect($this->bd()->consultar('usp_Presupuestos_Consultar', [
            'id_usuario'     => Auth::id(),
            'id_presupuesto' => $id,
            'mes'            => null,
            'anio'           => null,
        ]))->first();

        abort_if($presupuesto === null, 404);

        return $presupuesto;
    }
}
