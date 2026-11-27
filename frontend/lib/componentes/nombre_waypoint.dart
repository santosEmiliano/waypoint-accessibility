import 'package:flutter/material.dart';

/// El nombre "Waypoint" con el punto de la "i" en amarillo.
///
/// Se escribe con la "ı" sin punto y el punto amarillo se dibuja encima.
/// Las medidas (centro a 0,181 em del inicio de la letra y a 0,671 em
/// de la línea base, radio de 0,095 em) son las del punto de la "i"
/// de Atkinson Hyperlegible Next en peso 800.
class NombreWaypoint extends StatelessWidget {
  const NombreWaypoint({
    super.key,
    required this.estilo,
    required this.colorPunto,
  });

  final TextStyle estilo;
  final Color colorPunto;

  static const _texto = 'Waypoınt';
  static const _posicionDeLaI = 5;

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);
    final tamano = escala.scale(estilo.fontSize!);

    final medidor = TextPainter(
      text: TextSpan(text: _texto, style: estilo),
      textDirection: TextDirection.ltr,
      textScaler: escala,
    )..layout();
    final inicioI = medidor
        .getOffsetForCaret(
          const TextPosition(offset: _posicionDeLaI),
          Rect.zero,
        )
        .dx;
    final lineaBase = medidor.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final centro = Offset(inicioI + 0.181 * tamano, lineaBase - 0.671 * tamano);
    final tamanoTexto = medidor.size;
    medidor.dispose();

    // Para los lectores de pantalla es el título "Waypoint", no "Waypoınt".
    return Semantics(
      header: true,
      label: 'Waypoint',
      excludeSemantics: true,
      child: SizedBox(
        width: tamanoTexto.width,
        height: tamanoTexto.height,
        child: CustomPaint(
          foregroundPainter: _PintorPunto(
            centro: centro,
            radio: 0.095 * tamano,
            color: colorPunto,
          ),
          child: Text(_texto, style: estilo, textScaler: escala),
        ),
      ),
    );
  }
}

class _PintorPunto extends CustomPainter {
  _PintorPunto({
    required this.centro,
    required this.radio,
    required this.color,
  });

  final Offset centro;
  final double radio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(centro, radio, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PintorPunto anterior) {
    return anterior.centro != centro ||
        anterior.radio != radio ||
        anterior.color != color;
  }
}
