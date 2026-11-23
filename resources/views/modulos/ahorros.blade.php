@extends('layouts.app')

@section('title', 'Ahorros')
@section('page-title', 'Ahorros')
@section('page-subtitle', 'Metas de ahorro y sus aportes.')

@section('page-actions')
  <button type="button" class="btn-dark-custom" data-bs-toggle="modal" data-bs-target="#modalCrear">
    <span class="icon-wrap"><i class="bi bi-plus-lg"></i></span>
    Nueva meta
  </button>
@endsection

@section('content')
  @php
    $estados = ['EN_CURSO' => ['En curso', 'pending'], 'CUMPLIDA' => ['Cumplida', 'success'], 'CANCELADA' => ['Cancelada', 'failed']];
    $reabrir = ($errors->any() || session('error')) && old('_form') === 'crear';
  @endphp

  @include('partials.alertas')

  @if ($metas->isEmpty())
    <div class="table-card-custom">
      <div class="text-center py-5">
        <div class="mb-3"><i class="bi bi-piggy-bank" style="font-size: 3rem;"></i></div>
        <h2 class="card-title mb-2">Aún no tienes metas de ahorro</h2>
        <p class="mb-0">Crea la primera con el botón "Nueva meta".</p>
      </div>
    </div>
  @else
    <div class="row g-3">
      @foreach ($metas as $m)
        @php
          $objetivo = (float) $m->monto_objetivo;
          $actual   = (float) $m->monto_actual;
          $pct      = (float) $m->porcentaje_avance;
          $enCurso  = $m->estado === 'EN_CURSO';
          [$textoEstado, $claseEstado] = $estados[$m->estado] ?? [$m->estado, 'pending'];
        @endphp
        <div class="col-md-6 col-xl-4">
          <div class="card h-100 p-3">
            <div class="d-flex justify-content-between align-items-start mb-2">
              <h2 class="card-title mb-0">{{ $m->nombre_meta }}</h2>
              <span class="badge-table {{ $claseEstado }}">{{ $textoEstado }}</span>
            </div>

            <div class="progress mb-1" style="height: 10px;">
              <div class="progress-bar {{ $m->estado === 'CUMPLIDA' ? 'bg-success' : '' }}" style="width: {{ min($pct, 100) }}%"></div>
            </div>
            <div class="d-flex justify-content-between small mb-2">
              <span>₡{{ number_format($actual, 2, ',', '.') }}</span>
              <span class="text-muted">{{ number_format($pct, 1, ',', '.') }}% de ₡{{ number_format($objetivo, 2, ',', '.') }}</span>
            </div>

            <p class="small text-muted mb-3">
              @if ($m->fecha_limite)
                Fecha límite: {{ \Illuminate\Support\Carbon::parse($m->fecha_limite)->format('d/m/Y') }}
              @else
                Sin fecha límite
              @endif
            </p>

            <div class="mt-auto d-flex gap-1">
              @if ($enCurso)
                <button type="button" class="btn-dark-custom flex-grow-1" data-bs-toggle="modal" data-bs-target="#modalAportar"
                  data-url="{{ route('ahorros.aportar', $m->id_meta) }}" data-nombre="{{ $m->nombre_meta }}"
                  data-faltante="{{ max($objetivo - $actual, 0) }}">
                  Aportar
                </button>
                <button type="button" class="btn btn-sm btn-light border" title="Editar"
                  data-bs-toggle="modal" data-bs-target="#modalEditar"
                  data-url="{{ route('ahorros.update', $m->id_meta) }}"
                  data-nombre="{{ $m->nombre_meta }}" data-objetivo="{{ $objetivo }}"
                  data-fecha="{{ $m->fecha_limite ? \Illuminate\Support\Carbon::parse($m->fecha_limite)->format('Y-m-d') : '' }}">
                  <i class="bi bi-pencil"></i>
                </button>
              @endif
              <form action="{{ route('ahorros.destroy', $m->id_meta) }}" method="POST"
                onsubmit="return confirm('¿Eliminar esta meta? Solo es posible si aún no tiene aportes.')">
                @csrf
                @method('DELETE')
                <button type="submit" class="btn btn-sm btn-light border text-danger" title="Eliminar">
                  <i class="bi bi-trash"></i>
                </button>
              </form>
            </div>
          </div>
        </div>
      @endforeach
    </div>
  @endif

  {{-- Ventana: nueva meta --}}
  <div class="modal fade" id="modalCrear" tabindex="-1" aria-labelledby="modalCrearLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" action="{{ route('ahorros.store') }}" method="POST">
        @csrf
        <input type="hidden" name="_form" value="crear">
        <div class="modal-header">
          <h5 class="modal-title" id="modalCrearLabel">Nueva meta de ahorro</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div class="mb-3">
            <label class="form-label" for="crear_nombre">Nombre de la meta</label>
            <input type="text" id="crear_nombre" name="nombre_meta" class="form-control-custom" maxlength="80"
              value="{{ old('nombre_meta') }}" placeholder="Ej. Viaje, laptop, fondo de emergencia" required>
          </div>
          <div class="row g-3">
            <div class="col-6">
              <label class="form-label" for="crear_objetivo">Objetivo (₡)</label>
              <input type="number" id="crear_objetivo" name="monto_objetivo" class="form-control-custom"
                min="0.01" step="0.01" value="{{ old('monto_objetivo') }}" required>
            </div>
            <div class="col-6">
              <label class="form-label" for="crear_fecha">Fecha límite (opcional)</label>
              <input type="date" id="crear_fecha" name="fecha_limite" class="form-control-custom"
                min="{{ date('Y-m-d', strtotime('+1 day')) }}" value="{{ old('fecha_limite') }}">
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn-dark-custom">Crear meta</button>
        </div>
      </form>
    </div>
  </div>

  {{-- Ventana: editar meta (lo ahorrado no se edita a mano) --}}
  <div class="modal fade" id="modalEditar" tabindex="-1" aria-labelledby="modalEditarLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" id="formEditar" action="#" method="POST">
        @csrf
        @method('PUT')
        <div class="modal-header">
          <h5 class="modal-title" id="modalEditarLabel">Editar meta</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div class="mb-3">
            <label class="form-label" for="editar_nombre">Nombre de la meta</label>
            <input type="text" id="editar_nombre" name="nombre_meta" class="form-control-custom" maxlength="80" required>
          </div>
          <div class="row g-3">
            <div class="col-6">
              <label class="form-label" for="editar_objetivo">Objetivo (₡)</label>
              <input type="number" id="editar_objetivo" name="monto_objetivo" class="form-control-custom" min="0.01" step="0.01" required>
            </div>
            <div class="col-6">
              <label class="form-label" for="editar_fecha">Fecha límite</label>
              <input type="date" id="editar_fecha" name="fecha_limite" class="form-control-custom"
                min="{{ date('Y-m-d', strtotime('+1 day')) }}">
            </div>
          </div>
          <p class="small text-muted mt-3 mb-0">Lo ahorrado cambia solo con los aportes.</p>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn-dark-custom">Guardar cambios</button>
        </div>
      </form>
    </div>
  </div>

  {{-- Ventana: aportar a una meta --}}
  <div class="modal fade" id="modalAportar" tabindex="-1" aria-labelledby="modalAportarLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" id="formAportar" action="#" method="POST">
        @csrf
        <div class="modal-header">
          <h5 class="modal-title" id="modalAportarLabel">Aportar a la meta</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <p class="mb-3">Meta: <strong id="aportar_meta"></strong><br>
            <span class="small text-muted">Faltan ₡<span id="aportar_faltante"></span></span></p>
          @if ($cuentas->isEmpty())
            <div class="alert alert-warning mb-0">
              No tienes cuentas en colones (que no sean tarjeta) para aportar. Crea una en el módulo de Cuentas.
            </div>
          @else
            <div class="mb-3">
              <label class="form-label" for="aportar_cuenta">Desde la cuenta</label>
              <select id="aportar_cuenta" name="id_cuenta" class="form-control-custom" required>
                @foreach ($cuentas as $c)
                  <option value="{{ $c->id_cuenta }}">{{ $c->nombre_cuenta }} — ₡{{ number_format((float) $c->saldo, 2, ',', '.') }}</option>
                @endforeach
              </select>
            </div>
            <div>
              <label class="form-label" for="aportar_monto">Monto (₡)</label>
              <input type="number" id="aportar_monto" name="monto" class="form-control-custom" min="0.01" step="0.01" required>
            </div>
          @endif
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          @unless ($cuentas->isEmpty())
            <button type="submit" class="btn-dark-custom">Aportar</button>
          @endunless
        </div>
      </form>
    </div>
  </div>
@endsection

@push('scripts')
  <script>
    document.getElementById('modalEditar').addEventListener('show.bs.modal', function (e) {
      var b = e.relatedTarget, f = document.getElementById('formEditar');
      f.action = b.dataset.url;
      f.querySelector('[name=nombre_meta]').value = b.dataset.nombre;
      f.querySelector('[name=monto_objetivo]').value = b.dataset.objetivo;
      f.querySelector('[name=fecha_limite]').value = b.dataset.fecha;
    });

    document.getElementById('modalAportar').addEventListener('show.bs.modal', function (e) {
      var b = e.relatedTarget, f = document.getElementById('formAportar');
      f.action = b.dataset.url;
      document.getElementById('aportar_meta').textContent = b.dataset.nombre;
      document.getElementById('aportar_faltante').textContent =
        Number(b.dataset.faltante).toLocaleString('es-CR', { minimumFractionDigits: 2 });
      var m = f.querySelector('[name=monto]');
      if (m) { m.max = b.dataset.faltante; m.value = ''; }
    });
  </script>
  @if ($reabrir)
    <script>new bootstrap.Modal(document.getElementById('modalCrear')).show();</script>
  @endif
@endpush
