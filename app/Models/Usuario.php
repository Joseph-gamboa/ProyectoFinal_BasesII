<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Foundation\Auth\User as Authenticatable;

class Usuario extends Authenticatable
{
    protected $table = 'Usuarios';
    protected $primaryKey = 'id_usuario';
    public $timestamps = false;

    protected $fillable = ['nombre', 'apellido', 'correo', 'contrasena_hash', 'estado'];
    protected $hidden = ['contrasena_hash'];

    public function getAuthPassword(): string
    {
        return $this->contrasena_hash;
    }

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
