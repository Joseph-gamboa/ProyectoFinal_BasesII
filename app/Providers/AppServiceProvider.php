<?php

namespace App\Providers;

use App\Services\Database\MariaDB\MariaDbProcedimientos;
use App\Services\Database\Procedimientos;
use App\Services\Database\SqlServer\SqlServerProcedimientos;
use Illuminate\Pagination\Paginator;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // El motor lo decide DB_CONNECTION en el .env de cada quien:
        //   sqlsrv          -> SQL Server (oficial, el del equipo)
        //   mariadb / mysql -> MariaDB (solo desarrollo local)
        $this->app->singleton(Procedimientos::class, function ($app) {
            $conexion = config('database.default');
            $driver   = config("database.connections.{$conexion}.driver");

            return match ($driver) {
                'sqlsrv'           => new SqlServerProcedimientos(),
                'mariadb', 'mysql' => new MariaDbProcedimientos(),
                default            => throw new \RuntimeException(
                    "DB_CONNECTION={$conexion} no está soportada: use sqlsrv (oficial) o mariadb (local)."
                ),
            };
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Paginator::useBootstrapFive();
    }
}
