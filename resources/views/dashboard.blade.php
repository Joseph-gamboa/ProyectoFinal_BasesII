@extends('layouts.app')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard')
@section('page-subtitle', 'Resumen general de tus finanzas personales.')

@section('page-actions')
  <span class="btn-date-picker">
    <i class="bi bi-calendar4-event"></i>
    <span>{{ $mesActual }}</span>
  </span>
@endsection

@php
  $crc = fn ($n) => '₡' . number_format((float) $n, 0, ',', '.');
  $neto = $ingresosMes - $gastosMes;
@endphp

@section('content')
<div class="row g-4">

  {{-- Fila superior: indicadores --}}
  <div class="col-12">
    <div class="row g-4">
      <div class="col-md-4">
        <div class="card alert-green-card">
          <div class="position-relative z-index-2">
            <span class="alert-green-badge">Balance total</span>
            <div class="alert-green-date">Cuentas activas en colones</div>
            <div class="alert-green-text">{{ $crc($balance) }}</div>
          </div>
          <a href="{{ route('modulo', 'cuentas') }}" class="alert-green-link z-index-2">
            <span>Ver cuentas</span>
            <i class="bi bi-arrow-right"></i>
          </a>
          <svg class="alert-green-bg-shape" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
            <g transform="translate(50,50)">
              <rect x="-6" y="-45" width="12" height="90" rx="6" ry="6" fill="#B4F105" />
              <rect x="-6" y="-45" width="12" height="90" rx="6" ry="6" fill="#B4F105" transform="rotate(60)" />
              <rect x="-6" y="-45" width="12" height="90" rx="6" ry="6" fill="#B4F105" transform="rotate(120)" />
            </g>
          </svg>
        </div>
      </div>

      <div class="col-md-4">
        <div class="card card-stat d-flex flex-column justify-content-between">
          <div>
            <div class="card-header">
              <span class="stat-label">Ingresos del mes</span>
            </div>
            <div class="stat-value">{{ $crc($ingresosMes) }}</div>
            <div class="trend-badge trend-up">
              <i class="bi bi-arrow-down-left"></i>
              <span>Entradas confirmadas</span>
            </div>
          </div>
        </div>
      </div>

      <div class="col-md-4">
        <div class="card card-stat d-flex flex-column justify-content-between">
          <div>
            <div class="card-header">
              <span class="stat-label">Gastos del mes</span>
            </div>
            <div class="stat-value">{{ $crc($gastosMes) }}</div>
            <div class="trend-badge {{ $neto >= 0 ? 'trend-up' : 'trend-down' }}">
              <i class="bi {{ $neto >= 0 ? 'bi-arrow-up-right' : 'bi-arrow-down-left' }}"></i>
              <span>Balance del mes: {{ $crc($neto) }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  {{-- Columna principal --}}
  <div class="col-xl-9 col-lg-8">
    <div class="row g-4">

      <div class="col-12">
        <div class="card mb-0">
          <div class="card-header mb-2">
            <h2 class="card-title">Ingresos vs. gastos</h2>
            <div class="d-flex gap-3 align-items-center">
              <div class="chart-legend-item">
                <span class="legend-dot bg-forest-medium"></span>
                <span class="chart-legend-label">Ingresos</span>
              </div>
              <div class="chart-legend-item">
                <span class="legend-dot bg-lime-accent"></span>
                <span class="chart-legend-label">Gastos</span>
              </div>
            </div>
          </div>
          <div class="d-flex align-items-baseline gap-2 mb-3">
            <span class="stat-value-amount">{{ $crc($neto) }}</span>
            <span class="trend-badge {{ $neto >= 0 ? 'trend-up' : 'trend-down' }} fs-xs">balance de {{ $mesActual }}</span>
          </div>
          <div id="revenue-chart"></div>
        </div>
      </div>

      <div class="col-md-7 d-flex flex-column">
        <div class="card h-100 flex-grow-1">
          <div class="card-header">
            <h2 class="card-title">Últimos movimientos</h2>
          </div>
          <div class="transaction-list">
            @forelse ($ultimos as $mov)
              @php $esIngreso = $mov->tipo_transaccion === 'INGRESO'; @endphp
              <div class="transaction-item">
                <div class="transaction-icon bg-forest-light text-lime">
                  <i class="bi {{ $esIngreso ? 'bi-arrow-down-circle' : 'bi-arrow-up-circle' }}"></i>
                </div>
                <div class="transaction-info">
                  <div class="transaction-name">{{ $mov->descripcion ?: $mov->categoria }}</div>
                  <div class="transaction-date">{{ $mov->categoria }} • {{ \Carbon\Carbon::parse($mov->fecha)->format('d/m/Y') }}</div>
                </div>
                <div class="transaction-amount {{ $esIngreso ? 'text-success' : 'text-main' }}">
                  {{ $esIngreso ? '+' : '-' }}{{ $crc($mov->monto) }}
                </div>
              </div>
            @empty
              <p class="mb-0">Aún no hay movimientos registrados.</p>
            @endforelse
          </div>
        </div>
      </div>

      <div class="col-md-5 d-flex flex-column">
        <div class="card h-100 flex-grow-1">
          <div class="card-header">
            <h2 class="card-title">Gastos por categoría</h2>
          </div>
          @forelse ($porCategoria as $cat)
            @php $pct = $maxCategoria > 0 ? round($cat->total / $maxCategoria * 100) : 0; @endphp
            <div class="progress-container">
              <div class="progress-label-row">
                <span class="progress-label">{{ $cat->nombre }}</span>
                <span class="progress-value">{{ $crc($cat->total) }}</span>
              </div>
              <div class="progress" role="progressbar" aria-label="{{ $cat->nombre }}"
                aria-valuenow="{{ $pct }}" aria-valuemin="0" aria-valuemax="100">
                <div class="progress-bar bg-lime-accent" style="width: {{ $pct }}%"></div>
              </div>
            </div>
          @empty
            <p class="mb-0">Sin gastos este mes.</p>
          @endforelse
        </div>
      </div>

    </div>
  </div>

  {{-- Columna lateral: metas de ahorro --}}
  <div class="col-xl-3 col-lg-4">
    <div class="card mb-4">
      <div class="card-header">
        <h2 class="card-title">Metas de ahorro</h2>
      </div>
      <div class="mb-3">
        <span class="stat-label">Total ahorrado</span>
        <div class="stat-value">{{ $crc($ahorros) }}</div>
      </div>
      @forelse ($metas as $meta)
        @php $pct = min(100, round($meta->monto_actual / $meta->monto_objetivo * 100)); @endphp
        <div class="progress-container">
          <div class="progress-label-row">
            <span class="progress-label">{{ $meta->nombre }}</span>
            <span class="progress-value">{{ $pct }}%</span>
          </div>
          <div class="progress" role="progressbar" aria-label="{{ $meta->nombre }}"
            aria-valuenow="{{ $pct }}" aria-valuemin="0" aria-valuemax="100">
            <div class="progress-bar bg-lime-accent" style="width: {{ $pct }}%"></div>
          </div>
        </div>
      @empty
        <p class="mb-0">Aún no tienes metas activas.</p>
      @endforelse
    </div>
  </div>

</div>
@endsection

@push('scripts')
  <script src="{{ asset('assets/libs/apexcharts/apexcharts.min.js') }}"></script>
  <script>
    window.GF_GRAFICO = @json($grafico);
  </script>
  <script src="{{ asset('assets/js/dashboard.js') }}"></script>
@endpush
