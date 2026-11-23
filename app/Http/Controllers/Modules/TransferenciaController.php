<?php

namespace App\Http\Controllers\Modules;

use App\Http\Controllers\Concerns\EjecutaProcedimientos;
use App\Http\Controllers\Controller;
use App\Services\AuditoriaService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class TransferenciaController extends Controller
{
    use EjecutaProcedimientos;

    public function index()
    {
        $idUsuario = Auth::id();

        $transferencias = DB::table('Transferencias as t')
            ->join('Cuentas as o', 'o.id_cuenta', '=', 't.id_cuenta_origen')
            ->join('Cuentas as d', 'd.id_cuenta', '=', 't.id_cuenta_destino')
            ->where('o.id_usuario', $idUsuario)
            ->select(
                't.id_transferencia', 't.fecha', 't.monto', 't.descripcion',
                'o.nombre_cuenta as origen', 'd.nombre_cuenta as destino', 'o.moneda'
            )
            ->orderByDesc('t.fecha')
            ->orderByDesc('t.id_transferencia')
            ->paginate(15);

        $cuentas = collect(DB::select(
            'EXEC dbo.usp_Cuentas_Consultar @id_usuario = ?',
            [$idUsuario]
        ))->where('estado', 'ACTIVA')->values();

        return view('modulos.transferencias', compact('transferencias', 'cuentas'));
    }

    public function store(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'id_cuenta_origen'  => ['required', 'integer'],
            'id_cuenta_destino' => ['required', 'integer', 'different:id_cuenta_origen'],
            'monto'             => ['required', 'numeric', 'gt:0', 'max:999999999999.99'],
            'descripcion'       => ['nullable', 'string', 'max:150'],
        ], [
            'id_cuenta_destino.different' => 'La cuenta de origen y la de destino deben ser distintas.',
        ]);

        return $this->ejecutar(function () use ($datos) {
            // El procedimiento valida: cuentas propias y activas, misma moneda, saldo suficiente.
            $fila = DB::selectOne(
                'DECLARE @id INT;
                 EXEC dbo.usp_Transferencias_Registrar
                     @id_usuario = ?, @id_cuenta_origen = ?, @id_cuenta_destino = ?,
                     @monto = ?, @descripcion = ?, @id_transferencia = @id OUTPUT;',
                [
                    Auth::id(),
                    $datos['id_cuenta_origen'],
                    $datos['id_cuenta_destino'],
                    $datos['monto'],
                    $datos['descripcion'] ?? null,
                ]
            );

            AuditoriaService::registrar(
                'CREAR', 'transferencias', $fila->id_transferencia ?? null,
                "Transferencia de {$datos['monto']}",
                null,
                [
                    'id_cuenta_origen'  => (int) $datos['id_cuenta_origen'],
                    'id_cuenta_destino' => (int) $datos['id_cuenta_destino'],
                    'monto'             => (float) $datos['monto'],
                ]
            );
        }, 'Transferencia realizada correctamente.');
    }
}
