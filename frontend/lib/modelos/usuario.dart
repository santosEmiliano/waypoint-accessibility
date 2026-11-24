// El usuario de la sesión.
class Usuario {
  final int id;
  final String nombre;
  final String correo;
  final String rol; // 'usuario' u 'operador'
  final DateTime creacion;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.creacion,
  });

  bool get esOperador => rol == 'operador';

  factory Usuario.desdeJson(Map<String, dynamic> m) {
    return Usuario(
      id: m['id_usuario'] as int,
      nombre: m['nombre_usuario'] as String,
      correo: m['correo_usuario'] as String,
      rol: m['nombre_rol'] as String,
      creacion: DateTime.parse(m['creacion_usuario'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_usuario': id,
      'nombre_usuario': nombre,
      'correo_usuario': correo,
      'nombre_rol': rol,
      'creacion_usuario': creacion.toIso8601String(),
    };
  }
}
