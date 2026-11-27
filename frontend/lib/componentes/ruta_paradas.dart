import 'package:flutter/material.dart';

import '../tema/colores_waypoint.dart';

/// Ruta pequeña que sale al lado de la sección "lo ultimo" con las paradas de un
/// reporte, las paradas que ya pasó van rellenas, la parada en la que va lleva el
/// punto amarillo y las que faltan van vacías.
class RutaParadas extends StatelessWidget {
  const RutaParadas({super.key, required this.parada, this.total = 4});

  /// Parada en la que va el reporte, empezando en 1 (esto sale del contrato con la APi y la BD).
  final int parada;

  /// Cuántas paradas tiene el recorrido.
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      label: 'Parada $parada de $total',
      child: CustomPaint(
        size: const Size(76, 16),
        painter: _PintorRuta(
          parada: parada.clamp(1, total),
          total: total,
          tinta: c.tinta,
          pendiente: c.linea2,
          fondo: c.suelo,
          guia: c.guia,
          sobreGuia: c.sobreGuia,
        ),
      ),
    );
  }
}

class _PintorRuta extends CustomPainter {
  _PintorRuta({
    required this.parada,
    required this.total,
    required this.tinta,
    required this.pendiente,
    required this.fondo,
    required this.guia,
    required this.sobreGuia,
  });

  final int parada;
  final int total;
  final Color tinta;
  final Color pendiente;
  final Color fondo;
  final Color guia;
  final Color sobreGuia;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    // Los extremos dejan espacio para el punto amarillo, que es el más grande.
    const margen = 8.0;
    final paso = (size.width - margen * 2) / (total - 1);
    Offset centro(int i) => Offset(margen + paso * i, y);

    // Pedazos del recorrido hecho son más gruesos y oscuros que los que faltan.
    for (var i = 0; i < total - 1; i++) {
      final hecho = i + 1 < parada;
      canvas.drawLine(
        centro(i),
        centro(i + 1),
        Paint()
          ..color = hecho ? tinta : pendiente
          ..strokeWidth = hecho ? 4 : 2,
      );
    }

    for (var i = 0; i < total; i++) {
      final numero = i + 1;
      if (numero == parada) {
        // El estado actual es amarillo con contorno y un círculo del color del fondo para dar un
        // mejor diseño.
        canvas.drawCircle(centro(i), 10, Paint()..color = fondo);
        canvas.drawCircle(centro(i), 8, Paint()..color = sobreGuia);
        canvas.drawCircle(centro(i), 5, Paint()..color = guia);
      } else if (numero < parada) {
        canvas.drawCircle(centro(i), 5, Paint()..color = tinta);
      } else {
        canvas.drawCircle(centro(i), 5, Paint()..color = fondo);
        canvas.drawCircle(
          centro(i),
          4,
          Paint()
            ..color = pendiente
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorRuta anterior) {
    return anterior.parada != parada ||
        anterior.total != total ||
        anterior.tinta != tinta ||
        anterior.pendiente != pendiente ||
        anterior.fondo != fondo ||
        anterior.guia != guia ||
        anterior.sobreGuia != sobreGuia;
  }
}
