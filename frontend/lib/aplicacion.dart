import 'package:flutter/material.dart';

import 'pantallas/inicio_sesion.dart';
import 'servicios/sesion.dart';
import 'tema/tema_waypoint.dart';

/// Raíz de la aplicación.
class AplicacionWaypoint extends StatefulWidget {
  const AplicacionWaypoint({super.key, this.sesion});

  final Sesion? sesion;

  @override
  State<AplicacionWaypoint> createState() => _EstadoAplicacion();
}

class _EstadoAplicacion extends State<AplicacionWaypoint> {
  late final Sesion _sesion = widget.sesion ?? Sesion();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waypoint',
      debugShowCheckedModeBanner: false,
      theme: TemaWaypoint.claro,
      darkTheme: TemaWaypoint.oscuro,
      // Sigue el modo claro u oscuro que tenga el teléfono.
      themeMode: ThemeMode.system,
      home: PantallaInicioSesion(sesion: _sesion),
    );
  }
}
