<?php

namespace App\Http\Controllers;

/**
 * Pantalla provisional para los módulos que todavía no se implementan.
 * Cuando un módulo tenga su propio controlador, se agrega su ruta en
 * routes/web.php y se borra su entrada de aquí.
 */
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
