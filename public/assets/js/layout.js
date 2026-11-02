/*
 * Gravity Finance - comportamiento del layout (menú lateral y pantalla completa).
 * Adaptado de la plantilla Spark Admin (MIT).
 */
document.addEventListener('DOMContentLoaded', function () {
  // Menú lateral en móvil con fondo oscuro
  const sidebar = document.querySelector('.sidebar-wrapper');
  const toggleBtn = document.querySelector('.sidebar-toggle-btn');
  const overlay = document.createElement('div');
  overlay.className = 'sidebar-overlay';
  document.body.appendChild(overlay);

  if (toggleBtn && sidebar) {
    toggleBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      sidebar.classList.toggle('show');
      overlay.classList.toggle('show', sidebar.classList.contains('show'));
    });
    overlay.addEventListener('click', function () {
      sidebar.classList.remove('show');
      overlay.classList.remove('show');
    });
  }

  // Minimizar menú en escritorio
  const desktopToggle = document.querySelector('#desktop-sidebar-toggle');
  if (desktopToggle) {
    desktopToggle.addEventListener('click', function () {
      document.body.classList.toggle('sidebar-minimized');
      const icon = desktopToggle.querySelector('i');
      if (icon) {
        icon.className = document.body.classList.contains('sidebar-minimized')
          ? 'bi bi-chevron-bar-right'
          : 'bi bi-chevron-bar-left';
      }
      // Los gráficos se redibujan con el nuevo ancho
      setTimeout(() => window.dispatchEvent(new Event('resize')), 300);
    });
  }

  // Pantalla completa
  const fullscreenBtn = document.querySelector('#btn-fullscreen');
  if (fullscreenBtn) {
    const setIcon = (full) => {
      const icon = fullscreenBtn.querySelector('i');
      if (icon) icon.className = full ? 'bi bi-fullscreen-exit' : 'bi bi-arrows-fullscreen';
    };
    fullscreenBtn.addEventListener('click', function () {
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(() => {});
      } else {
        document.exitFullscreen().catch(() => {});
      }
    });
    document.addEventListener('fullscreenchange', () => setIcon(!!document.fullscreenElement));
  }
});
