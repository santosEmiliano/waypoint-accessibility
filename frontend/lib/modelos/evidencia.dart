import 'usuario_resumen.dart';

class Evidencia {
  final int id;
  // 'reporte' (la sube el usuario) o 'atencion' (la sube el operador).
  final String tipo;
  // Ruta de la imagen en el servidor.
  final String ruta;
  final DateTime creacion;
  // Quien subió la foto.
  final UsuarioResumen usuario;

  const Evidencia({
    required this.id,
    required this.tipo,
    required this.ruta,
    required this.creacion,
    required this.usuario,
  });

  bool get esDeAtencion => tipo == 'atencion';

  factory Evidencia.desdeJson(Map<String, dynamic> m) {
    return Evidencia(
      id: m['id_evidencia'] as int,
      tipo: m['tipo_evidencia'] as String,
      ruta: m['ruta_evidencia'] as String,
      creacion: DateTime.parse(m['creacion_evidencia'] as String),
      usuario: UsuarioResumen.desdeJson(m['usuario'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_evidencia': id,
      'tipo_evidencia': tipo,
      'ruta_evidencia': ruta,
      'creacion_evidencia': creacion.toIso8601String(),
      'usuario': usuario.toJson(),
    };
  }
}
