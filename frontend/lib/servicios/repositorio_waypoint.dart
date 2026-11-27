import 'dart:typed_data';

import '../modelos/categoria.dart';
import '../modelos/estado.dart';
import '../modelos/evidencia.dart';
import '../modelos/movimiento.dart';
import '../modelos/reporte.dart';
import '../modelos/usuario.dart';

/// Lo que devuelven el registro y el inicio de sesión.
class Acceso {
  final Usuario usuario;
  final String token;

  const Acceso({required this.usuario, required this.token});
}

/// Todo lo que la app le puede pedir al servidor.
/// Cualquier fallo se lanza como un ErrorApi.
abstract class RepositorioWaypoint {
  // Sesión

  Future<Acceso> iniciarSesion(String correo, String contrasena);

  Future<Acceso> registrar(String nombre, String correo, String contrasena);

  Future<Usuario> obtenerUsuario();

  Future<void> cerrarSesion();

  // Catálogos

  Future<List<Categoria>> listarCategorias();

  Future<List<Estado>> listarEstados();

  // Reportes

  Future<Reporte> crearReporte({
    required String titulo,
    required String descripcion,
    required int idCategoria,
    required String ubicacion,
    double? latitud,
    double? longitud,
  });

  /// En este endpoint el usuario recibe solo los suyos y el operador recibe todos.
  Future<List<Reporte>> listarReportes({
    int? idEstado,
    int? idCategoria,
    String? texto,
    bool cancelados = false,
  });

  Future<Reporte> obtenerReporte(int id);

  Future<Reporte> editarReporte(
    int id, {
    required String titulo,
    required String descripcion,
    required int idCategoria,
    required String ubicacion,
    double? latitud,
    double? longitud,
  });

  Future<Reporte> cancelarReporte(int id, {String? razon});

  // Evidencias e historial

  /// Recibe los bytes de la foto y no su ruta, porque en web no hay rutas de archivo.
  Future<Evidencia> subirEvidencia(
    int idReporte,
    Uint8List bytes,
    String nombreArchivo,
  );

  Future<List<Evidencia>> listarEvidencias(int idReporte);

  Future<List<Movimiento>> obtenerHistorial(int idReporte);

  // Solo el operador

  Future<Reporte> asignarReporte(int id);

  /// Se manda el estado al que se quiere pasar, no "el siguiente".
  Future<Reporte> cambiarEstado(int id, int idEstado, {String? comentario});

  Future<Movimiento> registrarAccion(int id, String descripcion);
}
