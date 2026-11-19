import 'package:flutter/material.dart';

/// Raíz de la aplicación. Aquí se configurarán el tema, las rutas y los
/// proveedores de estado conforme se vayan creando.
class AplicacionWaypoint extends StatelessWidget {
  const AplicacionWaypoint({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waypoint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Waypoint')),
      ),
    );
  }
}
