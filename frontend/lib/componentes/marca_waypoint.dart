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
    this.pulso = 0,
  });

  final double tamano;

  /// Color de los 8 puntos de afuera.
  final Color? colorPuntos;

  /// Contorno del punto central.
  final Color? colorBorde;

  /// Anima el punto amarillo.
  final bool respira;

  /// Cada vez que este número cambia, del punto amarillo sale un anillo que
  /// se expande y se desvanece.
  final int pulso;

  @override
  State<MarcaWaypoint> createState() => _EstadoMarcaWaypoint();
}

class _EstadoMarcaWaypoint extends State<MarcaWaypoint>
    with TickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final Animation<double> _respiracion = CurvedAnimation(
    parent: _controlador,
    curve: Curves.easeInOut,
  );
  late final AnimationController _onda = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
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
    if (widget.pulso != anterior.pulso &&
        !MediaQuery.disableAnimationsOf(context)) {
      _onda.forward(from: 0);
    }
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
    _onda.dispose();
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
          onda: _onda,
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
    required this.onda,
  }) : super(repaint: Listenable.merge([respiracion, onda]));

  final Animation<double> respiracion;
  final Animation<double> onda;
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

    // Anillo que sale del punto, empieza un poco después y crece hasta 3 veces.
    final avance = const Interval(
      0.35,
      1,
      curve: Curves.easeOut,
    ).transform(onda.value);
    if (avance > 0 && avance < 1) {
      canvas.drawCircle(
        centro,
        15 * escala * (1 + 2 * avance),
        Paint()
          ..color = colorGuia.withValues(alpha: 0.9 * (1 - avance))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * escala,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorMarca anterior) {
    return anterior.colorPuntos != colorPuntos ||
        anterior.colorGuia != colorGuia ||
        anterior.colorBorde != colorBorde;
  }
}
