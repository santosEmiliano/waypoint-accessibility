import 'categoria.dart';
import 'estado.dart';
import 'usuario_resumen.dart';

class Reporte {
  final int id;
  final String titulo;
  final String descripcion;
  final String ubicacion;

  // Vienen vacías si el usuario no dio permiso de ubicación.
  final double? latitud;
  final double? longitud;

  final bool cancelado;
  final String? razonCancelacion;
  final DateTime creacion;
  final DateTime actualizacion;
  final Categoria categoria;
  final Estado estado;
  final UsuarioResumen usuario;

  // Es null mientras ningún operador toma el reporte.
  final UsuarioResumen? operador;

  const Reporte({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.ubicacion,
    this.latitud,
    this.longitud,
    required this.cancelado,
    this.razonCancelacion,
    required this.creacion,
    required this.actualizacion,
    required this.categoria,
    required this.estado,
    required this.usuario,
    this.operador,
  });

  factory Reporte.desdeJson(Map<String, dynamic> m) {
    return Reporte(
      id: m['id_reporte'] as int,
      titulo: m['titulo_reporte'] as String,
      descripcion: m['descripcion_reporte'] as String,
      ubicacion: m['ubicacion_reporte'] as String,
      latitud: (m['latitud_reporte'] as num?)?.toDouble(),
      longitud: (m['longitud_reporte'] as num?)?.toDouble(),
      cancelado: m['cancelado_reporte'] as bool,
      razonCancelacion: m['razon_cancelacion_reporte'] as String?,
      creacion: DateTime.parse(m['creacion_reporte'] as String),
      actualizacion: DateTime.parse(m['actualizacion_reporte'] as String),
      categoria: Categoria.desdeJson(m['categoria'] as Map<String, dynamic>),
      estado: Estado.desdeJson(m['estado'] as Map<String, dynamic>),
      usuario: UsuarioResumen.desdeJson(m['usuario'] as Map<String, dynamic>),
      operador: m['operador'] == null
          ? null
          : UsuarioResumen.desdeJson(m['operador'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_reporte': id,
      'titulo_reporte': titulo,
      'descripcion_reporte': descripcion,
      'ubicacion_reporte': ubicacion,
      'latitud_reporte': latitud,
      'longitud_reporte': longitud,
      'cancelado_reporte': cancelado,
      'razon_cancelacion_reporte': razonCancelacion,
      'creacion_reporte': creacion.toIso8601String(),
      'actualizacion_reporte': actualizacion.toIso8601String(),
      'categoria': categoria.toJson(),
      'estado': estado.toJson(),
      'usuario': usuario.toJson(),
      'operador': operador?.toJson(),
    };
  }
}
