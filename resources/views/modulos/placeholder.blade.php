@extends('layouts.app')

@section('title', $titulo)
@section('page-title', $titulo)
@section('page-subtitle', $descripcion)

@section('content')
  <div class="card text-center py-5">
    <div class="mb-3"><i class="bi {{ $icono }}" style="font-size: 3rem;"></i></div>
    <h2 class="card-title mb-2">Módulo de {{ $titulo }}</h2>
    <p class="mb-0">Esta pantalla se implementará próximamente.</p>
  </div>
@endsection
