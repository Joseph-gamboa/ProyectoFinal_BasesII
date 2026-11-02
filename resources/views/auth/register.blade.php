@extends('layouts.auth')

@section('title', 'Crear cuenta')

@section('content')
  <p class="login-subtitle">Crea tu cuenta y empieza a organizar tus finanzas.</p>

  <form action="{{ route('register') }}" method="POST" id="loginForm" class="needs-validation" novalidate>
    @csrf

    <div class="row g-2">
      <div class="col-6">
        <div class="login-form-group">
          <label for="nombre" class="login-form-label">Nombre</label>
          <div class="login-input-group">
            <i class="bi bi-person input-icon"></i>
            <input type="text" id="nombre" name="nombre" value="{{ old('nombre') }}" class="login-input"
              maxlength="60" required autofocus>
          </div>
          @error('nombre') <div class="text-danger small mt-1">{{ $message }}</div> @enderror
        </div>
      </div>
      <div class="col-6">
        <div class="login-form-group">
          <label for="apellido" class="login-form-label">Apellido</label>
          <div class="login-input-group">
            <i class="bi bi-person input-icon"></i>
            <input type="text" id="apellido" name="apellido" value="{{ old('apellido') }}" class="login-input"
              maxlength="60" required>
          </div>
          @error('apellido') <div class="text-danger small mt-1">{{ $message }}</div> @enderror
        </div>
      </div>
    </div>

    <div class="login-form-group">
      <label for="correo" class="login-form-label">Correo electrónico</label>
      <div class="login-input-group">
        <i class="bi bi-envelope input-icon"></i>
        <input type="email" id="correo" name="correo" value="{{ old('correo') }}" class="login-input"
          placeholder="nombre@correo.com" maxlength="120" required>
      </div>
      @error('correo') <div class="text-danger small mt-1">{{ $message }}</div> @enderror
    </div>

    <div class="login-form-group">
      <label for="password" class="login-form-label">Contraseña (mínimo 8 caracteres)</label>
      <div class="login-input-group">
        <i class="bi bi-shield-lock input-icon"></i>
        <input type="password" id="password" name="password" class="login-input login-input-password"
          minlength="8" required>
        <button type="button" class="password-toggle-btn" id="toggle-password" aria-label="Mostrar contraseña">
          <i class="bi bi-eye"></i>
        </button>
      </div>
      @error('password') <div class="text-danger small mt-1">{{ $message }}</div> @enderror
    </div>

    <div class="login-form-group">
      <label for="password_confirmation" class="login-form-label">Confirmar contraseña</label>
      <div class="login-input-group">
        <i class="bi bi-shield-check input-icon"></i>
        <input type="password" id="password_confirmation" name="password_confirmation" class="login-input"
          minlength="8" required>
      </div>
    </div>

    <button type="submit" class="btn-login mt-3" id="btn-submit">
      <span>Crear cuenta</span>
      <i class="bi bi-arrow-right"></i>
    </button>
  </form>

  <p class="login-footer-text">
    ¿Ya tienes cuenta? <a href="{{ route('login') }}">Inicia sesión</a>
  </p>
@endsection
