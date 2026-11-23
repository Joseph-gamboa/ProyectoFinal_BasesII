{{-- Mensajes de error y aviso que comparten los módulos --}}
@if (session('error'))
  <div class="alert alert-danger" role="alert">{{ session('error') }}</div>
@endif

@if (session('warning'))
  <div class="alert alert-warning" role="alert">{{ session('warning') }}</div>
@endif

@if ($errors->any())
  <div class="alert alert-danger" role="alert">
    @foreach ($errors->all() as $error)
      <div>{{ $error }}</div>
    @endforeach
  </div>
@endif
