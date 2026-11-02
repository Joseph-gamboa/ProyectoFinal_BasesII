@php
  $usuario = (object) ['nombre_completo' => 'Usuario de demostración', 'correo' => 'demo@gravityfinance.local'];

  // [ruta, icono, texto]
  $principal = [
    ['dashboard', 'bi-grid-fill', 'Dashboard'],
  ];
  $finanzas = [
    ['modulo:cuentas',        'bi-bank',               'Cuentas'],
    ['modulo:ingresos',       'bi-arrow-down-circle',  'Ingresos'],
    ['modulo:gastos',         'bi-arrow-up-circle',    'Gastos'],
    ['modulo:transferencias', 'bi-arrow-left-right',   'Transferencias'],
    ['modulo:categorias',     'bi-tags',               'Categorías'],
  ];
  $planificacion = [
    ['modulo:presupuestos', 'bi-pie-chart',  'Presupuestos'],
    ['modulo:ahorros',      'bi-piggy-bank', 'Ahorros'],
    ['modulo:deudas',       'bi-cash-coin',  'Deudas'],
    ['modulo:reportes',     'bi-file-earmark-bar-graph', 'Reportes'],
  ];
  $sistema = [
    ['modulo:auditoria', 'bi-shield-check', 'Auditoría'],
  ];

  $grupos = array_filter([
    'Menú'          => $principal,
    'Finanzas'      => $finanzas,
    'Planificación' => $planificacion,
    'Sistema'       => $sistema,
  ]);

  // Convierte "modulo:cuentas" o "dashboard" en [url, activo?]
  $resolver = function (string $destino) {
    if (str_starts_with($destino, 'modulo:')) {
      $m = substr($destino, 7);
      return [route('modulo', $m), request()->is($m)];
    }
    return [route($destino), request()->routeIs($destino)];
  };
@endphp

<div class="sidebar-wrapper" id="sidebar">
  <a href="{{ route('dashboard') }}" class="sidebar-brand">
    <i class="bi bi-asterisk"></i>
    <span>Gravity Finance</span>
  </a>

  <div class="flex-grow-1 overflow-y-auto">
    @foreach ($grupos as $titulo => $items)
      <div class="sidebar-menu-section">
        <div class="sidebar-menu-title">{{ $titulo }}</div>
        <ul class="sidebar-menu-list">
          @foreach ($items as [$destino, $icono, $texto])
            @php [$url, $activo] = $resolver($destino); @endphp
            <li class="sidebar-menu-item">
              <a href="{{ $url }}" class="sidebar-menu-link {{ $activo ? 'active' : '' }}" title="{{ $texto }}">
                <i class="bi {{ $icono }}"></i>
                <span>{{ $texto }}</span>
              </a>
            </li>
          @endforeach
        </ul>
      </div>
    @endforeach
  </div>

  <div class="sidebar-profile">
    <img src="{{ asset('assets/images/avatar.png') }}" alt="{{ $usuario->nombre_completo }}" class="sidebar-profile-img">
    <div class="sidebar-profile-info">
      <div class="sidebar-profile-name">{{ $usuario->nombre_completo }}</div>
      <div class="sidebar-profile-email">{{ $usuario->correo }}</div>
    </div>
  </div>
</div>
