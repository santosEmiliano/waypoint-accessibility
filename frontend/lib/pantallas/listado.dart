import 'package:flutter/material.dart';

import 'detalle.dart';

class PantallaListado extends StatelessWidget {
  const PantallaListado({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Listado de reportes',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),
              // Provisional: para llegar al detalle mientras no hay lista.
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PantallaDetalle()),
                ),
                child: const Text('Ver un reporte de ejemplo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
