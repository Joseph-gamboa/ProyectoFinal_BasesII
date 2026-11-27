@extends('layouts.app')

@section('title', 'Deudas')
@section('page-title', 'Deudas')
@section('page-subtitle', 'Préstamos y deudas con sus pagos.')

@section('page-actions')
  <button type="button" class="btn-dark-custom" data-bs-toggle="modal" data-bs-target="#modalCrear">
    <span class="icon-wrap"><i class="bi bi-plus-lg"></i></span>
    Nueva deuda
  </button>
@endsection

@section('content')
  @php
    $estados = ['VIGENTE' => ['Vigente', 'pending'], 'PAGADA' => ['Pagada', 'success']];
    $reabrir = ($errors->any() || session('error')) && old('_form') === 'crear';
  @endphp

  @include('partials.alertas')

  @if ($deudas->isEmpty())
    <div class="table-card-custom">
      <div class="text-center py-5">
        <div class="mb-3"><i class="bi bi-cash-coin" style="font-size: 3rem;"></i></div>
        <h2 class="card-title mb-2">Aún no tienes deudas registradas</h2>
        <p class="mb-0">Registra la primera con el botón "Nueva deuda".</p>
      </div>
    </div>
  @else
    <div class="row g-3">
      @foreach ($deudas as $d)
        @php
          $total     = (float) $d->monto_total;
          $pendiente = (float) $d->saldo_pendiente;
          $pagado    = (float) $d->monto_pagado;
          $pct       = (float) $d->porcentaje_pagado;
          $vigente   = $d->estado === 'VIGENTE';
          [$textoEstado, $claseEstado] = $estados[$d->estado] ?? [$d->estado, 'pending'];
          if ($d->vencida) { $textoEstado = 'Vencida'; $claseEstado = 'failed'; }
        @endphp
        <div class="col-md-6 col-xl-4">
          <div class="card h-100 p-3">
            <div class="d-flex justify-content-between align-items-start mb-1">
              <h2 class="card-title mb-0">{{ $d->nombre_deuda }}</h2>
              <span class="badge-table {{ $claseEstado }}">{{ $textoEstado }}</span>
            </div>
            <p class="small text-muted mb-2">Acreedor: {{ $d->acreedor }}</p>

            <div class="progress mb-1" style="height: 10px;">
              <div class="progress-bar {{ $d->estado === 'PAGADA' ? 'bg-success' : '' }}" style="width: {{ min($pct, 100) }}%"></div>
            </div>
            <div class="d-flex justify-content-between small mb-2">
              <span>Pagado ₡{{ number_format($pagado, 2, ',', '.') }}</span>
              <span class="text-muted">{{ number_format($pct, 1, ',', '.') }}% de ₡{{ number_format($total, 2, ',', '.') }}</span>
            </div>

            <p class="mb-1"><strong>Pendiente: ₡{{ number_format($pendiente, 2, ',', '.') }}</strong></p>
            <p class="small text-muted mb-3">
              @if ($d->fecha_vencimiento)
                Vence: {{ \Illuminate\Support\Carbon::parse($d->fecha_vencimiento)->format('d/m/Y') }}
              @else
                Sin fecha de vencimiento
              @endif
            </p>

            <div class="mt-auto d-flex gap-1">
              @if ($vigente)
                <button type="button" class="btn-dark-custom flex-grow-1" data-bs-toggle="modal" data-bs-target="#modalPagar"
                  data-url="{{ route('deudas.pagar', $d->id_deuda) }}" data-nombre="{{ $d->nombre_deuda }}"
                  data-pendiente="{{ $pendiente }}">
                  Pagar
                </button>
                <button type="button" class="btn btn-sm btn-light border" title="Editar"
                  data-bs-toggle="modal" data-bs-target="#modalEditar"
                  data-url="{{ route('deudas.update', $d->id_deuda) }}"
                  data-nombre="{{ $d->nombre_deuda }}" data-acreedor="{{ $d->acreedor }}"
                  data-total="{{ $total }}"
                  data-fecha="{{ $d->fecha_vencimiento ? \Illuminate\Support\Carbon::parse($d->fecha_vencimiento)->format('Y-m-d') : '' }}">
                  <i class="bi bi-pencil"></i>
                </button>
              @endif
              <form action="{{ route('deudas.destroy', $d->id_deuda) }}" method="POST"
                onsubmit="return confirm('¿Eliminar esta deuda? Solo es posible si aún no tiene pagos.')">
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

  {{-- Ventana: nueva deuda --}}
  <div class="modal fade" id="modalCrear" tabindex="-1" aria-labelledby="modalCrearLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" action="{{ route('deudas.store') }}" method="POST">
        @csrf
        <input type="hidden" name="_form" value="crear">
        <div class="modal-header">
          <h5 class="modal-title" id="modalCrearLabel">Nueva deuda</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div class="mb-3">
            <label class="form-label" for="crear_nombre">Nombre de la deuda</label>
            <input type="text" id="crear_nombre" name="nombre_deuda" class="form-control-custom" maxlength="80"
              value="{{ old('nombre_deuda') }}" placeholder="Ej. Préstamo del carro" required>
          </div>
          <div class="mb-3">
            <label class="form-label" for="crear_acreedor">A quién se le debe</label>
            <input type="text" id="crear_acreedor" name="acreedor" class="form-control-custom" maxlength="80"
              value="{{ old('acreedor') }}" placeholder="Ej. Banco Nacional" required>
          </div>
          <div class="row g-3">
            <div class="col-6">
              <label class="form-label" for="crear_total">Monto total (₡)</label>
              <input type="number" id="crear_total" name="monto_total" class="form-control-custom"
                min="0.01" step="0.01" value="{{ old('monto_total') }}" required>
            </div>
            <div class="col-6">
              <label class="form-label" for="crear_fecha">Vence (opcional)</label>
              <input type="date" id="crear_fecha" name="fecha_vencimiento" class="form-control-custom"
                min="{{ date('Y-m-d', strtotime('+1 day')) }}" value="{{ old('fecha_vencimiento') }}">
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn-dark-custom">Registrar deuda</button>
        </div>
      </form>
    </div>
  </div>

  {{-- Ventana: editar deuda (lo pagado no se edita a mano) --}}
  <div class="modal fade" id="modalEditar" tabindex="-1" aria-labelledby="modalEditarLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" id="formEditar" action="#" method="POST">
        @csrf
        @method('PUT')
        <div class="modal-header">
          <h5 class="modal-title" id="modalEditarLabel">Editar deuda</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div class="mb-3">
            <label class="form-label" for="editar_nombre">Nombre de la deuda</label>
            <input type="text" id="editar_nombre" name="nombre_deuda" class="form-control-custom" maxlength="80" required>
          </div>
          <div class="mb-3">
            <label class="form-label" for="editar_acreedor">A quién se le debe</label>
            <input type="text" id="editar_acreedor" name="acreedor" class="form-control-custom" maxlength="80" required>
          </div>
          <div class="row g-3">
            <div class="col-6">
              <label class="form-label" for="editar_total">Monto total (₡)</label>
              <input type="number" id="editar_total" name="monto_total" class="form-control-custom" min="0.01" step="0.01" required>
            </div>
            <div class="col-6">
              <label class="form-label" for="editar_fecha">Vence</label>
              <input type="date" id="editar_fecha" name="fecha_vencimiento" class="form-control-custom"
                min="{{ date('Y-m-d', strtotime('+1 day')) }}">
            </div>
          </div>
          <p class="small text-muted mt-3 mb-0">Lo pagado cambia solo con los pagos.</p>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn-dark-custom">Guardar cambios</button>
        </div>
      </form>
    </div>
  </div>

  {{-- Ventana: pagar una deuda --}}
  <div class="modal fade" id="modalPagar" tabindex="-1" aria-labelledby="modalPagarLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" id="formPagar" action="#" method="POST">
        @csrf
        <div class="modal-header">
          <h5 class="modal-title" id="modalPagarLabel">Pagar deuda</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <p class="mb-3">Deuda: <strong id="pagar_deuda"></strong><br>
            <span class="small text-muted">Faltan ₡<span id="pagar_pendiente"></span></span></p>
          @if ($cuentas->isEmpty())
            <div class="alert alert-warning mb-0">
              No tienes cuentas en colones (que no sean tarjeta) para pagar. Crea una en el módulo de Cuentas.
            </div>
          @else
            <div class="mb-3">
              <label class="form-label" for="pagar_cuenta">Desde la cuenta</label>
              <select id="pagar_cuenta" name="id_cuenta" class="form-control-custom" required>
                @foreach ($cuentas as $c)
                  <option value="{{ $c->id_cuenta }}">{{ $c->nombre_cuenta }} — ₡{{ number_format((float) $c->saldo, 2, ',', '.') }}</option>
                @endforeach
              </select>
            </div>
            <div>
              <label class="form-label" for="pagar_monto">Monto (₡)</label>
              <input type="number" id="pagar_monto" name="monto" class="form-control-custom" min="0.01" step="0.01" required>
            </div>
          @endif
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          @unless ($cuentas->isEmpty())
            <button type="submit" class="btn-dark-custom">Pagar</button>
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
      f.querySelector('[name=nombre_deuda]').value = b.dataset.nombre;
      f.querySelector('[name=acreedor]').value = b.dataset.acreedor;
      f.querySelector('[name=monto_total]').value = b.dataset.total;
      f.querySelector('[name=fecha_vencimiento]').value = b.dataset.fecha;
    });

    document.getElementById('modalPagar').addEventListener('show.bs.modal', function (e) {
      var b = e.relatedTarget, f = document.getElementById('formPagar');
      f.action = b.dataset.url;
      document.getElementById('pagar_deuda').textContent = b.dataset.nombre;
      document.getElementById('pagar_pendiente').textContent =
        Number(b.dataset.pendiente).toLocaleString('es-CR', { minimumFractionDigits: 2 });
      var m = f.querySelector('[name=monto]');
      if (m) { m.max = b.dataset.pendiente; m.value = ''; }
    });
  </script>
  @if ($reabrir)
    <script>new bootstrap.Modal(document.getElementById('modalCrear')).show();</script>
  @endif
@endpush