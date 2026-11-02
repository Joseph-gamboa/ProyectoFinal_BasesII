<?php

namespace App\Http\Controllers;

use App\Models\Rol;
use App\Models\Usuario;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class AuthController extends Controller
{
    public function showLogin()
    {
        return view('auth.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'correo'   => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        // Solo usuarios ACTIVOS pueden entrar (la columna estado de dbo.Usuarios).
        $credenciales = [
            'correo'   => $datos['correo'],
            'password' => $datos['password'],
            'estado'   => 'ACTIVO',
        ];

        if (! Auth::attempt($credenciales)) {
            return back()
                ->withErrors(['correo' => 'Correo o contraseña incorrectos, o la cuenta no está activa.'])
                ->onlyInput('correo');
        }

        $request->session()->regenerate();

        return redirect()->intended(route('dashboard'));
    }

    public function showRegister()
    {
        return view('auth.register');
    }

    public function register(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'nombre'   => ['required', 'string', 'max:60'],
            'apellido' => ['required', 'string', 'max:60'],
            'correo'   => ['required', 'email', 'max:120', 'unique:Usuarios,correo'],
            'password' => ['required', 'confirmed', Password::min(8)],
        ]);

        $usuario = DB::transaction(function () use ($datos) {
            $usuario = Usuario::create([
                'nombre'          => $datos['nombre'],
                'apellido'        => $datos['apellido'],
                'correo'          => $datos['correo'],
                'contrasena_hash' => Hash::make($datos['password']),
                'estado'          => 'ACTIVO',
            ]);

            // Todo usuario nuevo recibe el rol "Usuario".
            $rol = Rol::where('nombre', 'Usuario')->firstOrFail();
            $usuario->roles()->attach($rol->id_rol);

            return $usuario;
        });

        Auth::login($usuario);
        $request->session()->regenerate();

        return redirect()->route('dashboard');
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
