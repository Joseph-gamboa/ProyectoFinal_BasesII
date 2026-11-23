@extends('layouts.app')

@section('title', 'Transferencias')
@section('page-title', 'Transferencias')
@section('page-subtitle', 'Mueve dinero entre tus propias cuentas.')

@section('page-actions')
  <button type="button" class="btn-dark-custom" data-bs-toggle="modal" data-bs-target="#modalCrear">
    <span class="icon-wrap"><i class="bi bi-plus-lg"></i></span>
    Nueva transferencia
  </button>
@endsection

@section('content')
  @php
    $simbolo = ['CRC' => '₡', 'USD' => '$'];
    $reabrir = $errors->any() || session('error');
  @endphp

  @include('partials.alertas')

  <div class="table-card-custom">
    @if ($transferencias->isEmpty())
      <div class="text-center py-5">
        <div class="mb-3"><i class="bi bi-arrow-left-right" style="font-size: 3rem;"></i></div>
        <h2 class="card-title mb-2">Aún no tienes transferencias</h2>
        <p class="mb-0">Crea la primera con el botón "Nueva transferencia".</p>
      </div>
    @else
      <div class="table-responsive">
        <table class="table-custom">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Origen</th>
              <th>Destino</th>
              <th>Descripción</th>
              <th class="text-end">Monto</th>
            </tr>
          </thead>
          <tbody>
            @foreach ($transferencias as $t)
              <tr>
                <td>{{ \Illuminate\Support\Carbon::parse($t->fecha)->format('d/m/Y H:i') }}</td>
                <td><span class="table-user-name">{{ $t->origen }}</span></td>
                <td><span class="table-user-name">{{ $t->destino }}</span></td>
                <td>{{ $t->descripcion ?: '—' }}</td>
                <td class="text-end fw-bold">{{ $simbolo[$t->moneda] ?? '' }}{{ number_format((float) $t->monto, 2, ',', '.') }}</td>
              </tr>
            @endforeach
          </tbody>
        </table>
      </div>
      <div class="p-3">{{ $transferencias->links() }}</div>
    @endif
  </div>

  {{-- Ventana: nueva transferencia --}}
  <div class="modal fade" id="modalCrear" tabindex="-1" aria-labelledby="modalCrearLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" action="{{ route('transferencias.store') }}" method="POST">
        @csrf
        <div class="modal-header">
          <h5 class="modal-title" id="modalCrearLabel">Nueva transferencia</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div class="row g-3">
            <div class="col-md-6">
              <label class="form-label" for="id_cuenta_origen">Cuenta de origen</label>
              <select id="id_cuenta_origen" name="id_cuenta_origen" class="form-control-custom" required>
                <option value="">Seleccione…</option>
                @foreach ($cuentas as $c)
                  <option value="{{ $c->id_cuenta }}" @selected(old('id_cuenta_origen') == $c->id_cuenta)>
                    {{ $c->nombre_cuenta }} ({{ $c->moneda }})
                  </option>
                @endforeach
              </select>
            </div>
            <div class="col-md-6">
              <label class="form-label" for="id_cuenta_destino">Cuenta de destino</label>
              <select id="id_cuenta_destino" name="id_cuenta_destino" class="form-control-custom" required>
                <option value="">Seleccione…</option>
                @foreach ($cuentas as $c)
                  <option value="{{ $c->id_cuenta }}" @selected(old('id_cuenta_destino') == $c->id_cuenta)>
                    {{ $c->nombre_cuenta }} ({{ $c->moneda }})
                  </option>
                @endforeach
              </select>
            </div>
            <div class="col-12">
              <label class="form-label" for="monto">Monto</label>
              <input type="number" id="monto" name="monto" class="form-control-custom"
                min="0.01" step="0.01" value="{{ old('monto') }}" required>
              <div class="small text-muted mt-1">Las dos cuentas deben tener la misma moneda; no se hace conversión.</div>
            </div>
            <div class="col-12">
              <label class="form-label" for="descripcion">Descripción (opcional)</label>
              <input type="text" id="descripcion" name="descripcion" class="form-control-custom"
                maxlength="150" value="{{ old('descripcion') }}">
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn-dark-custom">Transferir</button>
        </div>
      </form>
    </div>
  </div>
@endsection

@push('scripts')
  @if ($reabrir)
    <script>new bootstrap.Modal(document.getElementById('modalCrear')).show();</script>
  @endif
@endpush
