// Error que devuelve la API (o que pasa al intentar realizar una petición a ella).
class ErrorApi implements Exception {
  // Código fijo en mayúsculas, por ejemplo "REPORTE_YA_ASIGNADO".
  final String codigo;

  // Texto listo para mostrarle al usuario.
  final String mensaje;

  // Solo en VALIDACION: el problema de cada campo del formulario.
  final Map<String, String> campos;

  const ErrorApi({
    required this.codigo,
    required this.mensaje,
    this.campos = const {},
  });

  // Cuando no hay internet o el servidor no responde.
  const ErrorApi.sinConexion()
    : codigo = 'SIN_CONEXION',
      mensaje = 'No se pudo conectar con el servidor',
      campos = const {};

  bool get esSinConexion => codigo == 'SIN_CONEXION';

  // Con esto la app debe regresar al inicio de sesión.
  bool get esSesionVencida => codigo == 'NO_AUTENTICADO';

  // La API responde { "error": { "codigo", "mensaje", "campos"? } }
  factory ErrorApi.desdeJson(Map<String, dynamic> m) {
    final error = m['error'] as Map<String, dynamic>;
    final campos = error['campos'] as Map<String, dynamic>?;
    return ErrorApi(
      codigo: error['codigo'] as String,
      mensaje: error['mensaje'] as String,
      campos: campos?.map((k, v) => MapEntry(k, v as String)) ?? const {},
    );
  }

  @override
  String toString() => '$codigo: $mensaje';
}
