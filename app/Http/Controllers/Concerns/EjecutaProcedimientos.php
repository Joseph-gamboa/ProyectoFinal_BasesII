<?php

namespace App\Http\Controllers\Concerns;

use Illuminate\Database\QueryException;
use Illuminate\Http\RedirectResponse;

trait EjecutaProcedimientos
{

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

    protected function mensajeDeSql(QueryException $e): string
    {
        $texto = $e->getPrevious()?->getMessage() ?? $e->getMessage();

        if (preg_match('/\[SQL Server\](.+)$/s', $texto, $m)) {
            return trim($m[1]);
        }

        return 'No se pudo completar la operación. Intente de nuevo.';
    }
}
