<header class="navbar-custom">
    <div class="navbar-left">
        <button class="btn-desktop-toggle d-none d-xl-flex align-items-center justify-content-center me-3"
            id="desktop-sidebar-toggle" aria-label="Minimizar menú">
            <i class="bi bi-chevron-bar-left"></i>
        </button>
        <button class="sidebar-toggle-btn me-2" id="sidebar-toggle" aria-label="Mostrar menú">
            <i class="bi bi-list"></i>
        </button>

        <!-- Acciones rápidas -->
        <div class="dropdown ms-2">
            <button class="btn-quick-action dropdown-toggle" type="button" data-bs-toggle="dropdown"
                aria-expanded="false" id="quick-actions-dropdown">
                <i class="bi bi-plus-lg"></i>
                <span>Nuevo</span>
            </button>
            <ul class="dropdown-menu dropdown-menu-quick-action" aria-labelledby="quick-actions-dropdown">
                <li class="dropdown-header">Acciones rápidas</li>
                <li><a class="dropdown-item" href="{{ route('ingresos.index') }}"><i
                            class="bi bi-arrow-down-circle"></i> Registrar ingreso</a></li>
                <li><a class="dropdown-item" href="{{ route('gastos.index') }}"><i
                            class="bi bi-arrow-up-circle"></i> Registrar gasto</a></li>
                <li><a class="dropdown-item" href="{{ route('transferencias.index') }}"><i
                            class="bi bi-arrow-left-right"></i> Nueva transferencia</a></li>
                <li>
                    <hr class="dropdown-divider">
                </li>
                <li><a class="dropdown-item" href="{{ route('cuentas.index') }}"><i class="bi bi-bank"></i> Nueva
                        cuenta</a></li>
            </ul>
        </div>
    </div>

    <div class="navbar-actions">
        <button class="navbar-action-btn me-1" aria-label="Pantalla completa" id="btn-fullscreen">
            <i class="bi bi-arrows-fullscreen"></i>
        </button>

        
        <div class="dropdown ms-2">
            <button class="navbar-profile-btn dropdown-toggle" type="button" data-bs-toggle="dropdown"
                aria-expanded="false" id="profile-dropdown">
                <img src="{{ asset('assets/images/avatar.png') }}" alt="Perfil" class="navbar-profile-img">
                <span class="navbar-profile-name d-none d-md-inline">{{ auth()->user()->nombre }}</span>
                <i class="bi bi-chevron-down navbar-profile-caret"></i>
            </button>
            <ul class="dropdown-menu dropdown-menu-end dropdown-menu-profile" aria-labelledby="profile-dropdown">
                <li class="dropdown-header">{{ auth()->user()->correo }}</li>
                <li><a class="dropdown-item" href="#"><i class="bi bi-person"></i> Mi perfil</a></li>
                <li>
                    <hr class="dropdown-divider">
                </li>
                <li>
                    <form action="{{ route('logout') }}" method="POST">
                        @csrf
                        <button type="submit" class="dropdown-item"><i class="bi bi-box-arrow-right"></i> Cerrar
                            sesión</button>
                    </form>
                </li>
            </ul>
        </div>
    </div>
</header>
