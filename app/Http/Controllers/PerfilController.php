<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Throwable;

class PerfilController extends Controller
{
    public function edit()
    {
        return view('perfil.edit');
    }

    public function update(Request $request)
    {
        $request->validate([
            'foto' => [
                'required',
                'image',
                'mimes:jpg,jpeg,png,webp',
                'max:2048',
                'dimensions:max_width=4096,max_height=4096',
            ],
        ]);

        $usuario = $request->user();
        $anterior = $usuario->foto_perfil;

        $ruta = $request->file('foto')->store(
            'perfiles/' . $usuario->getKey(),
            'public'
        );

        if (!$ruta) {
            return back()->withErrors([
                'foto' => 'No se pudo guardar la imagen. Inténtalo de nuevo.',
            ]);
        }

        try {
            // Solo modifica la foto del usuario conectado.
            $usuario->foto_perfil = $ruta;
            $usuario->save();
        } catch (Throwable $e) {
            Storage::disk('public')->delete($ruta);
            throw $e;
        }

        // La imagen anterior se elimina después de guardar la nueva ruta.
        $prefijo = 'perfiles/' . $usuario->getKey() . '/';

        if ($anterior && str_starts_with($anterior, $prefijo)) {
            Storage::disk('public')->delete($anterior);
        }

        return redirect()->route('perfil.edit')
            ->with('success', 'Foto de perfil actualizada correctamente.');
    }
}