<?php

namespace App\Services;

use App\Models\Auditoria;
use App\Models\Usuario;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class AuditoriaService
{
    /**
     * Guarda un evento en MongoDB. Nunca lanza errores: si MongoDB falla,
     * la acción del usuario continúa y solo se deja un aviso en el log.
     */
    public static function registrar(
        string $accion,
        string $modulo,
        ?int $entidadId = null,
        ?string $detalle = null,
        ?array $antes = null,
        ?array $despues = null,
        ?Usuario $usuario = null,
    ): void {
        try {
            $usuario ??= Auth::user();

            Auditoria::create([
                'id_usuario'     => $usuario?->id_usuario,
                'usuario_nombre' => $usuario?->nombre_completo,
                'usuario_correo' => $usuario?->correo,
                'accion'         => $accion,
                'modulo'         => $modulo,
                'entidad_id'     => $entidadId,
                'detalle'        => $detalle,
                'datos_antes'    => $antes,
                'datos_despues'  => $despues,
                'ip'             => request()->ip(),
                'fecha'          => now(),
            ]);
        } catch (\Throwable $e) {
            Log::warning('No se pudo guardar la auditoría: ' . $e->getMessage());
        }
    }
}