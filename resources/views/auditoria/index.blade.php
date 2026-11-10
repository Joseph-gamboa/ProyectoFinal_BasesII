@extends('layouts.app')

@section('title', 'Auditoría')
@section('page-title', 'Auditoría')
@section('page-subtitle', $esAdmin
    ? 'Registro de las acciones de todos los usuarios (guardado en MongoDB).'
    : 'Registro de tus acciones (guardado en MongoDB).')

@section('content')
  @php
    $clases = [
        'CREAR' => 'success', 'REABRIR' => 'success', 'APORTAR' => 'success',
        'ELIMINAR' => 'failed', 'CERRAR' => 'failed', 'ANULAR' => 'failed',
    ];
    $json = fn ($dato) => json_encode($dato, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
  @endphp

  @if ($errors->any())
    <div class="alert alert-danger" role="alert">
      @foreach ($errors->all() as $error)
        <div>{{ $error }}</div>
      @endforeach
    </div>
  @endif

  {{-- Filtros --}}
  <form method="GET" action="{{ route('auditoria.index') }}" class="card mb-3">
    <div class="row g-3 align-items-end">
      <div class="col-md-3">
        <label class="form-label" for="f_modulo">Módulo</label>
        <select id="f_modulo" name="modulo" class="form-control-custom">
          <option value="">Todos</option>
          @foreach ($modulos as $m)
            <option value="{{ $m }}" @selected(($filtros['modulo'] ?? '') === $m)>{{ ucfirst($m) }}</option>
          @endforeach
        </select>
      </div>
      <div class="col-md-3">
        <label class="form-label" for="f_accion">Acción</label>
        <select id="f_accion" name="accion" class="form-control-custom">
          <option value="">Todas</option>
          @foreach ($acciones as $a)
            <option value="{{ $a }}" @selected(($filtros['accion'] ?? '') === $a)>{{ ucfirst(strtolower($a)) }}</option>
          @endforeach
        </select>
      </div>
      <div class="col-md-2">
        <label class="form-label" for="f_desde">Desde</label>
        <input type="date" id="f_desde" name="desde" class="form-control-custom" value="{{ $filtros['desde'] ?? '' }}">
      </div>
      <div class="col-md-2">
        <label class="form-label" for="f_hasta">Hasta</label>
        <input type="date" id="f_hasta" name="hasta" class="form-control-custom" value="{{ $filtros['hasta'] ?? '' }}">
      </div>
      <div class="col-md-2 d-flex gap-2">
        <button type="submit" class="btn-dark-custom">Filtrar</button>
        <a href="{{ route('auditoria.index') }}" class="btn btn-light border">Limpiar</a>
      </div>
    </div>
  </form>

  {{-- Registros --}}
  <div class="table-card-custom">
    @if ($registros->isEmpty())
      <div class="text-center py-5">
        <div class="mb-3"><i class="bi bi-shield-check" style="font-size: 3rem;"></i></div>
        <h2 class="card-title mb-2">No hay registros</h2>
        <p class="mb-0">Cuando se creen, editen o eliminen datos, las acciones aparecerán aquí.</p>
      </div>
    @else
      <div class="table-responsive">
        <table class="table-custom">
          <thead>
            <tr>
              <th>Fecha</th>
              @if ($esAdmin) <th>Usuario</th> @endif
              <th>Módulo</th>
              <th>Acción</th>
              <th>Detalle</th>
              <th>Cambios</th>
            </tr>
          </thead>
          <tbody>
            @foreach ($registros as $r)
              <tr>
                <td class="text-nowrap">{{ $r->fecha?->timezone($zona)->format('d/m/Y H:i') }}</td>
                @if ($esAdmin)
                  <td>
                    <div class="fw-bold">{{ $r->usuario_nombre }}</div>
                    <div class="small text-muted">{{ $r->usuario_correo }}</div>
                  </td>
                @endif
                <td>{{ ucfirst($r->modulo) }}</td>
                <td><span class="badge-table {{ $clases[$r->accion] ?? '' }}">{{ ucfirst(strtolower($r->accion)) }}</span></td>
                <td>{{ $r->detalle }}</td>
                <td>
                  @if ($r->datos_antes || $r->datos_despues)
                    <details>
                      <summary class="small">Ver cambios</summary>
                      @if ($r->datos_antes)
                        <div class="small fw-bold mt-2">Antes</div>
                        <pre class="small mb-1">{{ $json($r->datos_antes) }}</pre>
                      @endif
                      @if ($r->datos_despues)
                        <div class="small fw-bold mt-2">Después</div>
                        <pre class="small mb-0">{{ $json($r->datos_despues) }}</pre>
                      @endif
                    </details>
                  @else
                    <span class="text-muted">—</span>
                  @endif
                </td>
              </tr>
            @endforeach
          </tbody>
        </table>
      </div>

      <div class="mt-3">
        {{ $registros->links('pagination::bootstrap-5') }}
      </div>
    @endif
  </div>
@endsection