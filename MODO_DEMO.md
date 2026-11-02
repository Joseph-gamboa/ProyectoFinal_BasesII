# Gravity Finance - modo demostración

Este proyecto está configurado temporalmente para mostrar la interfaz sin autenticación ni conexión a una base de datos.

- La ruta `/` abre directamente el dashboard.
- `/login` y `/registro` redirigen al dashboard.
- Los módulos del menú muestran sus pantallas provisionales.
- El dashboard utiliza datos ficticios definidos en `app/Http/Controllers/DashboardController.php`.
- Los controladores y modelos de autenticación se conservan, pero no están conectados a las rutas durante este modo.

Para iniciar el proyecto desde la carpeta `gravity-finance`:

```bash
php artisan optimize:clear
php artisan serve
```

Luego abrir http://127.0.0.1:8000.

No se requiere SQL Server para esta demostración. Cuando se implemente la base de datos, se podrán restaurar las rutas y consultas reales.
