<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\CuentaController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ModuloController;
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

    // Cuentas (módulo real)
    Route::get('/cuentas', [CuentaController::class, 'index'])->name('cuentas.index');
    Route::post('/cuentas', [CuentaController::class, 'store'])->name('cuentas.store');
    Route::put('/cuentas/{id}', [CuentaController::class, 'update'])->whereNumber('id')->name('cuentas.update');
    Route::patch('/cuentas/{id}/estado', [CuentaController::class, 'cambiarEstado'])->whereNumber('id')->name('cuentas.estado');
    Route::delete('/cuentas/{id}', [CuentaController::class, 'destroy'])->whereNumber('id')->name('cuentas.destroy');

    // Módulos que todavía son pantallas provisionales
    Route::get('/{modulo}', ModuloController::class)
        ->whereIn('modulo', [
            'cuentas', 'ingresos', 'gastos', 'transferencias', 'categorias',
            'presupuestos', 'ahorros', 'deudas', 'reportes', 'auditoria',
        ])
        ->name('modulo');
});