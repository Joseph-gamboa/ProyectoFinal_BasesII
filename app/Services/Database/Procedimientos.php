<?php

namespace App\Services\Database;

interface Procedimientos
{

    public function consultar(string $procedimiento, array $parametros = []): array;

    public function llamar(string $procedimiento, array $parametros = []): void;

    public function registrar(string $procedimiento, array $parametros, string $salida): ?object;

    public function conjuntos(string $procedimiento, array $parametros = []): array;

    public function anularMovimiento(int $idMovimiento): void;

    public function condicionMesActual(string $columna): string;

    public function mensajeDeError(\Throwable $e): string;
}
