<!DOCTYPE html>
<html lang="es">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="csrf-token" content="{{ csrf_token() }}">
  <title>@yield('title', 'Panel') | Gravity Finance</title>
  <meta name="description" content="Gravity Finance - Sistema web de gestión de finanzas personales">

  <link rel="icon" type="image/png" href="{{ asset('assets/images/favicon.ico') }}">

  <link rel="stylesheet" href="{{ asset('assets/libs/bootstrap/css/bootstrap.min.css') }}">
  <link rel="stylesheet" href="{{ asset('assets/libs/bootstrap-icons/bootstrap-icons.css') }}">
  <link rel="stylesheet" href="{{ asset('assets/libs/apexcharts/apexcharts.css') }}">
  <link rel="stylesheet" href="{{ asset('assets/css/main.css') }}">
  @stack('styles')
</head>

<body>

  @include('partials.sidebar')

  <div class="main-wrapper">
    @include('partials.navbar')

    <div class="page-header">
      <div>
        <h1 class="page-title">@yield('page-title', 'Panel')</h1>
        <p class="page-subtitle">@yield('page-subtitle')</p>
      </div>
      @yield('page-actions')
    </div>

    @if (session('status'))
      <div class="alert alert-success" role="alert">{{ session('status') }}</div>
    @endif

    @yield('content')

    @include('partials.footer')
  </div>

  <script src="{{ asset('assets/libs/bootstrap/js/bootstrap.bundle.min.js') }}"></script>
  <script src="{{ asset('assets/js/layout.js') }}"></script>
  @stack('scripts')
</body>

</html>
