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
                <li><a class="dropdown-item" href="{{ route('modulo', 'ingresos') }}"><i
                            class="bi bi-arrow-down-circle"></i> Registrar ingreso</a></li>
                <li><a class="dropdown-item" href="{{ route('modulo', 'gastos') }}"><i
                            class="bi bi-arrow-up-circle"></i> Registrar gasto</a></li>
                <li><a class="dropdown-item" href="{{ route('modulo', 'transferencias') }}"><i
                            class="bi bi-arrow-left-right"></i> Nueva transferencia</a></li>
                <li>
                    <hr class="dropdown-divider">
                </li>
                <li><a class="dropdown-item" href="{{ route('modulo', 'cuentas') }}"><i class="bi bi-bank"></i> Nueva
                        cuenta</a></li>
            </ul>
        </div>
    </div>

    <div class="navbar-search-wrapper">
        <input type="text" class="navbar-search-input" placeholder="Buscar en Gravity Finance..." id="main-search">
        <button class="navbar-search-btn" aria-label="Buscar">
            <i class="bi bi-search"></i>
        </button>
    </div>

    <div class="navbar-actions">
        <button class="navbar-action-btn me-1" aria-label="Pantalla completa" id="btn-fullscreen">
            <i class="bi bi-arrows-fullscreen"></i>
        </button>

        <!-- Notificaciones: se conectarán a la colección "notificaciones" de MongoDB -->
        <div class="dropdown">
            <button class="navbar-action-btn dropdown-toggle" type="button" data-bs-toggle="dropdown"
                aria-expanded="false" id="btn-notifications" data-bs-auto-close="outside">
                <i class="bi bi-bell"></i>
            </button>
            <div class="dropdown-menu dropdown-menu-end dropdown-menu-notification p-0"
                aria-labelledby="btn-notifications">
                <div class="notification-header">
                    <h6 class="notification-title">Notificaciones</h6>
                </div>
                <div class="notification-list">
                    <div class="notification-item">
                        <div class="notification-content">
                            <p class="notification-text mb-0">No tienes notificaciones nuevas.</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>

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
