import 'estado.dart';
import 'usuario_resumen.dart';

// Un renglón del historial de un reporte (la línea de tiempo del seguimiento).
class Movimiento {
  final int id;

  // creacion, edicion, asignacion, cambio_estado, accion_correctiva o cancelacion
  final String tipo;

  // Solo vienen en los movimientos que cambian el estado.
  final Estado? estadoAnterior;
  final Estado? estadoNuevo;
  final String? descripcion;

  final DateTime creacion;

  final UsuarioResumen usuario; // Quien hizo el movimiento.

  const Movimiento({
    required this.id,
    required this.tipo,
    this.estadoAnterior,
    this.estadoNuevo,
    this.descripcion,
    required this.creacion,
    required this.usuario,
  });

  factory Movimiento.desdeJson(Map<String, dynamic> m) {
    return Movimiento(
      id: m['id_historial'] as int,
      tipo: m['tipo_historial'] as String,
      estadoAnterior: m['estado_anterior'] == null
          ? null
          : Estado.desdeJson(m['estado_anterior'] as Map<String, dynamic>),
      estadoNuevo: m['estado_nuevo'] == null
          ? null
          : Estado.desdeJson(m['estado_nuevo'] as Map<String, dynamic>),
      descripcion: m['descripcion_historial'] as String?,
      creacion: DateTime.parse(m['creacion_historial'] as String),
      usuario: UsuarioResumen.desdeJson(m['usuario'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_historial': id,
      'tipo_historial': tipo,
      'estado_anterior': estadoAnterior?.toJson(),
      'estado_nuevo': estadoNuevo?.toJson(),
      'descripcion_historial': descripcion,
      'creacion_historial': creacion.toIso8601String(),
      'usuario': usuario.toJson(),
    };
  }
}
