@extends('layouts.app')

@section('title', 'Cuentas')
@section('page-title', 'Cuentas')
@section('page-subtitle', 'Administra tus cuentas de efectivo, bancos y tarjetas.')

@section('page-actions')
  <button type="button" class="btn-dark-custom" data-bs-toggle="modal" data-bs-target="#modalCrear">
    <span class="icon-wrap"><i class="bi bi-plus-lg"></i></span>
    Nueva cuenta
  </button>
@endsection

@section('content')
  @php
    $simbolo = ['CRC' => '₡', 'USD' => '$'];
    $iconos  = ['EFECTIVO' => 'bi-cash-stack', 'BANCO' => 'bi-bank', 'TARJETA' => 'bi-credit-card'];
    $tipos   = ['EFECTIVO' => 'Efectivo', 'BANCO' => 'Banco', 'TARJETA' => 'Tarjeta'];
    $totales = $cuentas->where('estado', 'ACTIVA')->groupBy('moneda')->map(fn ($g) => $g->sum('saldo'));
  @endphp

  @if (session('error'))
    <div class="alert alert-danger" role="alert">{{ session('error') }}</div>
  @endif

  @if ($errors->any())
    <div class="alert alert-danger" role="alert">
      @foreach ($errors->all() as $error)
        <div>{{ $error }}</div>
      @endforeach
    </div>
  @endif

  {{-- Resumen de saldos de las cuentas activas --}}
  <div class="row g-3 mb-2">
    @foreach (['CRC' => 'Saldo total en colones', 'USD' => 'Saldo total en dólares'] as $moneda => $titulo)
      <div class="col-md-6">
        <div class="card card-stat">
          <div class="stat-label">{{ $titulo }}</div>
          <div class="stat-value mb-0">
            {{ $simbolo[$moneda] }}{{ number_format((float) ($totales[$moneda] ?? 0), 2, ',', '.') }}
          </div>
        </div>
      </div>
    @endforeach
  </div>

  {{-- Lista de cuentas --}}
  <div class="table-card-custom">
    @if ($cuentas->isEmpty())
      <div class="text-center py-5">
        <div class="mb-3"><i class="bi bi-bank" style="font-size: 3rem;"></i></div>
        <h2 class="card-title mb-2">Aún no tienes cuentas</h2>
        <p class="mb-0">Crea la primera con el botón "Nueva cuenta".</p>
      </div>
    @else
      <div class="table-responsive">
        <table class="table-custom">
          <thead>
            <tr>
              <th>Cuenta</th>
              <th>Tipo</th>
              <th>Moneda</th>
              <th class="text-end">Saldo</th>
              <th>Estado</th>
              <th class="text-end">Acciones</th>
            </tr>
          </thead>
          <tbody>
            @foreach ($cuentas as $c)
              <tr style="{{ $c->estado === 'CERRADA' ? 'opacity: .6;' : '' }}">
                <td>
                  <div class="table-user-cell">
                    <i class="bi {{ $iconos[$c->tipo_cuenta] ?? 'bi-bank' }}" style="font-size: 1.4rem;"></i>
                    <span class="table-user-name">{{ $c->nombre_cuenta }}</span>
                  </div>
                </td>
                <td>{{ $tipos[$c->tipo_cuenta] ?? $c->tipo_cuenta }}</td>
                <td>{{ $c->moneda }}</td>
                <td class="text-end fw-bold {{ $c->saldo < 0 ? 'text-danger' : '' }}">
                  {{ $simbolo[$c->moneda] ?? '' }}{{ number_format((float) $c->saldo, 2, ',', '.') }}
                </td>
                <td>
                  <span class="badge-table {{ $c->estado === 'ACTIVA' ? 'success' : 'failed' }}">
                    {{ $c->estado === 'ACTIVA' ? 'Activa' : 'Cerrada' }}
                  </span>
                </td>
                <td class="text-end">
                  <div class="d-inline-flex gap-1">
                    <button type="button" class="btn btn-sm btn-light border" title="Editar"
                      data-bs-toggle="modal" data-bs-target="#modalEditar"
                      data-url="{{ route('cuentas.update', $c->id_cuenta) }}"
                      data-nombre="{{ $c->nombre_cuenta }}"
                      data-tipo="{{ $c->tipo_cuenta }}"
                      data-moneda="{{ $c->moneda }}">
                      <i class="bi bi-pencil"></i>
                    </button>

                    <form action="{{ route('cuentas.estado', $c->id_cuenta) }}" method="POST">
                      @csrf
                      @method('PATCH')
                      <input type="hidden" name="estado" value="{{ $c->estado === 'ACTIVA' ? 'CERRADA' : 'ACTIVA' }}">
                      <button type="submit" class="btn btn-sm btn-light border"
                        title="{{ $c->estado === 'ACTIVA' ? 'Cerrar cuenta' : 'Reabrir cuenta' }}">
                        <i class="bi {{ $c->estado === 'ACTIVA' ? 'bi-lock' : 'bi-unlock' }}"></i>
                      </button>
                    </form>

                    <form action="{{ route('cuentas.destroy', $c->id_cuenta) }}" method="POST"
                      onsubmit="return confirm('¿Eliminar esta cuenta? Esta acción no se puede deshacer.')">
                      @csrf
                      @method('DELETE')
                      <button type="submit" class="btn btn-sm btn-light border text-danger" title="Eliminar">
                        <i class="bi bi-trash"></i>
                      </button>
                    </form>
                  </div>
                </td>
              </tr>
            @endforeach
          </tbody>
        </table>
      </div>
    @endif
  </div>

  {{-- Ventana: nueva cuenta --}}
  <div class="modal fade" id="modalCrear" tabindex="-1" aria-labelledby="modalCrearLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" action="{{ route('cuentas.store') }}" method="POST">
        @csrf
        <div class="modal-header">
          <h5 class="modal-title" id="modalCrearLabel">Nueva cuenta</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div class="mb-3">
            <label class="form-label" for="crear_nombre">Nombre de la cuenta</label>
            <input type="text" id="crear_nombre" name="nombre_cuenta" class="form-control-custom"
              maxlength="60" required placeholder="Ej. Cuenta de ahorros BAC">
          </div>
          <div class="row g-3">
            <div class="col-6">
              <label class="form-label" for="crear_tipo">Tipo</label>
              <select id="crear_tipo" name="tipo_cuenta" class="form-control-custom" required>
                <option value="EFECTIVO">Efectivo</option>
                <option value="BANCO">Banco</option>
                <option value="TARJETA">Tarjeta</option>
              </select>
            </div>
            <div class="col-6">
              <label class="form-label" for="crear_moneda">Moneda</label>
              <select id="crear_moneda" name="moneda" class="form-control-custom" required>
                <option value="CRC">Colones (₡)</option>
                <option value="USD">Dólares ($)</option>
              </select>
            </div>
          </div>
          <div class="mt-3">
            <label class="form-label" for="crear_saldo">Saldo inicial</label>
            <input type="number" id="crear_saldo" name="saldo_inicial" class="form-control-custom"
              min="0" step="0.01" value="0">
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn-dark-custom">Crear cuenta</button>
        </div>
      </form>
    </div>
  </div>

  {{-- Ventana: editar cuenta (el saldo no se edita a mano) --}}
  <div class="modal fade" id="modalEditar" tabindex="-1" aria-labelledby="modalEditarLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" id="formEditar" action="#" method="POST">
        @csrf
        @method('PUT')
        <div class="modal-header">
          <h5 class="modal-title" id="modalEditarLabel">Editar cuenta</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div class="mb-3">
            <label class="form-label" for="editar_nombre">Nombre de la cuenta</label>
            <input type="text" id="editar_nombre" name="nombre_cuenta" class="form-control-custom"
              maxlength="60" required>
          </div>
          <div class="row g-3">
            <div class="col-6">
              <label class="form-label" for="editar_tipo">Tipo</label>
              <select id="editar_tipo" name="tipo_cuenta" class="form-control-custom" required>
                <option value="EFECTIVO">Efectivo</option>
                <option value="BANCO">Banco</option>
                <option value="TARJETA">Tarjeta</option>
              </select>
            </div>
            <div class="col-6">
              <label class="form-label" for="editar_moneda">Moneda</label>
              <select id="editar_moneda" name="moneda" class="form-control-custom" required>
                <option value="CRC">Colones (₡)</option>
                <option value="USD">Dólares ($)</option>
              </select>
            </div>
          </div>
          <p class="small text-muted mt-3 mb-0">
            El saldo no se edita aquí: cambia solo con los movimientos y las transferencias.
          </p>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn-dark-custom">Guardar cambios</button>
        </div>
      </form>
    </div>
  </div>
@endsection

@push('scripts')
  <script>
    // Al abrir la ventana de editar, se llenan los campos con los datos de la fila
    document.getElementById('modalEditar').addEventListener('show.bs.modal', function (e) {
      var b = e.relatedTarget;
      var f = document.getElementById('formEditar');
      f.action = b.dataset.url;
      f.querySelector('[name=nombre_cuenta]').value = b.dataset.nombre;
      f.querySelector('[name=tipo_cuenta]').value = b.dataset.tipo;
      f.querySelector('[name=moneda]').value = b.dataset.moneda;
    });
  </script>
@endpush