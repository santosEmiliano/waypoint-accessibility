import 'package:flutter/material.dart';

import '../tema/colores_waypoint.dart';
import 'marca_waypoint.dart';
import 'nombre_waypoint.dart';

/// Bloque punteado de la primera pantalla con la cuadicula de fondo, el logo, el nombre y la frase.
class CabeceraMarca extends StatelessWidget {
  const CabeceraMarca({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: c.dock,
      child: CustomPaint(
        painter: _PintorCuadricula(c.dockPastilla),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
            // En pantallas anchas el contenido se queda alineado con el formulario.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarcaWaypoint(
                        tamano: 56,
                        colorPuntos: c.dockTexto,
                        colorBorde: c.dock,
                        respira: true,
                      ),
                      const SizedBox(height: 24),
                      NombreWaypoint(
                        estilo: texto.displayLarge!.copyWith(
                          color: c.dockActivo,
                        ),
                        colorPunto: c.guia,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Reporta las barreras del campus y sigue cada reporte hasta que se resuelva.',
                        style: texto.titleMedium!.copyWith(
                          color: c.dockActivo,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Cuadrícula de puntos.
class _PintorCuadricula extends CustomPainter {
  _PintorCuadricula(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const separacion = 26.0;
    final pincel = Paint()..color = color;
    for (double x = separacion / 2; x < size.width; x += separacion) {
      for (double y = separacion / 2; y < size.height; y += separacion) {
        canvas.drawCircle(Offset(x, y), 5, pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorCuadricula anterior) => anterior.color != color;
}
