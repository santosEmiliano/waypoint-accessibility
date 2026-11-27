import 'dart:async';

import 'package:flutter/material.dart';

import '../tema/colores_waypoint.dart';

/// Qué parte de la línea del río pasa por un tramo.
enum LineaRio {
  /// De arriba abajo, el tramo va en medio del recorrido.
  completa,

  /// Del centro hacia abajo, la primera parada.
  desdeElCentro,

  /// De arriba al centro, la última parada, donde termina el río.
  hastaElCentro,

  /// Sin línea, lo que queda después del destino, o una parada sola.
  ninguna,
}

/// Un renglón del río del listado, a la izquierda va la línea vertical (y el
/// círculo, si es una parada) y a la derecha el contenido.
///
/// Al aparecer, la línea se dibuja de arriba abajo, el círculo crece cuando
/// la línea llega a él y el contenido sube mientras aparece. Con [retraso]
/// cada renglón empieza un poco después del anterior, así la línea parece
/// recorrer la lista. Si [animar] es false o el teléfono pide menos
/// movimiento, aparece completo sin la animación..
class TramoRio extends StatefulWidget {
  const TramoRio({
    super.key,
    required this.child,
    this.linea = LineaRio.completa,
    this.parada = false,
    this.destino = false,
    this.animar = true,
    this.retraso = Duration.zero,
  });

  final Widget child;
  final LineaRio linea;

  /// Si lleva el círculo de una parada.
  final bool parada;

  /// La parada final va rellena.
  final bool destino;

  final bool animar;
  final Duration retraso;

  /// Ancho de la columna de la línea, incluido el espacio hasta el contenido.
  static const margen = 40.0;

  @override
  State<TramoRio> createState() => _EstadoTramoRio();
}

class _EstadoTramoRio extends State<TramoRio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  late final Animation<double> _linea = CurvedAnimation(
    parent: _controlador,
    curve: const Interval(0, 0.6, curve: Curves.easeInOut),
  );
  late final Animation<double> _circulo = CurvedAnimation(
    parent: _controlador,
    curve: const Interval(0.3, 0.75, curve: Curves.easeOutBack),
  );
  late final Animation<double> _contenido = CurvedAnimation(
    parent: _controlador,
    curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
  );

  bool _iniciado = false;
  Timer? _espera;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (!widget.animar || MediaQuery.disableAnimationsOf(context)) {
      _controlador.value = 1;
    } else {
      _espera = Timer(widget.retraso, _controlador.forward);
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return CustomPaint(
      painter: _PintorTramo(
        linea: widget.linea,
        parada: widget.parada,
        destino: widget.destino,
        tinta: c.tinta,
        fondo: c.suelo,
        avanceLinea: _linea,
        avanceCirculo: _circulo,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: TramoRio.margen),
        child: AnimatedBuilder(
          animation: _contenido,
          builder: (context, hijo) => Opacity(
            opacity: _contenido.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - _contenido.value)),
              child: hijo,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PintorTramo extends CustomPainter {
  _PintorTramo({
    required this.linea,
    required this.parada,
    required this.destino,
    required this.tinta,
    required this.fondo,
    required this.avanceLinea,
    required this.avanceCirculo,
  }) : super(repaint: Listenable.merge([avanceLinea, avanceCirculo]));

  final LineaRio linea;
  final bool parada;
  final bool destino;
  final Color tinta;
  final Color fondo;
  final Animation<double> avanceLinea;
  final Animation<double> avanceCirculo;

  // La línea y el círculo van centrados en x = 12 (el círculo mide 24).
  static const _x = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.height / 2;
    final (inicio, fin) = switch (linea) {
      LineaRio.completa => (0.0, size.height),
      LineaRio.desdeElCentro => (centro, size.height),
      LineaRio.hastaElCentro => (0.0, centro),
      LineaRio.ninguna => (0.0, 0.0),
    };

    // La línea crece de arriba abajo.
    final hasta = inicio + (fin - inicio) * avanceLinea.value;
    if (hasta > inicio) {
      canvas.drawRect(
        Rect.fromLTRB(_x - 2, inicio, _x + 2, hasta),
        Paint()..color = tinta,
      );
    }

    if (parada && avanceCirculo.value > 0) {
      final escala = avanceCirculo.value;
      final punto = Offset(_x, centro);
      canvas.drawCircle(punto, 12 * escala, Paint()..color = tinta);
      if (!destino) {
        canvas.drawCircle(punto, 8 * escala, Paint()..color = fondo);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorTramo anterior) {
    return anterior.linea != linea ||
        anterior.parada != parada ||
        anterior.destino != destino ||
        anterior.tinta != tinta ||
        anterior.fondo != fondo;
  }
}
