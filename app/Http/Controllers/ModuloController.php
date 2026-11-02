<?php

namespace App\Http\Controllers;

/**
 * Pantalla provisional para los módulos que todavía no se implementan.
 * Cuando un módulo tenga su propio controlador, se cambia su ruta en
 * routes/web.php y se borra su entrada de aquí.
 */
class ModuloController extends Controller
{
    private const MODULOS = [
        'cuentas'        => ['Cuentas',        'bi-bank',            'Administración de cuentas bancarias, de ahorro, efectivo y digitales.'],
        'ingresos'       => ['Ingresos',       'bi-arrow-down-circle', 'Registro y consulta de ingresos.'],
        'gastos'         => ['Gastos',         'bi-arrow-up-circle',   'Registro, clasificación y consulta de gastos.'],
        'transferencias' => ['Transferencias', 'bi-arrow-left-right',  'Movimiento de dinero entre cuentas propias.'],
        'categorias'     => ['Categorías',     'bi-tags',            'Categorías de ingresos y gastos.'],
        'presupuestos'   => ['Presupuestos',   'bi-pie-chart',       'Límites de gasto por categoría y periodo.'],
        'ahorros'        => ['Ahorros',        'bi-piggy-bank',      'Metas de ahorro y sus aportes.'],
        'deudas'         => ['Deudas',         'bi-cash-coin',       'Préstamos, cuotas y pagos.'],
        'reportes'       => ['Reportes',       'bi-file-earmark-bar-graph', 'Informes financieros por periodo.'],
        'auditoria'      => ['Auditoría',      'bi-shield-check',    'Registro de actividades importantes (MongoDB).'],
    ];

    public function __invoke(string $modulo)
    {
        abort_unless(isset(self::MODULOS[$modulo]), 404);

        [$titulo, $icono, $descripcion] = self::MODULOS[$modulo];

        return view('modulos.placeholder', compact('modulo', 'titulo', 'icono', 'descripcion'));
    }
}
