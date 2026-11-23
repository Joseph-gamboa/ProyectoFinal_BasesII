@extends('layouts.app')

@section('title', 'Categorías')
@section('page-title', 'Categorías')
@section('page-subtitle', 'Categorías de ingresos y gastos.')

@section('page-actions')
  @if ($esAdmin)
    <button type="button" class="btn-dark-custom" data-bs-toggle="modal" data-bs-target="#modalCrear">
      <span class="icon-wrap"><i class="bi bi-plus-lg"></i></span>
      Nueva categoría
    </button>
  @endif
@endsection

@section('content')
  @php $reabrir = ($errors->any() || session('error')) && old('_form') === 'crear'; @endphp

  @include('partials.alertas')

  @unless ($esAdmin)
    <div class="alert alert-info" role="alert">
      Solo el administrador puede crear, editar o eliminar categorías.
    </div>
  @endunless

  <div class="row g-3">
    @foreach (['INGRESO' => ['Ingresos', 'bi-arrow-down-circle'], 'GASTO' => ['Gastos', 'bi-arrow-up-circle']] as $tipo => [$titulo, $icono])
      <div class="col-lg-6">
        <div class="table-card-custom">
          <div class="p-3 pb-0"><h2 class="card-title"><i class="bi {{ $icono }}"></i> {{ $titulo }}</h2></div>
          @php $lista = $categorias->where('tipo_categoria', $tipo); @endphp
          @if ($lista->isEmpty())
            <p class="p-3 mb-0 text-muted">No hay categorías de {{ strtolower($titulo) }}.</p>
          @else
            <div class="table-responsive">
              <table class="table-custom">
                <thead>
                  <tr>
                    <th>Nombre</th>
                    @if ($esAdmin)<th class="text-end">Acciones</th>@endif
                  </tr>
                </thead>
                <tbody>
                  @foreach ($lista as $c)
                    <tr>
                      <td><span class="table-user-name">{{ $c->nombre_categoria }}</span></td>
                      @if ($esAdmin)
                        <td class="text-end">
                          <div class="d-inline-flex gap-1">
                            <button type="button" class="btn btn-sm btn-light border" title="Editar"
                              data-bs-toggle="modal" data-bs-target="#modalEditar"
                              data-url="{{ route('categorias.update', $c->id_categoria) }}"
                              data-nombre="{{ $c->nombre_categoria }}"
                              data-tipo="{{ $c->tipo_categoria }}">
                              <i class="bi bi-pencil"></i>
                            </button>
                            <form action="{{ route('categorias.destroy', $c->id_categoria) }}" method="POST"
                              onsubmit="return confirm('¿Eliminar esta categoría?')">
                              @csrf
                              @method('DELETE')
                              <button type="submit" class="btn btn-sm btn-light border text-danger" title="Eliminar">
                                <i class="bi bi-trash"></i>
                              </button>
                            </form>
                          </div>
                        </td>
                      @endif
                    </tr>
                  @endforeach
                </tbody>
              </table>
            </div>
          @endif
        </div>
      </div>
    @endforeach
  </div>

  @if ($esAdmin)
    {{-- Ventana: nueva categoría --}}
    <div class="modal fade" id="modalCrear" tabindex="-1" aria-labelledby="modalCrearLabel" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered">
        <form class="modal-content" action="{{ route('categorias.store') }}" method="POST">
          @csrf
          <input type="hidden" name="_form" value="crear">
          <div class="modal-header">
            <h5 class="modal-title" id="modalCrearLabel">Nueva categoría</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
          </div>
          <div class="modal-body">
            <div class="mb-3">
              <label class="form-label" for="crear_nombre">Nombre</label>
              <input type="text" id="crear_nombre" name="nombre_categoria" class="form-control-custom"
                maxlength="50" value="{{ old('nombre_categoria') }}" required>
            </div>
            <div>
              <label class="form-label" for="crear_tipo">Tipo</label>
              <select id="crear_tipo" name="tipo_categoria" class="form-control-custom" required>
                <option value="INGRESO" @selected(old('tipo_categoria') === 'INGRESO')>Ingreso</option>
                <option value="GASTO"   @selected(old('tipo_categoria') === 'GASTO')>Gasto</option>
              </select>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
            <button type="submit" class="btn-dark-custom">Crear categoría</button>
          </div>
        </form>
      </div>
    </div>

    {{-- Ventana: editar categoría --}}
    <div class="modal fade" id="modalEditar" tabindex="-1" aria-labelledby="modalEditarLabel" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered">
        <form class="modal-content" id="formEditar" action="#" method="POST">
          @csrf
          @method('PUT')
          <div class="modal-header">
            <h5 class="modal-title" id="modalEditarLabel">Editar categoría</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
          </div>
          <div class="modal-body">
            <div class="mb-3">
              <label class="form-label" for="editar_nombre">Nombre</label>
              <input type="text" id="editar_nombre" name="nombre_categoria" class="form-control-custom" maxlength="50" required>
            </div>
            <div>
              <label class="form-label" for="editar_tipo">Tipo</label>
              <select id="editar_tipo" name="tipo_categoria" class="form-control-custom" required>
                <option value="INGRESO">Ingreso</option>
                <option value="GASTO">Gasto</option>
              </select>
              <div class="small text-muted mt-1">El tipo no se puede cambiar si la categoría ya tiene movimientos.</div>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
            <button type="submit" class="btn-dark-custom">Guardar cambios</button>
          </div>
        </form>
      </div>
    </div>
  @endif
@endsection

@push('scripts')
  @if ($esAdmin)
    <script>
      document.getElementById('modalEditar').addEventListener('show.bs.modal', function (e) {
        var b = e.relatedTarget, f = document.getElementById('formEditar');
        f.action = b.dataset.url;
        f.querySelector('[name=nombre_categoria]').value = b.dataset.nombre;
        f.querySelector('[name=tipo_categoria]').value = b.dataset.tipo;
      });
    </script>
    @if ($reabrir)
      <script>new bootstrap.Modal(document.getElementById('modalCrear')).show();</script>
    @endif
  @endif
@endpush
