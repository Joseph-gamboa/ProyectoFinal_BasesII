@extends('layouts.auth')

@section('title', 'Iniciar sesión')

@section('content')
  <p class="login-subtitle">Toma el control de tu dinero. Inicia sesión para continuar.</p>

  <form action="{{ route('login') }}" method="POST" id="loginForm" class="needs-validation" novalidate>
    @csrf

    <div class="login-form-group">
      <label for="correo" class="login-form-label">Correo electrónico</label>
      <div class="login-input-group">
        <i class="bi bi-envelope input-icon"></i>
        <input type="email" id="correo" name="correo" value="{{ old('correo') }}" class="login-input"
          placeholder="nombre@correo.com" required autofocus>
      </div>
      @error('correo')
        <div class="text-danger small mt-1">{{ $message }}</div>
      @enderror
    </div>

    <div class="login-form-group">
      <label for="password" class="login-form-label">Contraseña</label>
      <div class="login-input-group">
        <i class="bi bi-shield-lock input-icon"></i>
        <input type="password" id="password" name="password" class="login-input login-input-password"
          placeholder="••••••••" required>
        <button type="button" class="password-toggle-btn" id="toggle-password" aria-label="Mostrar contraseña">
          <i class="bi bi-eye"></i>
        </button>
      </div>
      @error('password')
        <div class="text-danger small mt-1">{{ $message }}</div>
      @enderror
    </div>

    <button type="submit" class="btn-login mt-3" id="btn-submit">
      <span>Entrar a Gravity Finance</span>
      <i class="bi bi-arrow-right"></i>
    </button>
  </form>

  <p class="login-footer-text">
    ¿No tienes cuenta? <a href="{{ route('register') }}">Regístrate</a>
  </p>
@endsection
