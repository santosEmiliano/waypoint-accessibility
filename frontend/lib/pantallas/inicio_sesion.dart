import 'package:flutter/material.dart';

import '../rutas/destinos.dart';
import 'armazon.dart';
import 'registro.dart';

class PantallaInicioSesion extends StatelessWidget {
  const PantallaInicioSesion({super.key});

  // Abre el armazón con el rol elegido mediante los botones, sin poder volver al inicio de sesión.
  void _entrar(BuildContext context, Rol rol) {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => Armazon(rol: rol)));
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
                'Iniciar sesión',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),
              // Botones de pruebapara poder recorrer la app.
              // Se quitarán cuando exista el inicio de sesión real.
              FilledButton(
                onPressed: () => _entrar(context, Rol.usuario),
                child: const Text('Entrar como usuario'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _entrar(context, Rol.operador),
                child: const Text('Entrar como operador'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PantallaRegistro()),
                ),
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
