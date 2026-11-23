@extends('layouts.app')

@section('title', 'Reportes')
@section('page-title', 'Reportes')
@section('page-subtitle', 'Resumen financiero mensual.')

@section('page-actions')
  <button type="button" class="btn-dark-custom" onclick="window.print()">
    <span class="icon-wrap"><i class="bi bi-printer"></i></span>
    Imprimir
  </button>
@endsection

@section('content')
  @php
    $meses = [1 => 'Enero', 2 => 'Febrero', 3 => 'Marzo', 4 => 'Abril', 5 => 'Mayo', 6 => 'Junio',
              7 => 'Julio', 8 => 'Agosto', 9 => 'Septiembre', 10 => 'Octubre', 11 => 'Noviembre', 12 => 'Diciembre'];
    $simbolo = ['CRC' => '₡', 'USD' => '$'];
    $fmt = fn ($n) => number_format((float) $n, 2, ',', '.');
    $alertas = [
      'OK'               => ['En orden', 'success'],
      'CERCA_DEL_LIMITE' => ['Cerca del límite', 'pending'],
      'EXCEDIDO'         => ['Excedido', 'failed'],
      'SIN_PRESUPUESTO'  => ['Sin presupuesto', 'pending'],
    ];
    $estadosMeta = ['EN_CURSO' => 'En curso', 'CUMPLIDA' => 'Cumplida', 'CANCELADA' => 'Cancelada'];
  @endphp

  <form method="GET" class="row g-2 align-items-end mb-3 d-print-none">
    <div class="col-md-4">
      <label class="form-label" for="mes">Mes</label>
      <select id="mes" name="mes" class="form-control-custom">
        @foreach ($meses as $n => $nombre)
          <option value="{{ $n }}" @selected($mes === $n)>{{ $nombre }}</option>
        @endforeach
      </select>
    </div>
    <div class="col-md-3">
      <label class="form-label" for="anio">Año</label>
      <input type="number" id="anio" name="anio" class="form-control-custom" min="2000" max="2100" value="{{ $anio }}">
    </div>
    <div class="col-md-2">
      <button type="submit" class="btn btn-light border w-100">Ver reporte</button>
    </div>
  </form>

  @if ($error)
    <div class="alert alert-danger" role="alert">{{ $error }}</div>
  @endif
  @include('partials.alertas')

  <h2 class="card-title mb-3">{{ $meses[$mes] }} {{ $anio }}</h2>

  {{-- 1) Balance del mes por moneda --}}
  <div class="row g-3 mb-4">
    @forelse ($balances as $b)
      <div class="col-lg-6">
        <div class="card card-stat">
          <div class="stat-label">Balance en {{ $b->moneda === 'CRC' ? 'colones' : 'dólares' }} ({{ $b->cantidad_movimientos }} movimientos)</div>
          <div class="stat-value {{ $b->balance_del_mes < 0 ? 'text-danger' : '' }}">
            {{ $simbolo[$b->moneda] ?? '' }}{{ $fmt($b->balance_del_mes) }}
          </div>
          <div class="small">
            <span class="text-success">Ingresos: {{ $simbolo[$b->moneda] ?? '' }}{{ $fmt($b->total_ingresos) }}</span>
            &nbsp;·&nbsp;
            <span class="text-danger">Gastos: {{ $simbolo[$b->moneda] ?? '' }}{{ $fmt($b->total_gastos) }}</span>
          </div>
        </div>
      </div>
    @empty
      <div class="col-12"><p class="text-muted mb-0">No hay movimientos ni cuentas para este periodo.</p></div>
    @endforelse
  </div>

  {{-- 2) Gastos por categoría contra presupuesto --}}
  <div class="table-card-custom mb-4">
    <div class="p-3 pb-0"><h2 class="card-title">Gastos por categoría (cuentas en colones)</h2></div>
    @if (count($presupuestos) === 0)
      <p class="p-3 mb-0 text-muted">No hay gastos en colones en este mes.</p>
    @else
      <div class="table-responsive">
        <table class="table-custom">
          <thead>
            <tr>
              <th>Categoría</th>
              <th class="text-end">Gastado</th>
              <th class="text-end">Presupuesto</th>
              <th class="text-end">Uso</th>
              <th>Estado</th>
            </tr>
          </thead>
          <tbody>
            @foreach ($presupuestos as $p)
              @php [$texto, $clase] = $alertas[$p->alerta] ?? [$p->alerta, 'pending']; @endphp
              <tr>
                <td><span class="table-user-name">{{ $p->nombre_categoria }}</span></td>
                <td class="text-end">₡{{ $fmt($p->total_gastado) }}</td>
                <td class="text-end">{{ $p->presupuesto !== null ? '₡' . $fmt($p->presupuesto) : '—' }}</td>
                <td class="text-end">{{ $p->porcentaje_presupuesto !== null ? number_format((float) $p->porcentaje_presupuesto, 1, ',', '.') . '%' : '—' }}</td>
                <td><span class="badge-table {{ $clase }}">{{ $texto }}</span></td>
              </tr>
            @endforeach
          </tbody>
        </table>
      </div>
    @endif
  </div>

  <div class="row g-3">
    {{-- 3) Saldos actuales --}}
    <div class="col-lg-6">
      <div class="table-card-custom h-100">
        <div class="p-3 pb-0"><h2 class="card-title">Saldos actuales</h2></div>
        @if (count($cuentas) === 0)
          <p class="p-3 mb-0 text-muted">No tienes cuentas activas.</p>
        @else
          <div class="table-responsive">
            <table class="table-custom">
              <thead><tr><th>Cuenta</th><th>Tipo</th><th class="text-end">Saldo</th></tr></thead>
              <tbody>
                @foreach ($cuentas as $c)
                  <tr>
                    <td><span class="table-user-name">{{ $c->nombre_cuenta }}</span></td>
                    <td>{{ ucfirst(strtolower($c->tipo_cuenta)) }}</td>
                    <td class="text-end fw-bold {{ $c->saldo < 0 ? 'text-danger' : '' }}">{{ $simbolo[$c->moneda] ?? '' }}{{ $fmt($c->saldo) }}</td>
                  </tr>
                @endforeach
              </tbody>
            </table>
          </div>
        @endif
      </div>
    </div>

    {{-- 4) Metas de ahorro --}}
    <div class="col-lg-6">
      <div class="table-card-custom h-100">
        <div class="p-3 pb-0"><h2 class="card-title">Metas de ahorro</h2></div>
        @if (count($metas) === 0)
          <p class="p-3 mb-0 text-muted">No tienes metas de ahorro.</p>
        @else
          <div class="table-responsive">
            <table class="table-custom">
              <thead><tr><th>Meta</th><th class="text-end">Avance</th><th class="text-end">Aportado en el mes</th><th>Estado</th></tr></thead>
              <tbody>
                @foreach ($metas as $m)
                  <tr>
                    <td><span class="table-user-name">{{ $m->nombre_meta }}</span></td>
                    <td class="text-end">{{ number_format((float) $m->porcentaje_avance, 1, ',', '.') }}%</td>
                    <td class="text-end">₡{{ $fmt($m->aportado_en_el_mes) }}</td>
                    <td>{{ $estadosMeta[$m->estado] ?? $m->estado }}</td>
                  </tr>
                @endforeach
              </tbody>
            </table>
          </div>
        @endif
      </div>
    </div>
  </div>
@endsection
