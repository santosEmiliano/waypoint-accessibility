import 'package:flutter/material.dart';

import '../tema/colores_waypoint.dart';

/// El logo de waypoint. Una cuadrícula de 3 × 3 puntos con el centro amarillo.
///
/// Con [respira] el punto amarillo crece y se hace pequeño despacio.
class MarcaWaypoint extends StatefulWidget {
  const MarcaWaypoint({
    super.key,
    this.tamano = 32,
    this.colorPuntos,
    this.colorBorde,
    this.respira = false,
  });

  final double tamano;

  /// Color de los 8 puntos de afuera.
  final Color? colorPuntos;

  /// Contorno del punto central.
  final Color? colorBorde;

  /// Anima el punto amarillo.
  final bool respira;

  @override
  State<MarcaWaypoint> createState() => _EstadoMarcaWaypoint();
}

class _EstadoMarcaWaypoint extends State<MarcaWaypoint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final Animation<double> _respiracion = CurvedAnimation(
    parent: _controlador,
    curve: Curves.easeInOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizarAnimacion();
  }

  @override
  void didUpdateWidget(MarcaWaypoint anterior) {
    super.didUpdateWidget(anterior);
    _actualizarAnimacion();
  }

  void _actualizarAnimacion() {
    final animar = widget.respira && !MediaQuery.disableAnimationsOf(context);
    if (animar && !_controlador.isAnimating) {
      _controlador.repeat(reverse: true);
    } else if (!animar && _controlador.isAnimating) {
      _controlador.stop();
      _controlador.value = 0;
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    // Es decorado.
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(widget.tamano),
        painter: _PintorMarca(
          colorPuntos: widget.colorPuntos ?? c.tinta,
          colorGuia: c.guia,
          colorBorde: widget.colorBorde ?? c.sobreGuia,
          respiracion: _respiracion,
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
    required this.respiracion,
  }) : super(repaint: respiracion);

  final Animation<double> respiracion;
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

    // El punto central crece hasta un 12 %, sin llegar a tocar a los vecinos.
    final latido = 1 + 0.12 * respiracion.value;
    final centro = punto(50, 50);
    canvas.drawCircle(centro, 13 * escala * latido, Paint()..color = colorGuia);
    canvas.drawCircle(
      centro,
      13 * escala * latido,
      Paint()
        ..color = colorBorde
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * escala * latido,
    );
  }

  @override
  bool shouldRepaint(_PintorMarca anterior) {
    return anterior.colorPuntos != colorPuntos ||
        anterior.colorGuia != colorGuia ||
        anterior.colorBorde != colorBorde;
  }
}
