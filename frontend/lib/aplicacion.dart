import 'package:flutter/material.dart';

import 'pantallas/inicio_sesion.dart';
import 'tema/tema_waypoint.dart';

/// Raíz de la aplicación.
class AplicacionWaypoint extends StatelessWidget {
  const AplicacionWaypoint({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waypoint',
      debugShowCheckedModeBanner: false,
      theme: TemaWaypoint.claro,
      darkTheme: TemaWaypoint.oscuro,
      // Sigue el modo claro u oscuro que tenga el teléfono.
      themeMode: ThemeMode.system,
      home: const PantallaInicioSesion(),
    );
  }
}
