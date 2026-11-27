<?php

namespace App\Http\Controllers\Modules;

use App\Http\Controllers\Concerns\EjecutaProcedimientos;
use App\Http\Controllers\Controller;
use App\Services\AuditoriaService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class DeudaController extends Controller
{
    use EjecutaProcedimientos;

    public function index()
    {
        $deudas = collect(DB::select(
            'EXEC dbo.usp_Deudas_Consultar @id_usuario = ?, @id_deuda = NULL, @estado = NULL',
            [Auth::id()]
        ));

        $cuentas = collect(DB::select(
            'EXEC dbo.usp_Cuentas_Consultar @id_usuario = ?',
            [Auth::id()]
        ))->filter(fn ($c) => $c->estado === 'ACTIVA' && $c->moneda === 'CRC' && $c->tipo_cuenta !== 'TARJETA')
          ->values();

        return view('modulos.deudas', compact('deudas', 'cuentas'));
    }

    public function store(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'nombre_deuda'      => ['required', 'string', 'max:80'],
            'acreedor'          => ['required', 'string', 'max:80'],
            'monto_total'       => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
            'fecha_vencimiento' => ['nullable', 'date', 'after:today'],
        ]);

        return $this->ejecutar(function () use ($datos) {
            $nombre   = trim($datos['nombre_deuda']);
            $acreedor = trim($datos['acreedor']);

            $fila = DB::select(
                'DECLARE @id INT; EXEC dbo.usp_Deudas_Insertar @id_usuario = ?, @nombre_deuda = ?, '
                . '@acreedor = ?, @monto_total = ?, @fecha_vencimiento = ?, @id_deuda = @id OUTPUT; '
                . 'SELECT @id AS id_deuda;',
                [Auth::id(), $nombre, $acreedor, $datos['monto_total'], $datos['fecha_vencimiento'] ?? null]
            )[0] ?? null;

            AuditoriaService::registrar(
                'CREAR', 'deudas', $fila->id_deuda ?? null,
                "Deuda «{$nombre}» con {$acreedor}",
                null,
                [
                    'nombre_deuda'      => $nombre,
                    'acreedor'          => $acreedor,
                    'monto_total'       => (float) $datos['monto_total'],
                    'fecha_vencimiento' => $datos['fecha_vencimiento'] ?? null,
                ]
            );
        }, 'Deuda registrada correctamente.');
    }

    public function update(Request $request, int $id): RedirectResponse
    {
        $antes = $this->deudaDelUsuario($id);

        $datos = $request->validate([
            'nombre_deuda'      => ['required', 'string', 'max:80'],
            'acreedor'          => ['required', 'string', 'max:80'],
            'monto_total'       => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
            'fecha_vencimiento' => ['nullable', 'date', 'after:today'],
        ]);

        return $this->ejecutar(function () use ($id, $datos, $antes) {
            $nombre   = trim($datos['nombre_deuda']);
            $acreedor = trim($datos['acreedor']);

            DB::statement(
                'EXEC dbo.usp_Deudas_Actualizar @id_deuda = ?, @nombre_deuda = ?, @acreedor = ?, '
                . '@monto_total = ?, @fecha_vencimiento = ?',
                [$id, $nombre, $acreedor, $datos['monto_total'], $datos['fecha_vencimiento'] ?? null]
            );

            AuditoriaService::registrar(
                'EDITAR', 'deudas', $id,
                "Deuda «{$nombre}»",
                $this->datosDeuda($antes),
                [
                    'nombre_deuda'      => $nombre,
                    'acreedor'          => $acreedor,
                    'monto_total'       => (float) $datos['monto_total'],
                    'fecha_vencimiento' => $datos['fecha_vencimiento'] ?? null,
                ]
            );
        }, 'Deuda actualizada.');
    }

    public function destroy(int $id): RedirectResponse
    {
        $antes = $this->deudaDelUsuario($id);

        return $this->ejecutar(function () use ($id, $antes) {
            DB::statement('EXEC dbo.usp_Deudas_Eliminar @id_deuda = ?', [$id]);

            AuditoriaService::registrar(
                'ELIMINAR', 'deudas', $id,
                "Deuda «{$antes->nombre_deuda}»",
                $this->datosDeuda($antes),
                null
            );
        }, 'Deuda eliminada.');
    }

    public function pagar(Request $request, int $id): RedirectResponse
    {
        $deuda = $this->deudaDelUsuario($id);

        $datos = $request->validate([
            'id_cuenta' => ['required', 'integer'],
            'monto'     => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
        ]);

        return $this->ejecutar(function () use ($id, $deuda, $datos) {
            $fila = DB::selectOne(
                'DECLARE @id INT;
                 EXEC dbo.usp_Deudas_Pagar
                     @id_usuario = ?, @id_deuda = ?, @id_cuenta = ?, @monto = ?, @id_pago = @id OUTPUT;',
                [Auth::id(), $id, $datos['id_cuenta'], $datos['monto']]
            );

            AuditoriaService::registrar(
                'PAGAR', 'deudas', $id,
                "Pago de {$datos['monto']} a «{$deuda->nombre_deuda}»",
                ['saldo_pendiente' => (float) $deuda->saldo_pendiente],
                [
                    'saldo_pendiente' => (float) ($fila->saldo_pendiente ?? 0),
                    'pago'            => (float) $datos['monto'],
                    'id_cuenta'       => (int) $datos['id_cuenta'],
                ]
            );

            return ($fila->saldo_pendiente ?? 1) <= 0
                ? '¡Deuda pagada por completo! «' . $deuda->nombre_deuda . '» quedó en cero.'
                : null;
        }, 'Pago registrado correctamente.');
    }

    private function deudaDelUsuario(int $id): object
    {
        $deuda = collect(DB::select(
            'EXEC dbo.usp_Deudas_Consultar @id_usuario = ?, @id_deuda = ?, @estado = NULL',
            [Auth::id(), $id]
        ))->first();

        abort_if($deuda === null, 404);

        return $deuda;
    }

    private function datosDeuda(object $d): array
    {
        return [
            'nombre_deuda'      => $d->nombre_deuda,
            'acreedor'          => $d->acreedor,
            'monto_total'       => (float) $d->monto_total,
            'saldo_pendiente'   => (float) $d->saldo_pendiente,
            'fecha_vencimiento' => $d->fecha_vencimiento,
            'estado'            => $d->estado,
        ];
    }
}