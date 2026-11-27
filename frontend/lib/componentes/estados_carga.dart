import 'package:flutter/material.dart';

import '../servicios/error_api.dart';
import 'marca_waypoint.dart';

/// Lo que se ve mientras responde la API, el logo respirando y un texto.
class CargandoWaypoint extends StatelessWidget {
  const CargandoWaypoint({super.key, this.mensaje = 'Cargando tus reportes'});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MarcaWaypoint(tamano: 48, respira: true),
          const SizedBox(height: 16),
          Text(mensaje, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Lo que se ve si falla la carga. El mensaje y el botón para reintentar.
class ErrorWaypoint extends StatelessWidget {
  const ErrorWaypoint({
    super.key,
    required this.mensaje,
    required this.alReintentar,
  });

  /// Saca el mensaje de un error, el de la API si lo trae, o [porDefecto].
  static String mensajeDe(
    Object? error, {
    String porDefecto = 'No se pudieron cargar tus reportes.',
  }) {
    return error is ErrorApi ? error.mensaje : porDefecto;
  }

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: alReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
