<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

/**
 * Registro de auditoría. Vive en MongoDB (base gravity_auditoria,
 * colección auditoria), no en SQL Server.
 */
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