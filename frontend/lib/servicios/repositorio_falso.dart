import 'dart:typed_data';

import '../modelos/categoria.dart';
import '../modelos/estado.dart';
import '../modelos/evidencia.dart';
import '../modelos/movimiento.dart';
import '../modelos/reporte.dart';
import '../modelos/usuario.dart';
import 'datos_ejemplo.dart';
import 'error_api.dart';
import 'repositorio_waypoint.dart';

/// Repositorio que guarda todo en memoria, para desarrollar sin servidor.
/// Aplica las mismas reglas y lanza los mismos errores que el contrato de la API.
class RepositorioFalso implements RepositorioWaypoint {
  RepositorioFalso({this.retraso = const Duration(milliseconds: 300)});

  // Lo que tarda cada respuesta, para que se vean los estados de carga.
  final Duration retraso;

  final _cuentas = DatosEjemplo.cuentas();
  final _reportes = DatosEjemplo.reportes();
  final _evidencias = DatosEjemplo.evidencias();
  final _historial = DatosEjemplo.historial();

  Usuario? _actual;
  // Los datos de ejemplo usan ids bajos, lo nuevo empieza desde aquí.
  int _siguienteId = 100;

  // Ayudas internas

  Future<void> _espera() => Future.delayed(retraso);

  Usuario _sesion() {
    final usuario = _actual;
    if (usuario == null) {
      throw const ErrorApi(
        codigo: 'NO_AUTENTICADO',
        mensaje: 'Inicia sesión para continuar',
      );
    }
    return usuario;
  }

  ErrorApi _sinPermiso() => const ErrorApi(
    codigo: 'SIN_PERMISO',
    mensaje: 'No tienes permiso para hacer esto',
  );

  ErrorApi _noEncontrado() => const ErrorApi(
    codigo: 'NO_ENCONTRADO',
    mensaje: 'No se encontró el reporte',
  );

  ErrorApi _noEditable(String mensaje) =>
      ErrorApi(codigo: 'REPORTE_NO_EDITABLE', mensaje: mensaje);

  ErrorApi _validacion(Map<String, String> campos) => ErrorApi(
    codigo: 'VALIDACION',
    mensaje: 'Hay campos inválidos',
    campos: campos,
  );

  // Devuelve el reporte si la sesión puede verlo (el creador o un operador).
  Reporte _visible(int id) {
    final usuario = _sesion();
    final reporte = _reportes.where((r) => r.id == id).firstOrNull;
    if (reporte == null) throw _noEncontrado();
    if (!usuario.esOperador && reporte.usuario.id != usuario.id) {
      throw _noEncontrado();
    }
    return reporte;
  }

  void _guardar(Reporte nuevo) {
    final i = _reportes.indexWhere((r) => r.id == nuevo.id);
    _reportes[i] = nuevo;
  }

  // Copia el reporte cambiando solo lo que se pide.
  Reporte _copiar(
    Reporte r, {
    Estado? estado,
    bool? cancelado,
    String? razon,
    Usuario? operador,
  }) {
    return Reporte(
      id: r.id,
      titulo: r.titulo,
      descripcion: r.descripcion,
      ubicacion: r.ubicacion,
      latitud: r.latitud,
      longitud: r.longitud,
      cancelado: cancelado ?? r.cancelado,
      razonCancelacion: razon ?? r.razonCancelacion,
      creacion: r.creacion,
      actualizacion: DateTime.now(),
      categoria: r.categoria,
      estado: estado ?? r.estado,
      usuario: r.usuario,
      operador: operador?.resumen ?? r.operador,
    );
  }

  Movimiento _anotar(
    int idReporte,
    String tipo, {
    Estado? anterior,
    Estado? nuevo,
    String? descripcion,
  }) {
    final movimiento = Movimiento(
      id: _siguienteId++,
      tipo: tipo,
      estadoAnterior: anterior,
      estadoNuevo: nuevo,
      descripcion: descripcion,
      creacion: DateTime.now(),
      usuario: _sesion().resumen,
    );
    _historial.putIfAbsent(idReporte, () => []).add(movimiento);
    return movimiento;
  }

  void _validarReporte(
    String titulo,
    String descripcion,
    int idCategoria,
    String ubicacion,
    double? latitud,
    double? longitud,
  ) {
    final campos = <String, String>{};
    if (titulo.trim().isEmpty || titulo.length > 200) {
      campos['titulo_reporte'] = 'Debe tener de 1 a 200 caracteres';
    }
    if (descripcion.trim().isEmpty || descripcion.length > 2000) {
      campos['descripcion_reporte'] = 'Debe tener de 1 a 2000 caracteres';
    }
    if (ubicacion.trim().isEmpty || ubicacion.length > 255) {
      campos['ubicacion_reporte'] = 'Debe tener de 1 a 255 caracteres';
    }
    if (!DatosEjemplo.categorias.any((c) => c.id == idCategoria)) {
      campos['id_categoria'] = 'La categoría no existe';
    }
    if ((latitud == null) != (longitud == null)) {
      campos['latitud_reporte'] = 'La latitud y la longitud van juntas';
    }
    if (campos.isNotEmpty) throw _validacion(campos);
  }

  Reporte _construir(
    int id,
    Usuario creador,
    String titulo,
    String descripcion,
    int idCategoria,
    String ubicacion,
    double? latitud,
    double? longitud,
  ) {
    final ahora = DateTime.now();
    return Reporte(
      id: id,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      ubicacion: ubicacion.trim(),
      latitud: latitud,
      longitud: longitud,
      cancelado: false,
      creacion: ahora,
      actualizacion: ahora,
      categoria: DatosEjemplo.categorias.firstWhere((c) => c.id == idCategoria),
      estado: DatosEjemplo.estados.first,
      usuario: creador.resumen,
    );
  }

  // Sesión

  @override
  Future<Acceso> iniciarSesion(String correo, String contrasena) async {
    await _espera();
    final cuenta = _cuentas
        .where(
          (c) =>
              c.usuario.correo == correo.trim().toLowerCase() &&
              c.contrasena == contrasena,
        )
        .firstOrNull;
    if (cuenta == null) {
      throw const ErrorApi(
        codigo: 'CREDENCIALES_INVALIDAS',
        mensaje: 'El correo o la contraseña no son correctos',
      );
    }
    _actual = cuenta.usuario;
    return Acceso(
      usuario: cuenta.usuario,
      token: 'token-falso-${cuenta.usuario.id}',
    );
  }

  @override
  Future<Acceso> registrar(
    String nombre,
    String correo,
    String contrasena,
  ) async {
    await _espera();
    final campos = <String, String>{};
    if (nombre.trim().isEmpty || nombre.length > 100) {
      campos['nombre_usuario'] = 'Debe tener de 1 a 100 caracteres';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo.trim())) {
      campos['correo_usuario'] = 'Formato inválido';
    }
    if (contrasena.length < 8) {
      campos['contrasena_usuario'] = 'Debe tener al menos 8 caracteres';
    }
    if (campos.isNotEmpty) throw _validacion(campos);

    final correoLimpio = correo.trim().toLowerCase();
    if (_cuentas.any((c) => c.usuario.correo == correoLimpio)) {
      throw const ErrorApi(
        codigo: 'CORREO_REGISTRADO',
        mensaje: 'Ya existe una cuenta con ese correo',
      );
    }

    // Toda cuenta nueva se crea con rol usuario.
    final usuario = Usuario(
      id: _siguienteId++,
      nombre: nombre.trim(),
      correo: correoLimpio,
      rol: 'usuario',
      creacion: DateTime.now(),
    );
    _cuentas.add(CuentaEjemplo(usuario: usuario, contrasena: contrasena));
    _actual = usuario;
    return Acceso(usuario: usuario, token: 'token-falso-${usuario.id}');
  }

  @override
  Future<Usuario> obtenerUsuario() async {
    await _espera();
    return _sesion();
  }

  @override
  Future<void> cerrarSesion() async {
    await _espera();
    _actual = null;
  }

  // Catálogos

  @override
  Future<List<Categoria>> listarCategorias() async {
    await _espera();
    _sesion();
    return List.of(DatosEjemplo.categorias);
  }

  @override
  Future<List<Estado>> listarEstados() async {
    await _espera();
    _sesion();
    return List.of(DatosEjemplo.estados);
  }

  // Reportes

  @override
  Future<Reporte> crearReporte({
    required String titulo,
    required String descripcion,
    required int idCategoria,
    required String ubicacion,
    double? latitud,
    double? longitud,
  }) async {
    await _espera();
    final usuario = _sesion();
    if (usuario.esOperador) throw _sinPermiso();
    _validarReporte(
      titulo,
      descripcion,
      idCategoria,
      ubicacion,
      latitud,
      longitud,
    );

    final reporte = _construir(
      _siguienteId++,
      usuario,
      titulo,
      descripcion,
      idCategoria,
      ubicacion,
      latitud,
      longitud,
    );
    _reportes.add(reporte);
    _anotar(reporte.id, 'creacion', nuevo: reporte.estado);
    return reporte;
  }

  @override
  Future<List<Reporte>> listarReportes({
    int? idEstado,
    int? idCategoria,
    String? texto,
    bool cancelados = false,
  }) async {
    await _espera();
    final usuario = _sesion();
    final buscado = texto?.trim().toLowerCase() ?? '';

    final lista = _reportes.where((r) {
      if (!usuario.esOperador && r.usuario.id != usuario.id) return false;
      if (r.cancelado != cancelados) return false;
      if (idEstado != null && r.estado.id != idEstado) return false;
      if (idCategoria != null && r.categoria.id != idCategoria) return false;
      if (buscado.isEmpty) return true;
      return r.titulo.toLowerCase().contains(buscado) ||
          r.descripcion.toLowerCase().contains(buscado) ||
          r.ubicacion.toLowerCase().contains(buscado);
    }).toList();

    // Los más recientes primero.
    lista.sort((a, b) => b.creacion.compareTo(a.creacion));
    return lista;
  }

  @override
  Future<Reporte> obtenerReporte(int id) async {
    await _espera();
    return _visible(id);
  }

  @override
  Future<Reporte> editarReporte(
    int id, {
    required String titulo,
    required String descripcion,
    required int idCategoria,
    required String ubicacion,
    double? latitud,
    double? longitud,
  }) async {
    await _espera();
    final usuario = _sesion();
    final actual = _visible(id);
    if (usuario.esOperador) throw _sinPermiso();
    if (actual.cancelado || actual.estado.orden != 1) {
      throw _noEditable('Solo se puede editar un reporte en estado Reportado');
    }
    _validarReporte(
      titulo,
      descripcion,
      idCategoria,
      ubicacion,
      latitud,
      longitud,
    );

    final editado = Reporte(
      id: actual.id,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      ubicacion: ubicacion.trim(),
      latitud: latitud,
      longitud: longitud,
      cancelado: false,
      creacion: actual.creacion,
      actualizacion: DateTime.now(),
      categoria: DatosEjemplo.categorias.firstWhere((c) => c.id == idCategoria),
      estado: actual.estado,
      usuario: actual.usuario,
      operador: actual.operador,
    );
    _guardar(editado);
    _anotar(id, 'edicion');
    return editado;
  }

  @override
  Future<Reporte> cancelarReporte(int id, {String? razon}) async {
    await _espera();
    final usuario = _sesion();
    final actual = _visible(id);
    if (usuario.esOperador) throw _sinPermiso();
    if (actual.cancelado || actual.estado.orden != 1) {
      throw _noEditable(
        'Solo se puede cancelar un reporte en estado Reportado',
      );
    }
    if (razon != null && razon.length > 2000) {
      throw _validacion({
        'razon_cancelacion_reporte': 'Máximo 2000 caracteres',
      });
    }

    final cancelado = _copiar(actual, cancelado: true, razon: razon);
    _guardar(cancelado);
    _anotar(id, 'cancelacion');
    return cancelado;
  }

  // Evidencias e historial

  @override
  Future<Evidencia> subirEvidencia(
    int idReporte,
    Uint8List bytes,
    String nombreArchivo,
  ) async {
    await _espera();
    final usuario = _sesion();
    final reporte = _visible(idReporte);
    // Un operador solo puede subir fotos de los reportes que tiene asignados.
    if (usuario.esOperador && reporte.operador?.id != usuario.id) {
      throw _sinPermiso();
    }

    final idNuevo = _siguienteId++;
    final evidencia = Evidencia(
      id: idNuevo,
      tipo: usuario.esOperador ? 'atencion' : 'reporte',
      ruta: '/uploads/falso-$idNuevo.jpg',
      creacion: DateTime.now(),
      usuario: usuario.resumen,
    );
    _evidencias.putIfAbsent(idReporte, () => []).add(evidencia);
    return evidencia;
  }

  @override
  Future<List<Evidencia>> listarEvidencias(int idReporte) async {
    await _espera();
    _visible(idReporte);
    return List.of(_evidencias[idReporte] ?? []);
  }

  @override
  Future<List<Movimiento>> obtenerHistorial(int idReporte) async {
    await _espera();
    _visible(idReporte);
    return List.of(_historial[idReporte] ?? []);
  }

  // Solo el operador

  @override
  Future<Reporte> asignarReporte(int id) async {
    await _espera();
    final usuario = _sesion();
    if (!usuario.esOperador) throw _sinPermiso();
    final actual = _visible(id);
    if (actual.cancelado || actual.estado.orden == 4) {
      throw _noEditable('Este reporte ya no admite cambios');
    }

    final dueno = actual.operador;
    if (dueno != null && dueno.id != usuario.id) {
      throw const ErrorApi(
        codigo: 'REPORTE_YA_ASIGNADO',
        mensaje: 'Otro operador ya tomó este reporte',
      );
    }
    // Si ya era suyo no hay nada que cambiar.
    if (dueno != null) return actual;

    final asignado = _copiar(actual, operador: usuario);
    _guardar(asignado);
    _anotar(id, 'asignacion');
    return asignado;
  }

  @override
  Future<Reporte> cambiarEstado(
    int id,
    int idEstado, {
    String? comentario,
  }) async {
    await _espera();
    final usuario = _sesion();
    if (!usuario.esOperador) throw _sinPermiso();
    final actual = _visible(id);
    // Solo el operador asignado puede mover el estado.
    if (actual.operador?.id != usuario.id) throw _sinPermiso();
    if (actual.cancelado) throw _noEditable('El reporte está cancelado');

    final destino = DatosEjemplo.estados
        .where((e) => e.id == idEstado)
        .firstOrNull;
    if (destino == null) {
      throw _validacion({'id_estado': 'El estado no existe'});
    }

    // Si ya está en ese estado, la pantalla estaba desactualizada.
    if (destino.orden == actual.estado.orden) {
      throw const ErrorApi(
        codigo: 'ESTADO_DESACTUALIZADO',
        mensaje: 'El reporte ya estaba en ese estado',
      );
    }
    // Solo se avanza de uno en uno.
    if (destino.orden != actual.estado.orden + 1) {
      throw const ErrorApi(
        codigo: 'TRANSICION_INVALIDA',
        mensaje: 'Solo se puede pasar al siguiente estado',
      );
    }
    // Para resolver tiene que existir la foto de la atención.
    final hayFotoAtencion = (_evidencias[id] ?? []).any((e) => e.esDeAtencion);
    if (destino.orden == 4 && !hayFotoAtencion) {
      throw const ErrorApi(
        codigo: 'FALTA_EVIDENCIA_ATENCION',
        mensaje: 'Sube la foto de la atención antes de resolver',
      );
    }

    final nuevo = _copiar(actual, estado: destino);
    _guardar(nuevo);
    _anotar(
      id,
      'cambio_estado',
      anterior: actual.estado,
      nuevo: destino,
      descripcion: comentario,
    );
    return nuevo;
  }

  @override
  Future<Movimiento> registrarAccion(int id, String descripcion) async {
    await _espera();
    final usuario = _sesion();
    if (!usuario.esOperador) throw _sinPermiso();
    final actual = _visible(id);
    if (actual.operador?.id != usuario.id) throw _sinPermiso();
    if (descripcion.trim().isEmpty || descripcion.length > 2000) {
      throw _validacion({
        'descripcion_historial': 'Debe tener de 1 a 2000 caracteres',
      });
    }
    // Solo mientras se analiza o se atiende.
    if (actual.cancelado || ![2, 3].contains(actual.estado.orden)) {
      throw _noEditable('Ahora no se pueden registrar acciones');
    }
    return _anotar(id, 'accion_correctiva', descripcion: descripcion.trim());
  }
}
