<?php

namespace App\Http\Controllers\Modules;

use App\Http\Controllers\Concerns\EjecutaProcedimientos;
use App\Http\Controllers\Controller;
use App\Services\AuditoriaService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;

class CategoriaController extends Controller
{
    use EjecutaProcedimientos;

    public function index()
    {
        $categorias = collect($this->bd()->consultar('usp_Categorias_Consultar', [
            'id_categoria'   => null,
            'tipo_categoria' => null,
        ]));

        $esAdmin = $this->esAdmin();

        return view('modulos.categorias', compact('categorias', 'esAdmin'));
    }

    public function store(Request $request): RedirectResponse
    {
        $this->exigirAdmin();

        $datos = $request->validate([
            'nombre_categoria' => ['required', 'string', 'max:50'],
            'tipo_categoria'   => ['required', Rule::in(['INGRESO', 'GASTO'])],
        ]);

        return $this->ejecutar(function () use ($datos) {
            $nombre = trim($datos['nombre_categoria']);

            $fila = $this->bd()->registrar('usp_Categorias_Insertar', [
                'nombre_categoria' => $nombre,
                'tipo_categoria'   => $datos['tipo_categoria'],
            ], 'id_categoria');

            AuditoriaService::registrar(
                'CREAR', 'categorias', $fila->id_categoria ?? null,
                "Categoría «{$nombre}» ({$datos['tipo_categoria']})",
                null,
                ['nombre_categoria' => $nombre, 'tipo_categoria' => $datos['tipo_categoria']]
            );
        }, 'Categoría creada correctamente.');
    }

    public function update(Request $request, int $id): RedirectResponse
    {
        $this->exigirAdmin();
        $antes = $this->categoria($id);

        $datos = $request->validate([
            'nombre_categoria' => ['required', 'string', 'max:50'],
            'tipo_categoria'   => ['required', Rule::in(['INGRESO', 'GASTO'])],
        ]);

        return $this->ejecutar(function () use ($id, $datos, $antes) {
            $nombre = trim($datos['nombre_categoria']);

            $this->bd()->llamar('usp_Categorias_Actualizar', [
                'id_categoria'     => $id,
                'nombre_categoria' => $nombre,
                'tipo_categoria'   => $datos['tipo_categoria'],
            ]);

            AuditoriaService::registrar(
                'EDITAR', 'categorias', $id,
                "Categoría «{$nombre}»",
                ['nombre_categoria' => $antes->nombre_categoria, 'tipo_categoria' => $antes->tipo_categoria],
                ['nombre_categoria' => $nombre, 'tipo_categoria' => $datos['tipo_categoria']]
            );
        }, 'Categoría actualizada.');
    }

    public function destroy(int $id): RedirectResponse
    {
        $this->exigirAdmin();
        $antes = $this->categoria($id);

        return $this->ejecutar(function () use ($id, $antes) {
            $this->bd()->llamar('usp_Categorias_Eliminar', ['id_categoria' => $id]);

            AuditoriaService::registrar(
                'ELIMINAR', 'categorias', $id,
                "Categoría «{$antes->nombre_categoria}»",
                ['nombre_categoria' => $antes->nombre_categoria, 'tipo_categoria' => $antes->tipo_categoria],
                null
            );
        }, 'Categoría eliminada.');
    }

    private function esAdmin(): bool
    {
        return Auth::user()->tieneRol('Administrador');
    }

    private function exigirAdmin(): void
    {
        abort_unless($this->esAdmin(), 403, 'Solo el administrador puede modificar categorías.');
    }

    private function categoria(int $id): object
    {
        $categoria = collect($this->bd()->consultar('usp_Categorias_Consultar', [
            'id_categoria'   => $id,
            'tipo_categoria' => null,
        ]))->first();

        abort_if($categoria === null, 404);

        return $categoria;
    }
}
