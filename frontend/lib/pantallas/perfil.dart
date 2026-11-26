import 'package:flutter/material.dart';

import '../servicios/sesion.dart';
import 'acceso.dart';

class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key, required this.sesion});

  final Sesion sesion;

  // Cierra la sesión y regresa al inicio de sesión.
  Future<void> _salir(BuildContext context) async {
    await sesion.cerrar();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PantallaAcceso(sesion: sesion)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Perfil y configuración',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              // Muestra con quién se inició sesión.
              Text(sesion.usuario?.nombre ?? ''),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => _salir(context),
                child: const Text('Salir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
