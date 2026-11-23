<?php

namespace App\Http\Controllers\Modules;

use Illuminate\Database\Query\Builder;
use Illuminate\Validation\Rule;

class GastoController extends MovimientoController
{
    protected function tipo(): string
    {
        return 'GASTO';
    }

    protected function modulo(): string
    {
        return 'gastos';
    }

    protected function textos(): array
    {
        return [
            'titulo'       => 'Gastos',
            'singular'     => 'gasto',
            'subtitulo'    => 'Registra y clasifica el dinero que sale de tus cuentas.',
            'icono'        => 'bi-arrow-up-circle',
            'boton_nuevo'  => 'Nuevo gasto',
            'etiqueta'     => 'Comercio',
            'placeholder'  => 'Ej. Supermercado, gasolinera',
            'vacio'        => 'Aún no tienes gastos registrados',
            'exito_crear'  => 'Gasto registrado correctamente.',
            'exito_anular' => 'Gasto anulado: el dinero volvió a la cuenta.',
        ];
    }

    protected function reglasPropias(): array
    {
        return [
            'comercio'    => ['required', 'string', 'max:80'],
            'metodo_pago' => ['required', Rule::in(['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'])],
        ];
    }

    protected function detalle(array $datos): string
    {
        return $datos['comercio'];
    }

    protected function metodoPago(array $datos): ?string
    {
        return $datos['metodo_pago'];
    }

    protected function conDetalle(Builder $consulta): Builder
    {
        return $consulta
            ->join('Gastos as g', 'g.id_movimiento', '=', 'm.id_movimiento')
            ->addSelect('g.comercio as detalle', 'g.metodo_pago');
    }
}
