<?php

namespace App\Http\Controllers\Modules;

use App\Http\Controllers\Concerns\EjecutaProcedimientos;
use App\Http\Controllers\Controller;
use App\Services\AuditoriaService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

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

        $presupuestos = collect(DB::select(
            'EXEC dbo.usp_Presupuestos_Consultar @id_usuario = ?, @id_presupuesto = NULL, @mes = ?, @anio = ?',
            [Auth::id(), $mes, $anio]
        ));

        $categorias = collect(DB::select(
            'EXEC dbo.usp_Categorias_Consultar @id_categoria = NULL, @tipo_categoria = ?',
            ['GASTO']
        ));

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
            $fila = DB::select(
                'DECLARE @id INT; EXEC dbo.usp_Presupuestos_Insertar @id_usuario = ?, @id_categoria = ?, '
                . '@monto_limite = ?, @mes = ?, @anio = ?, @id_presupuesto = @id OUTPUT; SELECT @id AS id_presupuesto;',
                [Auth::id(), $datos['id_categoria'], $datos['monto_limite'], $datos['mes'], $datos['anio']]
            )[0] ?? null;

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
            DB::statement(
                'EXEC dbo.usp_Presupuestos_Actualizar @id_presupuesto = ?, @monto_limite = ?, @mes = ?, @anio = ?',
                [$id, $datos['monto_limite'], $datos['mes'], $datos['anio']]
            );

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
            DB::statement('EXEC dbo.usp_Presupuestos_Eliminar @id_presupuesto = ?', [$id]);

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
        $presupuesto = collect(DB::select(
            'EXEC dbo.usp_Presupuestos_Consultar @id_usuario = ?, @id_presupuesto = ?, @mes = NULL, @anio = NULL',
            [Auth::id(), $id]
        ))->first();

        abort_if($presupuesto === null, 404);

        return $presupuesto;
    }
}
