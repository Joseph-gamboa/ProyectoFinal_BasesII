<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class Auditoria extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'auditoria';
    public $timestamps = false;

    protected $fillable = [
        'id_usuario', 'usuario_nombre', 'usuario_correo',
        'accion', 'modulo', 'entidad_id', 'detalle',
        'datos_antes', 'datos_despues', 'ip', 'fecha',
    ];

    protected $casts = [
        'fecha' => 'datetime',
    ];
}