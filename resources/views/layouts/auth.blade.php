<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>@yield('title') | Gravity Finance</title>
  <link rel="icon" type="image/png" href="{{ asset('assets/images/favicon.ico') }}">
  <link rel="stylesheet" href="{{ asset('assets/libs/bootstrap/css/bootstrap.min.css') }}">
  <link rel="stylesheet" href="{{ asset('assets/libs/bootstrap-icons/bootstrap-icons.css') }}">
  <link rel="stylesheet" href="{{ asset('assets/css/main.css') }}">
</head>
<body>
  <div class="login-wrapper">
    <div class="login-bg-shape login-bg-shape-1"></div>
    <div class="login-bg-shape login-bg-shape-2"></div>

    <div class="login-card">
      <a href="{{ url('/') }}" class="login-brand text-decoration-none">
        <i class="bi bi-asterisk"></i>
        <span>Gravity Finance</span>
      </a>

      @yield('content')
    </div>
  </div>

  <script src="{{ asset('assets/libs/bootstrap/js/bootstrap.bundle.min.js') }}"></script>
  <script src="{{ asset('assets/js/auth.js') }}"></script>
</body>
</html>
