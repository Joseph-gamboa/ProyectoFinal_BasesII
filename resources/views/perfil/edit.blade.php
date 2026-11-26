@extends('layouts.app')

@section('title', 'Mi perfil')
@section('page-title', 'Mi perfil')
@section('page-subtitle', 'Personaliza tu foto de perfil.')

@section('content')
<div class="row">
    <div class="col-lg-6">
        <div class="card">
            @if (session('success'))
                <div class="alert alert-success" role="alert">
                    {{ session('success') }}
                </div>
            @endif

            <div class="text-center mb-4">
                <img
                    src="{{ auth()->user()->foto_perfil_url }}"
                    alt="Tu foto de perfil"
                    width="120"
                    height="120"
                    style="border-radius: 50%; object-fit: cover;"
                >

                <h2 class="h5 mt-3">
                    {{ auth()->user()->nombre_completo }}
                </h2>

                <p>{{ auth()->user()->correo }}</p>
            </div>

            <form
                action="{{ route('perfil.update') }}"
                method="POST"
                enctype="multipart/form-data"
            >
                @csrf
                @method('PUT')

                <div class="mb-3">
                    <label for="foto" class="form-label">
                        Nueva foto
                    </label>

                    <input
                        type="file"
                        id="foto"
                        name="foto"
                        class="form-control @error('foto') is-invalid @enderror"
                        accept="image/jpeg,image/png,image/webp"
                        required
                        aria-describedby="foto-ayuda"
                    >

                    <div id="foto-ayuda" class="form-text">
                        JPG, PNG o WebP. Máximo 2 MB y 4096 × 4096 píxeles.
                    </div>

                    @error('foto')
                        <div class="invalid-feedback">{{ $message }}</div>
                    @enderror
                </div>

                <button type="submit" class="btn btn-dark">
                    Guardar foto
                </button>
            </form>
        </div>
    </div>
</div>
@endsection