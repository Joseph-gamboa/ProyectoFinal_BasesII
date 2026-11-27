<?php

namespace App\Providers;

use App\Services\Database\MariaDB\MariaDbProcedimientos;
use App\Services\Database\Procedimientos;
use App\Services\Database\SqlServer\SqlServerProcedimientos;
use Illuminate\Pagination\Paginator;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{

    public function register(): void
    {

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

    public function boot(): void
    {
        Paginator::useBootstrapFive();
    }
}
