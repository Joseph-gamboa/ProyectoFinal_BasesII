<?php

namespace App\Http\Controllers;

class ModuloController extends Controller
{
    private const MODULOS = [
        'deudas' => ['Deudas', 'bi-cash-coin', 'Préstamos, cuotas y pagos.'],
    ];

    public function __invoke(string $modulo)
    {
        abort_unless(isset(self::MODULOS[$modulo]), 404);

        [$titulo, $icono, $descripcion] = self::MODULOS[$modulo];

        return view('modulos.placeholder', compact('modulo', 'titulo', 'icono', 'descripcion'));
    }
}
