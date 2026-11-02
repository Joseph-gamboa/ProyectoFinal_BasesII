<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ModuloController;
use Illuminate\Support\Facades\Route;

// Modo demostración: no requiere autenticación ni conexión a base de datos.
Route::get('/', fn () => redirect()->route('dashboard'));
Route::get('/login', fn () => redirect()->route('dashboard'))->name('login');
Route::get('/registro', fn () => redirect()->route('dashboard'))->name('register');
Route::post('/login', fn () => redirect()->route('dashboard'));
Route::post('/logout', fn () => redirect()->route('dashboard'))->name('logout');

Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');

Route::get('/{modulo}', ModuloController::class)
    ->whereIn('modulo', [
        'cuentas', 'ingresos', 'gastos', 'transferencias', 'categorias',
        'presupuestos', 'ahorros', 'deudas', 'reportes', 'auditoria',
    ])
    ->name('modulo');
