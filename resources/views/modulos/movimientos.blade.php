{{-- Pantalla compartida de Ingresos y Gastos (la variable $t trae los textos) --}}
@extends('layouts.app')

@section('title', $t['titulo'])
@section('page-title', $t['titulo'])
@section('page-subtitle', $t['subtitulo'])

@section('page-actions')
  <button type="button" class="btn-dark-custom" data-bs-toggle="modal" data-bs-target="#modalCrear">
    <span class="icon-wrap"><i class="bi bi-plus-lg"></i></span>
    {{ $t['boton_nuevo'] }}
  </button>
@endsection

@section('content')
  @php
    $simbolo  = ['CRC' => '₡', 'USD' => '$'];
    $esGasto  = $tipo === 'GASTO';
    $metodos  = ['EFECTIVO' => 'Efectivo', 'TARJETA' => 'Tarjeta', 'TRANSFERENCIA' => 'Transferencia'];
    $cuentasActivas = $cuentas->where('estado', 'ACTIVA');
    $reabrir = ($errors->any() || session('error')) && old('_form') === 'crear';
  @endphp

  @include('partials.alertas')

  {{-- Total del mes en curso --}}
  <div class="row g-3 mb-2">
    @foreach (['CRC' => 'colones', 'USD' => 'dólares'] as $moneda => $nombre)
      <div class="col-md-6">
        <div class="card card-stat">
          <div class="stat-label">{{ $t['titulo'] }} del mes en {{ $nombre }}</div>
          <div class="stat-value mb-0">
            {{ $simbolo[$moneda] }}{{ number_format((float) ($totalesMes[$moneda] ?? 0), 2, ',', '.') }}
          </div>
        </div>
      </div>
    @endforeach
  </div>

  {{-- Filtros --}}
  <form method="GET" class="row g-2 align-items-end mb-3">
    <div class="col-md-4">
      <label class="form-label" for="f_cuenta">Cuenta</label>
      <select id="f_cuenta" name="id_cuenta" class="form-control-custom">
        <option value="">Todas</option>
        @foreach ($cuentas as $c)
          <option value="{{ $c->id_cuenta }}" @selected(($filtros['id_cuenta'] ?? '') == $c->id_cuenta)>
            {{ $c->nombre_cuenta }} ({{ $c->moneda }})
          </option>
        @endforeach
      </select>
    </div>
    <div class="col-md-3">
      <label class="form-label" for="f_desde">Desde</label>
      <input type="date" id="f_desde" name="desde" class="form-control-custom" value="{{ $filtros['desde'] ?? '' }}">
    </div>
    <div class="col-md-3">
      <label class="form-label" for="f_hasta">Hasta</label>
      <input type="date" id="f_hasta" name="hasta" class="form-control-custom" value="{{ $filtros['hasta'] ?? '' }}">
    </div>
    <div class="col-md-2 d-flex gap-1">
      <button type="submit" class="btn btn-light border w-100">Filtrar</button>
      <a href="{{ route($modulo . '.index') }}" class="btn btn-light border" title="Quitar filtros"><i class="bi bi-x-lg"></i></a>
    </div>
  </form>

  {{-- Historial --}}
  <div class="table-card-custom">
    @if ($movimientos->isEmpty())
      <div class="text-center py-5">
        <div class="mb-3"><i class="bi {{ $t['icono'] }}" style="font-size: 3rem;"></i></div>
        <h2 class="card-title mb-2">{{ $t['vacio'] }}</h2>
        <p class="mb-0">Crea el primero con el botón "{{ $t['boton_nuevo'] }}".</p>
      </div>
    @else
      <div class="table-responsive">
        <table class="table-custom">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>{{ $t['etiqueta'] }}</th>
              <th>Categoría</th>
              <th>Cuenta</th>
              @if ($esGasto)<th>Método</th>@endif
              <th>Descripción</th>
              <th class="text-end">Monto</th>
              <th>Estado</th>
              <th class="text-end">Acciones</th>
            </tr>
          </thead>
          <tbody>
            @foreach ($movimientos as $m)
              @php $anulado = $m->estado === 'ANULADO'; @endphp
              <tr style="{{ $anulado ? 'opacity: .55;' : '' }}">
                <td>{{ \Illuminate\Support\Carbon::parse($m->fecha)->format('d/m/Y') }}</td>
                <td><span class="table-user-name">{{ $m->detalle }}</span></td>
                <td>{{ $m->nombre_categoria }}</td>
                <td>{{ $m->nombre_cuenta }}</td>
                @if ($esGasto)<td>{{ $metodos[$m->metodo_pago] ?? $m->metodo_pago }}</td>@endif
                <td>{{ $m->descripcion ?: '—' }}</td>
                <td class="text-end fw-bold {{ $esGasto ? '' : 'text-success' }}" @if($anulado) style="text-decoration: line-through;" @endif>
                  {{ $esGasto ? '-' : '+' }}{{ $simbolo[$m->moneda] ?? '' }}{{ number_format((float) $m->monto, 2, ',', '.') }}
                </td>
                <td>
                  <span class="badge-table {{ $anulado ? 'failed' : 'success' }}">{{ $anulado ? 'Anulado' : 'Activo' }}</span>
                </td>
                <td class="text-end">
                  @unless ($anulado)
                    <form action="{{ route($modulo . '.destroy', $m->id_movimiento) }}" method="POST"
                      onsubmit="return confirm('¿Anular este {{ $t['singular'] }}? El saldo de la cuenta se ajustará.')">
                      @csrf
                      @method('DELETE')
                      <button type="submit" class="btn btn-sm btn-light border text-danger" title="Anular">
                        <i class="bi bi-x-circle"></i>
                      </button>
                    </form>
                  @endunless
                </td>
              </tr>
            @endforeach
          </tbody>
        </table>
      </div>

      <div class="p-3">{{ $movimientos->links() }}</div>
    @endif
  </div>

  {{-- Ventana: nuevo movimiento --}}
  <div class="modal fade" id="modalCrear" tabindex="-1" aria-labelledby="modalCrearLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" action="{{ route($modulo . '.store') }}" method="POST">
        @csrf
        <input type="hidden" name="_form" value="crear">
        <div class="modal-header">
          <h5 class="modal-title" id="modalCrearLabel">{{ $t['boton_nuevo'] }}</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div class="row g-3">
            <div class="col-md-6">
              <label class="form-label" for="id_cuenta">Cuenta</label>
              <select id="id_cuenta" name="id_cuenta" class="form-control-custom" required>
                <option value="">Seleccione…</option>
                @foreach ($cuentasActivas as $c)
                  <option value="{{ $c->id_cuenta }}" @selected(old('id_cuenta') == $c->id_cuenta)>
                    {{ $c->nombre_cuenta }} ({{ $c->moneda }})
                  </option>
                @endforeach
              </select>
            </div>
            <div class="col-md-6">
              <label class="form-label" for="id_categoria">Categoría</label>
              <select id="id_categoria" name="id_categoria" class="form-control-custom" required>
                <option value="">Seleccione…</option>
                @foreach ($categorias as $cat)
                  <option value="{{ $cat->id_categoria }}" @selected(old('id_categoria') == $cat->id_categoria)>
                    {{ $cat->nombre_categoria }}
                  </option>
                @endforeach
              </select>
            </div>
            <div class="col-md-6">
              <label class="form-label" for="monto">Monto</label>
              <input type="number" id="monto" name="monto" class="form-control-custom"
                min="0.01" step="0.01" value="{{ old('monto') }}" required>
            </div>
            <div class="col-md-6">
              <label class="form-label" for="fecha">Fecha</label>
              <input type="date" id="fecha" name="fecha" class="form-control-custom"
                max="{{ date('Y-m-d') }}" value="{{ old('fecha', date('Y-m-d')) }}">
            </div>

            @if ($esGasto)
              <div class="col-md-6">
                <label class="form-label" for="comercio">Comercio</label>
                <input type="text" id="comercio" name="comercio" class="form-control-custom"
                  maxlength="80" value="{{ old('comercio') }}" placeholder="{{ $t['placeholder'] }}" required>
              </div>
              <div class="col-md-6">
                <label class="form-label" for="metodo_pago">Método de pago</label>
                <select id="metodo_pago" name="metodo_pago" class="form-control-custom" required>
                  @foreach ($metodos as $valor => $texto)
                    <option value="{{ $valor }}" @selected(old('metodo_pago') === $valor)>{{ $texto }}</option>
                  @endforeach
                </select>
              </div>
            @else
              <div class="col-12">
                <label class="form-label" for="fuente">Fuente</label>
                <input type="text" id="fuente" name="fuente" class="form-control-custom"
                  maxlength="80" value="{{ old('fuente') }}" placeholder="{{ $t['placeholder'] }}" required>
              </div>
            @endif

            <div class="col-12">
              <label class="form-label" for="descripcion">Descripción (opcional)</label>
              <input type="text" id="descripcion" name="descripcion" class="form-control-custom"
                maxlength="150" value="{{ old('descripcion') }}">
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn-dark-custom">Guardar</button>
        </div>
      </form>
    </div>
  </div>
@endsection

@push('scripts')
  @if ($reabrir)
    <script>
      // Si el formulario falló, se vuelve a abrir con lo que el usuario escribió
      new bootstrap.Modal(document.getElementById('modalCrear')).show();
    </script>
  @endif
@endpush
