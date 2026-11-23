@extends('layouts.app')

@section('title', 'Presupuestos')
@section('page-title', 'Presupuestos')
@section('page-subtitle', 'Límites de gasto por categoría y mes.')

@section('page-actions')
  <button type="button" class="btn-dark-custom" data-bs-toggle="modal" data-bs-target="#modalCrear">
    <span class="icon-wrap"><i class="bi bi-plus-lg"></i></span>
    Nuevo presupuesto
  </button>
@endsection

@section('content')
  @php
    $meses = [1 => 'Enero', 2 => 'Febrero', 3 => 'Marzo', 4 => 'Abril', 5 => 'Mayo', 6 => 'Junio',
              7 => 'Julio', 8 => 'Agosto', 9 => 'Septiembre', 10 => 'Octubre', 11 => 'Noviembre', 12 => 'Diciembre'];
    $reabrir = ($errors->any() || session('error')) && old('_form') === 'crear';
    $anioActual = (int) date('Y');
  @endphp

  @include('partials.alertas')

  {{-- Filtro por periodo --}}
  <form method="GET" class="row g-2 align-items-end mb-3">
    <div class="col-md-4">
      <label class="form-label" for="f_mes">Mes</label>
      <select id="f_mes" name="mes" class="form-control-custom">
        <option value="">Todos</option>
        @foreach ($meses as $n => $nombre)
          <option value="{{ $n }}" @selected($mes === $n)>{{ $nombre }}</option>
        @endforeach
      </select>
    </div>
    <div class="col-md-3">
      <label class="form-label" for="f_anio">Año</label>
      <input type="number" id="f_anio" name="anio" class="form-control-custom" min="2000" max="2100"
        value="{{ $anio }}" placeholder="Todos">
    </div>
    <div class="col-md-3 d-flex gap-1">
      <button type="submit" class="btn btn-light border w-100">Filtrar</button>
      <a href="{{ route('presupuestos.index') }}" class="btn btn-light border" title="Mes actual"><i class="bi bi-x-lg"></i></a>
    </div>
  </form>

  <div class="table-card-custom">
    @if ($presupuestos->isEmpty())
      <div class="text-center py-5">
        <div class="mb-3"><i class="bi bi-pie-chart" style="font-size: 3rem;"></i></div>
        <h2 class="card-title mb-2">No hay presupuestos en este periodo</h2>
        <p class="mb-0">Crea uno con el botón "Nuevo presupuesto".</p>
      </div>
    @else
      <div class="table-responsive">
        <table class="table-custom">
          <thead>
            <tr>
              <th>Categoría</th>
              <th>Periodo</th>
              <th class="text-end">Límite</th>
              <th class="text-end">Gastado</th>
              <th style="min-width: 160px;">Uso</th>
              <th>Estado</th>
              <th class="text-end">Acciones</th>
            </tr>
          </thead>
          <tbody>
            @foreach ($presupuestos as $p)
              @php
                $limite    = (float) $p->monto_limite;
                $gastado   = (float) $p->monto_gastado;
                $pct       = $limite > 0 ? round($gastado * 100 / $limite, 1) : 0;
                $excedido  = $gastado > $limite;
                $cerca     = ! $excedido && $gastado >= $limite * 0.8;
                $color     = $excedido ? 'bg-danger' : ($cerca ? 'bg-warning' : 'bg-success');
              @endphp
              <tr>
                <td><span class="table-user-name">{{ $p->nombre_categoria }}</span></td>
                <td>{{ $meses[$p->mes] }} {{ $p->anio }}</td>
                <td class="text-end">₡{{ number_format($limite, 2, ',', '.') }}</td>
                <td class="text-end fw-bold {{ $excedido ? 'text-danger' : '' }}">₡{{ number_format($gastado, 2, ',', '.') }}</td>
                <td>
                  <div class="progress" style="height: 8px;">
                    <div class="progress-bar {{ $color }}" style="width: {{ min($pct, 100) }}%"></div>
                  </div>
                  <small class="text-muted">{{ number_format($pct, 1, ',', '.') }}%</small>
                </td>
                <td>
                  <span class="badge-table {{ $excedido ? 'failed' : ($cerca ? 'pending' : 'success') }}">
                    {{ $excedido ? 'Excedido' : ($cerca ? 'Cerca del límite' : 'En orden') }}
                  </span>
                </td>
                <td class="text-end">
                  <div class="d-inline-flex gap-1">
                    <button type="button" class="btn btn-sm btn-light border" title="Editar"
                      data-bs-toggle="modal" data-bs-target="#modalEditar"
                      data-url="{{ route('presupuestos.update', $p->id_presupuesto) }}"
                      data-categoria="{{ $p->nombre_categoria }}"
                      data-monto="{{ $limite }}" data-mes="{{ $p->mes }}" data-anio="{{ $p->anio }}">
                      <i class="bi bi-pencil"></i>
                    </button>
                    <form action="{{ route('presupuestos.destroy', $p->id_presupuesto) }}" method="POST"
                      onsubmit="return confirm('¿Eliminar este presupuesto?')">
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
  <p class="small text-muted mt-2">Los presupuestos y el gasto se calculan sobre los gastos de todas tus cuentas.</p>

  {{-- Ventana: nuevo presupuesto --}}
  <div class="modal fade" id="modalCrear" tabindex="-1" aria-labelledby="modalCrearLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" action="{{ route('presupuestos.store') }}" method="POST">
        @csrf
        <input type="hidden" name="_form" value="crear">
        <div class="modal-header">
          <h5 class="modal-title" id="modalCrearLabel">Nuevo presupuesto</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <div class="row g-3">
            <div class="col-12">
              <label class="form-label" for="id_categoria">Categoría de gasto</label>
              <select id="id_categoria" name="id_categoria" class="form-control-custom" required>
                <option value="">Seleccione…</option>
                @foreach ($categorias as $c)
                  <option value="{{ $c->id_categoria }}" @selected(old('id_categoria') == $c->id_categoria)>{{ $c->nombre_categoria }}</option>
                @endforeach
              </select>
            </div>
            <div class="col-12">
              <label class="form-label" for="monto_limite">Monto límite (₡)</label>
              <input type="number" id="monto_limite" name="monto_limite" class="form-control-custom"
                min="0.01" step="0.01" value="{{ old('monto_limite') }}" required>
            </div>
            <div class="col-6">
              <label class="form-label" for="c_mes">Mes</label>
              <select id="c_mes" name="mes" class="form-control-custom" required>
                @foreach ($meses as $n => $nombre)
                  <option value="{{ $n }}" @selected((int) old('mes', date('n')) === $n)>{{ $nombre }}</option>
                @endforeach
              </select>
            </div>
            <div class="col-6">
              <label class="form-label" for="c_anio">Año</label>
              <input type="number" id="c_anio" name="anio" class="form-control-custom" min="2000" max="2100"
                value="{{ old('anio', $anioActual) }}" required>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
          <button type="submit" class="btn-dark-custom">Crear presupuesto</button>
        </div>
      </form>
    </div>
  </div>

  {{-- Ventana: editar presupuesto (la categoría no cambia) --}}
  <div class="modal fade" id="modalEditar" tabindex="-1" aria-labelledby="modalEditarLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
      <form class="modal-content" id="formEditar" action="#" method="POST">
        @csrf
        @method('PUT')
        <div class="modal-header">
          <h5 class="modal-title" id="modalEditarLabel">Editar presupuesto</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
        </div>
        <div class="modal-body">
          <p class="mb-3">Categoría: <strong id="editar_categoria"></strong></p>
          <div class="row g-3">
            <div class="col-12">
              <label class="form-label" for="editar_monto">Monto límite (₡)</label>
              <input type="number" id="editar_monto" name="monto_limite" class="form-control-custom" min="0.01" step="0.01" required>
            </div>
            <div class="col-6">
              <label class="form-label" for="editar_mes">Mes</label>
              <select id="editar_mes" name="mes" class="form-control-custom" required>
                @foreach ($meses as $n => $nombre)
                  <option value="{{ $n }}">{{ $nombre }}</option>
                @endforeach
              </select>
            </div>
            <div class="col-6">
              <label class="form-label" for="editar_anio">Año</label>
              <input type="number" id="editar_anio" name="anio" class="form-control-custom" min="2000" max="2100" required>
            </div>
          </div>
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
    document.getElementById('modalEditar').addEventListener('show.bs.modal', function (e) {
      var b = e.relatedTarget, f = document.getElementById('formEditar');
      f.action = b.dataset.url;
      document.getElementById('editar_categoria').textContent = b.dataset.categoria;
      f.querySelector('[name=monto_limite]').value = b.dataset.monto;
      f.querySelector('[name=mes]').value = b.dataset.mes;
      f.querySelector('[name=anio]').value = b.dataset.anio;
    });
  </script>
  @if ($reabrir)
    <script>new bootstrap.Modal(document.getElementById('modalCrear')).show();</script>
  @endif
@endpush
