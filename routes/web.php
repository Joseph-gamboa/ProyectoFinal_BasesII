<?php

use App\Http\Controllers\AuditoriaController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\CuentaController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ModuloController;
use App\Http\Controllers\Modules\AhorroController;
use App\Http\Controllers\Modules\CategoriaController;
use App\Http\Controllers\Modules\GastoController;
use App\Http\Controllers\Modules\IngresoController;
use App\Http\Controllers\Modules\PresupuestoController;
use App\Http\Controllers\Modules\ReporteController;
use App\Http\Controllers\Modules\TransferenciaController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect()->route('dashboard'));

// Solo para visitantes (sin sesión iniciada)
Route::middleware('guest')->group(function () {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login']);
    Route::get('/registro', [AuthController::class, 'showRegister'])->name('register');
    Route::post('/registro', [AuthController::class, 'register']);
});

// Solo para usuarios con sesión iniciada
Route::middleware('auth')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');
    Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');

    // Cuentas
    Route::get('/cuentas', [CuentaController::class, 'index'])->name('cuentas.index');
    Route::post('/cuentas', [CuentaController::class, 'store'])->name('cuentas.store');
    Route::put('/cuentas/{id}', [CuentaController::class, 'update'])->whereNumber('id')->name('cuentas.update');
    Route::patch('/cuentas/{id}/estado', [CuentaController::class, 'cambiarEstado'])->whereNumber('id')->name('cuentas.estado');
    Route::delete('/cuentas/{id}', [CuentaController::class, 'destroy'])->whereNumber('id')->name('cuentas.destroy');

    // Ingresos y gastos (usp_Movimientos_Registrar + trigger de anulación)
    Route::get('/ingresos', [IngresoController::class, 'index'])->name('ingresos.index');
    Route::post('/ingresos', [IngresoController::class, 'store'])->name('ingresos.store');
    Route::delete('/ingresos/{id}', [IngresoController::class, 'destroy'])->whereNumber('id')->name('ingresos.destroy');

    Route::get('/gastos', [GastoController::class, 'index'])->name('gastos.index');
    Route::post('/gastos', [GastoController::class, 'store'])->name('gastos.store');
    Route::delete('/gastos/{id}', [GastoController::class, 'destroy'])->whereNumber('id')->name('gastos.destroy');

    // Transferencias
    Route::get('/transferencias', [TransferenciaController::class, 'index'])->name('transferencias.index');
    Route::post('/transferencias', [TransferenciaController::class, 'store'])->name('transferencias.store');

    // Categorías (solo el administrador modifica)
    Route::get('/categorias', [CategoriaController::class, 'index'])->name('categorias.index');
    Route::post('/categorias', [CategoriaController::class, 'store'])->name('categorias.store');
    Route::put('/categorias/{id}', [CategoriaController::class, 'update'])->whereNumber('id')->name('categorias.update');
    Route::delete('/categorias/{id}', [CategoriaController::class, 'destroy'])->whereNumber('id')->name('categorias.destroy');

    // Presupuestos
    Route::get('/presupuestos', [PresupuestoController::class, 'index'])->name('presupuestos.index');
    Route::post('/presupuestos', [PresupuestoController::class, 'store'])->name('presupuestos.store');
    Route::put('/presupuestos/{id}', [PresupuestoController::class, 'update'])->whereNumber('id')->name('presupuestos.update');
    Route::delete('/presupuestos/{id}', [PresupuestoController::class, 'destroy'])->whereNumber('id')->name('presupuestos.destroy');

    // Ahorros (metas y aportes)
    Route::get('/ahorros', [AhorroController::class, 'index'])->name('ahorros.index');
    Route::post('/ahorros', [AhorroController::class, 'store'])->name('ahorros.store');
    Route::put('/ahorros/{id}', [AhorroController::class, 'update'])->whereNumber('id')->name('ahorros.update');
    Route::delete('/ahorros/{id}', [AhorroController::class, 'destroy'])->whereNumber('id')->name('ahorros.destroy');
    Route::post('/ahorros/{id}/aportar', [AhorroController::class, 'aportar'])->whereNumber('id')->name('ahorros.aportar');

    // Reportes
    Route::get('/reportes', [ReporteController::class, 'index'])->name('reportes.index');

    // Auditoría (lee MongoDB)
    Route::get('/auditoria', [AuditoriaController::class, 'index'])->name('auditoria.index');

    // Módulos que todavía son pantallas provisionales (Deudas: aún no tiene tablas en SQL)
    Route::get('/{modulo}', ModuloController::class)
        ->whereIn('modulo', ['deudas'])
        ->name('modulo');
});
