<?php

namespace App\Http\Controllers\Modules;

use Illuminate\Database\Query\Builder;

class IngresoController extends MovimientoController
{
    protected function tipo(): string
    {
        return 'INGRESO';
    }

    protected function modulo(): string
    {
        return 'ingresos';
    }

    protected function textos(): array
    {
        return [
            'titulo'       => 'Ingresos',
            'singular'     => 'ingreso',
            'subtitulo'    => 'Registra y consulta el dinero que entra a tus cuentas.',
            'icono'        => 'bi-arrow-down-circle',
            'boton_nuevo'  => 'Nuevo ingreso',
            'etiqueta'     => 'Fuente',
            'placeholder'  => 'Ej. Salario, ventas, servicios',
            'vacio'        => 'Aún no tienes ingresos registrados',
            'exito_crear'  => 'Ingreso registrado correctamente.',
            'exito_anular' => 'Ingreso anulado: el dinero se descontó de la cuenta.',
        ];
    }

    protected function reglasPropias(): array
    {
        return ['fuente' => ['required', 'string', 'max:80']];
    }

    protected function detalle(array $datos): string
    {
        return $datos['fuente'];
    }

    protected function conDetalle(Builder $consulta): Builder
    {
        return $consulta
            ->join('Ingresos as i', 'i.id_movimiento', '=', 'm.id_movimiento')
            ->addSelect('i.fuente as detalle');
    }
}
