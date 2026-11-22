/// Datos de conexión con la API.
class ConfigApi {
  // Se cambia al compilar: flutter run --dart-define=API_URL=http://192.168.1.10:3000
  static const urlBase = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Arma la dirección completa de una ruta.
  static Uri ruta(String camino, [Map<String, String>? filtros]) {
    return Uri.parse('$urlBase$camino').replace(queryParameters: filtros);
  }
}
