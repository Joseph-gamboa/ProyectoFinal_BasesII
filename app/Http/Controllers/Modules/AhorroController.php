<?php

namespace App\Http\Controllers\Modules;

use App\Http\Controllers\Concerns\EjecutaProcedimientos;
use App\Http\Controllers\Controller;
use App\Services\AuditoriaService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class AhorroController extends Controller
{
    use EjecutaProcedimientos;

    public function index()
    {
        $metas = collect(DB::select(
            'EXEC dbo.usp_MetasAhorro_Consultar @id_usuario = ?, @id_meta = NULL, @estado = NULL',
            [Auth::id()]
        ));

        $cuentas = collect(DB::select(
            'EXEC dbo.usp_Cuentas_Consultar @id_usuario = ?',
            [Auth::id()]
        ))->filter(fn ($c) => $c->estado === 'ACTIVA' && $c->moneda === 'CRC' && $c->tipo_cuenta !== 'TARJETA')
          ->values();

        return view('modulos.ahorros', compact('metas', 'cuentas'));
    }

    public function store(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'nombre_meta'    => ['required', 'string', 'max:80'],
            'monto_objetivo' => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
            'fecha_limite'   => ['nullable', 'date', 'after:today'],
        ]);

        return $this->ejecutar(function () use ($datos) {
            $nombre = trim($datos['nombre_meta']);

            $fila = DB::select(
                'DECLARE @id INT; EXEC dbo.usp_MetasAhorro_Insertar @id_usuario = ?, @nombre_meta = ?, '
                . '@monto_objetivo = ?, @fecha_limite = ?, @id_meta = @id OUTPUT; SELECT @id AS id_meta;',
                [Auth::id(), $nombre, $datos['monto_objetivo'], $datos['fecha_limite'] ?? null]
            )[0] ?? null;

            AuditoriaService::registrar(
                'CREAR', 'metas', $fila->id_meta ?? null,
                "Meta «{$nombre}»",
                null,
                [
                    'nombre_meta'    => $nombre,
                    'monto_objetivo' => (float) $datos['monto_objetivo'],
                    'fecha_limite'   => $datos['fecha_limite'] ?? null,
                ]
            );
        }, 'Meta creada correctamente.');
    }

    public function update(Request $request, int $id): RedirectResponse
    {
        $antes = $this->metaDelUsuario($id);

        $datos = $request->validate([
            'nombre_meta'    => ['required', 'string', 'max:80'],
            'monto_objetivo' => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
            'fecha_limite'   => ['nullable', 'date', 'after:today'],
        ]);

        return $this->ejecutar(function () use ($id, $datos, $antes) {
            $nombre = trim($datos['nombre_meta']);

            DB::statement(
                'EXEC dbo.usp_MetasAhorro_Actualizar @id_meta = ?, @nombre_meta = ?, '
                . '@monto_objetivo = ?, @fecha_limite = ?',
                [$id, $nombre, $datos['monto_objetivo'], $datos['fecha_limite'] ?? null]
            );

            AuditoriaService::registrar(
                'EDITAR', 'metas', $id,
                "Meta «{$nombre}»",
                $this->datosMeta($antes),
                [
                    'nombre_meta'    => $nombre,
                    'monto_objetivo' => (float) $datos['monto_objetivo'],
                    'fecha_limite'   => $datos['fecha_limite'] ?? null,
                ]
            );
        }, 'Meta actualizada.');
    }

    public function destroy(int $id): RedirectResponse
    {
        $antes = $this->metaDelUsuario($id);

        return $this->ejecutar(function () use ($id, $antes) {
            DB::statement('EXEC dbo.usp_MetasAhorro_Eliminar @id_meta = ?', [$id]);

            AuditoriaService::registrar(
                'ELIMINAR', 'metas', $id,
                "Meta «{$antes->nombre_meta}»",
                $this->datosMeta($antes),
                null
            );
        }, 'Meta eliminada.');
    }

    public function aportar(Request $request, int $id): RedirectResponse
    {
        $meta = $this->metaDelUsuario($id);

        $datos = $request->validate([
            'id_cuenta' => ['required', 'integer'],
            'monto'     => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
        ]);

        return $this->ejecutar(function () use ($id, $meta, $datos) {
            $fila = DB::selectOne(
                'DECLARE @id INT;
                 EXEC dbo.usp_MetasAhorro_Aportar
                     @id_usuario = ?, @id_meta = ?, @id_cuenta = ?, @monto = ?, @id_aporte = @id OUTPUT;',
                [Auth::id(), $id, $datos['id_cuenta'], $datos['monto']]
            );

            AuditoriaService::registrar(
                'APORTAR', 'metas', $id,
                "Aporte de {$datos['monto']} a «{$meta->nombre_meta}»",
                ['monto_actual' => (float) $meta->monto_actual],
                [
                    'monto_actual' => (float) ($fila->monto_actual ?? 0),
                    'aporte'       => (float) $datos['monto'],
                    'id_cuenta'    => (int) $datos['id_cuenta'],
                ]
            );

            return ($fila->faltante ?? 1) <= 0
                ? '¡Meta cumplida! Alcanzaste el objetivo de «' . $meta->nombre_meta . '».'
                : null;
        }, 'Aporte registrado correctamente.');
    }

    private function metaDelUsuario(int $id): object
    {
        $meta = collect(DB::select(
            'EXEC dbo.usp_MetasAhorro_Consultar @id_usuario = ?, @id_meta = ?, @estado = NULL',
            [Auth::id(), $id]
        ))->first();

        abort_if($meta === null, 404);

        return $meta;
    }

    private function datosMeta(object $m): array
    {
        return [
            'nombre_meta'    => $m->nombre_meta,
            'monto_objetivo' => (float) $m->monto_objetivo,
            'monto_actual'   => (float) $m->monto_actual,
            'fecha_limite'   => $m->fecha_limite,
            'estado'         => $m->estado,
        ];
    }
}
