import 'package:flutter/material.dart';

import 'inicio_sesion.dart';

class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

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
              const SizedBox(height: 24),
              // botón de prueba que cierra la "sesión" volviendo al inicio de sesión.
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const PantallaInicioSesion(),
                  ),
                ),
                child: const Text('Salir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
