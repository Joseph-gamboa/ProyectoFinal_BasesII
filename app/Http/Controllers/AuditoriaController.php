<?php

namespace App\Http\Controllers;

use App\Models\Auditoria;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;

/**
 * Pantalla de auditoría: lee los registros guardados en MongoDB.
 * El administrador ve todo; un usuario normal solo ve sus propias acciones.
 */
class AuditoriaController extends Controller
{
    private const MODULOS  = ['cuentas', 'movimientos', 'transferencias', 'presupuestos', 'metas', 'categorias', 'usuarios'];
    private const ACCIONES = ['CREAR', 'EDITAR', 'CERRAR', 'REABRIR', 'ELIMINAR', 'ANULAR', 'APORTAR'];
    private const ZONA     = 'America/Costa_Rica';

    public function index(Request $request)
    {
        $usuario = Auth::user();
        $esAdmin = $usuario->tieneRol('Administrador');

        $filtros = $request->validate([
            'modulo' => ['nullable', Rule::in(self::MODULOS)],
            'accion' => ['nullable', Rule::in(self::ACCIONES)],
            'desde'  => ['nullable', 'date'],
            'hasta'  => ['nullable', 'date'],
        ]);

        $consulta = Auditoria::query()->orderBy('fecha', 'desc');

        if (! $esAdmin) {
            $consulta->where('id_usuario', $usuario->id_usuario);
        }
        if (! empty($filtros['modulo'])) {
            $consulta->where('modulo', $filtros['modulo']);
        }
        if (! empty($filtros['accion'])) {
            $consulta->where('accion', $filtros['accion']);
        }
        if (! empty($filtros['desde'])) {
            $consulta->where('fecha', '>=', Carbon::parse($filtros['desde'], self::ZONA)->startOfDay());
        }
        if (! empty($filtros['hasta'])) {
            $consulta->where('fecha', '<=', Carbon::parse($filtros['hasta'], self::ZONA)->endOfDay());
        }

        return view('auditoria.index', [
            'registros' => $consulta->paginate(15)->withQueryString(),
            'esAdmin'   => $esAdmin,
            'modulos'   => self::MODULOS,
            'acciones'  => self::ACCIONES,
            'filtros'   => $filtros,
            'zona'      => self::ZONA,
        ]);
    }
}