<?php

namespace App\Http\Controllers;

use App\Services\AuditoriaService;
use Illuminate\Database\QueryException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Módulo de Cuentas. Toda la lectura y escritura pasa por los
 * procedimientos almacenados de SQL Server (usp_Cuentas_*) y cada
 * acción exitosa queda registrada en la auditoría de MongoDB.
 */
class CuentaController extends Controller
{
    public function index()
    {
        $cuentas = collect(DB::select(
            'EXEC dbo.usp_Cuentas_Consultar @id_usuario = ?',
            [Auth::id()]
        ));

        return view('cuentas.index', compact('cuentas'));
    }

    public function store(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'nombre_cuenta' => ['required', 'string', 'max:60'],
            'tipo_cuenta'   => ['required', Rule::in(['EFECTIVO', 'BANCO', 'TARJETA'])],
            'moneda'        => ['required', Rule::in(['CRC', 'USD'])],
            'saldo_inicial' => ['nullable', 'numeric', 'min:0', 'max:999999999999'],
        ]);

        return $this->ejecutar(function () use ($datos) {
            $nombre = trim($datos['nombre_cuenta']);
            $saldo  = $datos['saldo_inicial'] ?? 0;

            $fila = DB::select(
                'DECLARE @id INT; EXEC dbo.usp_Cuentas_Insertar @id_usuario = ?, @nombre_cuenta = ?, '
                . '@tipo_cuenta = ?, @moneda = ?, @saldo_inicial = ?, @id_cuenta = @id OUTPUT; '
                . 'SELECT @id AS id_cuenta;',
                [Auth::id(), $nombre, $datos['tipo_cuenta'], $datos['moneda'], $saldo]
            )[0] ?? null;

            AuditoriaService::registrar(
                'CREAR', 'cuentas', $fila->id_cuenta ?? null,
                "Cuenta «{$nombre}» ({$datos['tipo_cuenta']}, {$datos['moneda']})",
                null,
                [
                    'nombre_cuenta' => $nombre,
                    'tipo_cuenta'   => $datos['tipo_cuenta'],
                    'moneda'        => $datos['moneda'],
                    'saldo_inicial' => (float) $saldo,
                ]
            );
        }, 'Cuenta creada correctamente.');
    }

    public function update(Request $request, int $id): RedirectResponse
    {
        $cuenta = $this->cuentaDelUsuario($id);

        $datos = $request->validate([
            'nombre_cuenta' => ['required', 'string', 'max:60'],
            'tipo_cuenta'   => ['required', Rule::in(['EFECTIVO', 'BANCO', 'TARJETA'])],
            'moneda'        => ['required', Rule::in(['CRC', 'USD'])],
        ]);

        return $this->ejecutar(function () use ($id, $datos, $cuenta) {
            $nombre = trim($datos['nombre_cuenta']);

            DB::statement(
                'EXEC dbo.usp_Cuentas_Actualizar @id_cuenta = ?, @nombre_cuenta = ?, '
                . '@tipo_cuenta = ?, @moneda = ?, @estado = ?',
                [$id, $nombre, $datos['tipo_cuenta'], $datos['moneda'], $cuenta->estado]
            );

            AuditoriaService::registrar(
                'EDITAR', 'cuentas', $id,
                "Cuenta «{$nombre}»",
                $this->datosCuenta($cuenta),
                [
                    'nombre_cuenta' => $nombre,
                    'tipo_cuenta'   => $datos['tipo_cuenta'],
                    'moneda'        => $datos['moneda'],
                    'estado'        => $cuenta->estado,
                ]
            );
        }, 'Cuenta actualizada.');
    }

    /** Cerrar o reabrir una cuenta (no se borra, para conservar su historial). */
    public function cambiarEstado(Request $request, int $id): RedirectResponse
    {
        $cuenta = $this->cuentaDelUsuario($id);

        $datos = $request->validate([
            'estado' => ['required', Rule::in(['ACTIVA', 'CERRADA'])],
        ]);

        return $this->ejecutar(function () use ($id, $cuenta, $datos) {
            DB::statement(
                'EXEC dbo.usp_Cuentas_Actualizar @id_cuenta = ?, @nombre_cuenta = ?, '
                . '@tipo_cuenta = ?, @moneda = ?, @estado = ?',
                [$id, $cuenta->nombre_cuenta, $cuenta->tipo_cuenta, $cuenta->moneda, $datos['estado']]
            );

            AuditoriaService::registrar(
                $datos['estado'] === 'CERRADA' ? 'CERRAR' : 'REABRIR', 'cuentas', $id,
                "Cuenta «{$cuenta->nombre_cuenta}»",
                ['estado' => $cuenta->estado],
                ['estado' => $datos['estado']]
            );
        }, $datos['estado'] === 'CERRADA' ? 'Cuenta cerrada.' : 'Cuenta reabierta.');
    }

    public function destroy(int $id): RedirectResponse
    {
        $cuenta = $this->cuentaDelUsuario($id);

        return $this->ejecutar(function () use ($id, $cuenta) {
            DB::statement('EXEC dbo.usp_Cuentas_Eliminar @id_cuenta = ?', [$id]);

            AuditoriaService::registrar(
                'ELIMINAR', 'cuentas', $id,
                "Cuenta «{$cuenta->nombre_cuenta}»",
                $this->datosCuenta($cuenta),
                null
            );
        }, 'Cuenta eliminada.');
    }

    /** Devuelve la cuenta solo si es del usuario con sesión; si no, error 404. */
    private function cuentaDelUsuario(int $id): object
    {
        $cuenta = collect(DB::select(
            'EXEC dbo.usp_Cuentas_Consultar @id_usuario = ?, @id_cuenta = ?',
            [Auth::id(), $id]
        ))->first();

        abort_if($cuenta === null, 404);

        return $cuenta;
    }

    /** Datos de una cuenta tal como se guardan en la auditoría. */
    private function datosCuenta(object $c): array
    {
        return [
            'nombre_cuenta' => $c->nombre_cuenta,
            'tipo_cuenta'   => $c->tipo_cuenta,
            'moneda'        => $c->moneda,
            'saldo'         => (float) $c->saldo,
            'estado'        => $c->estado,
        ];
    }

    /** Ejecuta la acción y, si un procedimiento la rechaza, muestra su mensaje. */
    private function ejecutar(callable $accion, string $mensajeExito): RedirectResponse
    {
        try {
            $accion();
        } catch (QueryException $e) {
            return back()->withInput()->with('error', $this->mensajeDeSql($e));
        }

        return back()->with('status', $mensajeExito);
    }

    /** Extrae solo el texto que escribió el procedimiento con THROW. */
    private function mensajeDeSql(QueryException $e): string
    {
        $texto = $e->getPrevious()?->getMessage() ?? $e->getMessage();

        if (preg_match('/\[SQL Server\](.+)$/s', $texto, $m)) {
            return trim($m[1]);
        }

        return 'No se pudo completar la operación. Intente de nuevo.';
    }
}