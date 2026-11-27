<?php

namespace App\Http\Controllers\Concerns;

use App\Services\Database\Procedimientos;
use Illuminate\Database\QueryException;
use Illuminate\Http\RedirectResponse;

trait EjecutaProcedimientos
{
    /** Acceso a los procedimientos almacenados del motor configurado (SQL Server o MariaDB). */
    protected function bd(): Procedimientos
    {
        return app(Procedimientos::class);
    }

    /**
     * Ejecuta la acción y, si un procedimiento la rechaza, muestra su mensaje.
     * Si la acción devuelve un texto, se muestra como aviso (no como error).
     */
    protected function ejecutar(callable $accion, string $mensajeExito): RedirectResponse
    {
        try {
            $aviso = $accion();
        } catch (QueryException $e) {
            return back()->withInput()->with('error', $this->mensajeDeSql($e));
        }

        $respuesta = back()->with('status', $mensajeExito);

        return is_string($aviso) && $aviso !== ''
            ? $respuesta->with('warning', $aviso)
            : $respuesta;
    }

    /** Extrae solo el texto que escribió el procedimiento (THROW en SQL Server, SIGNAL en MariaDB). */
    protected function mensajeDeSql(QueryException $e): string
    {
        return $this->bd()->mensajeDeError($e);
    }
}
