import 'package:flutter/material.dart';

import '../tema/colores_waypoint.dart';

/// El logo de waypoint. Una cuadrícula de 3 × 3 puntos con el centro amarillo.
class MarcaWaypoint extends StatelessWidget {
  const MarcaWaypoint({
    super.key,
    this.tamano = 32,
    this.colorPuntos,
    this.colorBorde,
  });

  final double tamano;

  /// Color de los 8 puntos de afuera.
  final Color? colorPuntos;

  /// Contorno del punto central.
  final Color? colorBorde;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    // Es decorado.
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(tamano),
        painter: _PintorMarca(
          colorPuntos: colorPuntos ?? c.tinta,
          colorGuia: c.guia,
          colorBorde: colorBorde ?? c.sobreGuia,
        ),
      ),
    );
  }
}

class _PintorMarca extends CustomPainter {
  _PintorMarca({
    required this.colorPuntos,
    required this.colorGuia,
    required this.colorBorde,
  });

  final Color colorPuntos;
  final Color colorGuia;
  final Color colorBorde;

  @override
  void paint(Canvas canvas, Size size) {
    // El dibujo original mide 68 unidades, pero se puede escalar al tamaño pedido.
    final escala = size.width / 68;
    // Posiciones de los puntos en el dibujo original: 26, 50 y 74.
    const posiciones = [26.0, 50.0, 74.0];
    Offset punto(double x, double y) =>
        Offset((x - 16) * escala, (y - 16) * escala);

    final pincel = Paint()..color = colorPuntos;
    for (final x in posiciones) {
      for (final y in posiciones) {
        // El del centro se dibuja aparte, en amarillo.
        if (x == 50 && y == 50) continue;
        canvas.drawCircle(punto(x, y), 6.5 * escala, pincel);
      }
    }

    final centro = punto(50, 50);
    canvas.drawCircle(centro, 13 * escala, Paint()..color = colorGuia);
    canvas.drawCircle(
      centro,
      13 * escala,
      Paint()
        ..color = colorBorde
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * escala,
    );
  }

  @override
  bool shouldRepaint(_PintorMarca anterior) {
    return anterior.colorPuntos != colorPuntos ||
        anterior.colorGuia != colorGuia ||
        anterior.colorBorde != colorBorde;
  }
}
