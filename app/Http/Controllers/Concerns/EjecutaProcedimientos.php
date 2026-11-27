<?php

namespace App\Http\Controllers\Concerns;

use App\Services\Database\Procedimientos;
use Illuminate\Database\QueryException;
use Illuminate\Http\RedirectResponse;

trait EjecutaProcedimientos
{

    protected function bd(): Procedimientos
    {
        return app(Procedimientos::class);
    }

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
        return $this->bd()->mensajeDeError($e);
    }
}
