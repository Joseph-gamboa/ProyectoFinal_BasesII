
@extends('layouts.app')

@section('title', 'Dashboard')
@section('page-title', 'Dashboard')
@section('page-subtitle', 'Resumen general de tus finanzas personales.')

@php
  $crc = fn ($n) => '₡' . number_format((float) $n, 0, ',', '.');
  $usd = fn ($n) => '$ ' . number_format((float) $n, 2, ',', '.');

  $netoCRC = $ingresosMesCRC - $gastosMesCRC;
  $netoUSD = $ingresosMesUSD - $gastosMesUSD;
@endphp

@section('content')
<div class="row g-4">

  {{-- Indicadores --}}
  <div class="col-12">
    <div class="row g-4">

      <div class="col-md-4">
        <div class="card alert-green-card">
          <div class="position-relative z-index-2">
            <span class="alert-green-badge">Balance total</span>
            <div class="alert-green-date">Cuentas activas</div>
            <div class="alert-green-text">{{ $crc($balance) }}</div>

            @if ($balanceUsd != 0)
              <div class="alert-green-text" style="margin-top: .25rem;">
                {{ $usd($balanceUsd) }}
              </div>
            @endif
          </div>

          <a href="{{ route('cuentas.index') }}" class="alert-green-link z-index-2">
            <span>Ver cuentas</span>
            <i class="bi bi-arrow-right"></i>
          </a>

          <svg class="alert-green-bg-shape" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
            <g transform="translate(50,50)">
              <rect x="-6" y="-45" width="12" height="90" rx="6" fill="#B4F105" />
              <rect x="-6" y="-45" width="12" height="90" rx="6" fill="#B4F105" transform="rotate(60)" />
              <rect x="-6" y="-45" width="12" height="90" rx="6" fill="#B4F105" transform="rotate(120)" />
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

            <div class="stat-value">{{ $crc($ingresosMesCRC) }}</div>
            <div class="stat-value">{{ $usd($ingresosMesUSD) }}</div>

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

            <div class="stat-value">{{ $crc($gastosMesCRC) }}</div>
            <div class="stat-value">{{ $usd($gastosMesUSD) }}</div>

            <div class="trend-badge {{ $netoCRC >= 0 ? 'trend-up' : 'trend-down' }}">
              <i class="bi {{ $netoCRC >= 0 ? 'bi-arrow-up-right' : 'bi-arrow-down-left' }}"></i>
              <span>Balance CRC: {{ $crc($netoCRC) }}</span>
            </div>

            <div class="trend-badge {{ $netoUSD >= 0 ? 'trend-up' : 'trend-down' }} mt-2">
              <i class="bi {{ $netoUSD >= 0 ? 'bi-arrow-up-right' : 'bi-arrow-down-left' }}"></i>
              <span>Balance USD: {{ $usd($netoUSD) }}</span>
            </div>
          </div>
        </div>
      </div>

    </div>
  </div>

  {{-- Columna principal --}}
  <div class="col-xl-9 col-lg-8">
    <div class="row g-4">

      {{-- Últimos movimientos --}}
      <div class="col-md-7 d-flex flex-column">
        <div class="card h-100 flex-grow-1">
          <div class="card-header">
            <h2 class="card-title">Últimos movimientos</h2>
          </div>

          <div class="transaction-list">
            @forelse ($ultimos as $mov)
              @php
                $esIngreso = $mov->tipo_transaccion === 'INGRESO';
                $montoFormato = $mov->moneda === 'USD'
                    ? $usd($mov->monto)
                    : $crc($mov->monto);
              @endphp

              <div class="transaction-item">
                <div class="transaction-icon bg-forest-light text-lime">
                  <i class="bi {{ $esIngreso ? 'bi-arrow-down-circle' : 'bi-arrow-up-circle' }}"></i>
                </div>

                <div class="transaction-info">
                  <div class="transaction-name">
                    {{ $mov->descripcion ?: $mov->categoria }}
                  </div>
                  <div class="transaction-date">
                    {{ $mov->categoria }} • {{ $mov->fecha->format('d/m/Y') }}
                  </div>
                </div>

                <div class="transaction-amount {{ $esIngreso ? 'text-success' : 'text-main' }}">
                  {{ $esIngreso ? '+' : '-' }}{{ $montoFormato }}
                </div>
              </div>
            @empty
              <p class="mb-0">Aún no hay movimientos registrados.</p>
            @endforelse
          </div>
        </div>
      </div>

      {{-- Gastos por categoría --}}
      <div class="col-md-5 d-flex flex-column">
        <div class="card h-100 flex-grow-1">
          <div class="card-header">
            <h2 class="card-title">Gastos por categoría</h2>
          </div>

          @forelse ($porCategoria as $cat)
            @php
              $maximo = $maxCategoriaPorMoneda[$cat->moneda] ?? 0;
              $pct = $maximo > 0 ? round($cat->total / $maximo * 100) : 0;
              $totalFormato = $cat->moneda === 'USD'
                  ? $usd($cat->total)
                  : $crc($cat->total);
            @endphp

            <div class="progress-container">
              <div class="progress-label-row">
                <span class="progress-label">{{ $cat->nombre }} ({{ $cat->moneda }})</span>
                <span class="progress-value">{{ $totalFormato }}</span>
              </div>

              <div class="progress" role="progressbar"
                aria-label="{{ $cat->nombre }}"
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

  {{-- Metas de ahorro --}}
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
        @php
          $pct = $meta->monto_objetivo > 0
              ? min(100, round($meta->monto_actual / $meta->monto_objetivo * 100))
              : 0;
        @endphp

        <div class="progress-container">
          <div class="progress-label-row">
            <span class="progress-label">{{ $meta->nombre }}</span>
            <span class="progress-value">{{ $pct }}%</span>
          </div>

          <div class="progress" role="progressbar"
            aria-label="{{ $meta->nombre }}"
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
