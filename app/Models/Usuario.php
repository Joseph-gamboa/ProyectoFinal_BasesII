<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Foundation\Auth\User as Authenticatable;

/**
 * Usuario de Gravity Finance (tabla dbo.Usuarios de SQL Server).
 * Reemplaza al modelo User por defecto de Laravel (ver AUTH_MODEL en .env).
 */
class Usuario extends Authenticatable
{
    protected $table = 'Usuarios';
    protected $primaryKey = 'id_usuario';
    public $timestamps = false;

    protected $fillable = ['nombre', 'apellido', 'correo', 'contrasena_hash', 'estado'];
    protected $hidden = ['contrasena_hash'];

    /** La contraseña vive en la columna contrasena_hash, no en "password". */
    public function getAuthPassword(): string
    {
        return $this->contrasena_hash;
    }

    /** La tabla Usuarios no tiene remember_token: se desactiva "recordarme". */
    public function getRememberTokenName(): string
    {
        return '';
    }

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Rol::class, 'UsuarioRol', 'id_usuario', 'id_rol');
    }

    public function tieneRol(string ...$nombres): bool
    {
        return $this->roles->pluck('nombre')->intersect($nombres)->isNotEmpty();
    }

    public function getNombreCompletoAttribute(): string
    {
        return trim($this->nombre . ' ' . $this->apellido);
    }
}
