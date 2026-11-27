import '../modelos/usuario.dart';
import 'repositorio_falso.dart';
import 'repositorio_waypoint.dart';

/// Quién tiene la sesión abierta. Se crea una vez y se pasa a las pantallas
/// que la necesitan.
class Sesion {
  final RepositorioWaypoint repositorio;

  Sesion({RepositorioWaypoint? repositorio})
    : repositorio = repositorio ?? RepositorioFalso();

  Usuario? usuario;

  bool get iniciada => usuario != null;

  Future<void> iniciarSesion(String correo, String contrasena) async {
    final acceso = await repositorio.iniciarSesion(correo, contrasena);
    usuario = acceso.usuario;
  }

  Future<void> registrar(
    String nombre,
    String correo,
    String contrasena,
  ) async {
    final acceso = await repositorio.registrar(nombre, correo, contrasena);
    usuario = acceso.usuario;
  }

  Future<void> cerrar() async {
    try {
      await repositorio.cerrarSesion();
    } finally {
      // Aunque falle el servidor, en la app la sesión se cierra.
      usuario = null;
    }
  }
}
