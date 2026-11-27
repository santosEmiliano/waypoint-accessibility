import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../tema/colores_waypoint.dart';
import 'marca_waypoint.dart';
import 'nombre_waypoint.dart';

/// Bloque oscuro de la primera pantalla: la cuadrícula de puntos de fondo, el
/// logo, el nombre y la frase.
///
/// Sirve para entrar y para crear la cuenta. Con [registro] se encoge, la
/// cuadrícula avanza una celda, el título y la frase se cambian por los del
/// registro y del punto amarillo sale un anillo.
class CabeceraMarca extends StatefulWidget {
  const CabeceraMarca({super.key, this.registro = false});

  final bool registro;

  @override
  State<CabeceraMarca> createState() => _EstadoCabeceraMarca();
}

class _EstadoCabeceraMarca extends State<CabeceraMarca> {
  static const _duracion = Duration(milliseconds: 750);
  static const _curva = Cubic(0.65, 0, 0.25, 1);

  static const _fraseEntrar =
      'Reporta las barreras del campus y sigue cada reporte hasta que se resuelva.';
  static const _fraseRegistro =
      'Con tu correo puedes reportar barreras y seguir cada reporte.';

  // Cuenta los cambios de vista para lanzar un anillo en cada uno.
  int _pulso = 0;

  @override
  void didUpdateWidget(CabeceraMarca anterior) {
    super.didUpdateWidget(anterior);
    if (widget.registro != anterior.registro) _pulso++;
  }

  // Alto que ocupa un texto con el ancho disponible.
  double _alto(
    String texto,
    TextStyle estilo,
    double ancho,
    TextScaler escala,
  ) {
    final medidor = TextPainter(
      text: TextSpan(text: texto, style: estilo),
      textDirection: TextDirection.ltr,
      textScaler: escala,
    )..layout(maxWidth: ancho);
    final alto = medidor.height;
    medidor.dispose();
    return alto;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;
    final escala = MediaQuery.textScalerOf(context);

    final estiloNombre = texto.displayLarge!.copyWith(color: c.dockActivo);
    final estiloTituloRegistro = estiloNombre.copyWith(
      fontSize: 42,
      height: 46 / 42,
      letterSpacing: -1.1,
    );
    final estiloFrase = texto.titleMedium!.copyWith(
      color: c.dockActivo,
      fontWeight: FontWeight.w400,
    );

    return TweenAnimationBuilder<double>(
      // 0 es la vista de entrar y 1 la de crear la cuenta.
      tween: Tween<double>(end: widget.registro ? 1 : 0),
      duration: _duracion,
      curve: _curva,
      builder: (context, t, _) {
        return Container(
          width: double.infinity,
          color: c.dock,
          child: CustomPaint(
            // La cuadrícula avanza una celda (26) y queda igual que al inicio.
            painter: _PintorCuadricula(c.dockPastilla, -26 * t),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  lerpDouble(48, 24, t)!,
                  24,
                  lerpDouble(36, 28, t)!,
                ),
                // En pantallas anchas el contenido se queda alineado con el formulario.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SizedBox(
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, restricciones) {
                          final ancho = restricciones.maxWidth;
                          final altoNombre = escala.scale(58);
                          final altoTituloRegistro = escala.scale(46);
                          final altoFraseEntrar = _alto(
                            _fraseEntrar,
                            estiloFrase,
                            ancho,
                            escala,
                          );
                          final altoFraseRegistro = _alto(
                            _fraseRegistro,
                            estiloFrase,
                            ancho,
                            escala,
                          );

                          // Lo que sale se desvanece primero y lo que entra
                          // aparece un poco después, sin encimarse del todo.
                          final sale = (1 - t / 0.55).clamp(0.0, 1.0);
                          final entra = ((t - 0.4) / 0.6).clamp(0.0, 1.0);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MarcaWaypoint(
                                tamano: lerpDouble(56, 40, t)!,
                                colorPuntos: c.dockTexto,
                                colorBorde: c.dock,
                                respira: true,
                                pulso: _pulso,
                              ),
                              SizedBox(height: lerpDouble(24, 16, t)),
                              SizedBox(
                                height: lerpDouble(
                                  altoNombre,
                                  altoTituloRegistro,
                                  t,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (t < 1)
                                      Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Opacity(
                                          opacity: sale,
                                          child: Transform.translate(
                                            offset: Offset(0, -34 * t),
                                            child: ExcludeSemantics(
                                              excluding: widget.registro,
                                              child: NombreWaypoint(
                                                estilo: estiloNombre,
                                                colorPunto: c.guia,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (t > 0)
                                      Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Opacity(
                                          opacity: entra,
                                          child: Transform.translate(
                                            offset: Offset(0, 34 * (1 - t)),
                                            child: ExcludeSemantics(
                                              excluding: !widget.registro,
                                              child: Semantics(
                                                header: true,
                                                child: Text(
                                                  'Crea tu cuenta',
                                                  maxLines: 1,
                                                  style: estiloTituloRegistro,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: lerpDouble(
                                  altoFraseEntrar,
                                  altoFraseRegistro,
                                  t,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (t < 1)
                                      Opacity(
                                        opacity: sale,
                                        child: Transform.translate(
                                          offset: Offset(0, -18 * t),
                                          child: ExcludeSemantics(
                                            excluding: widget.registro,
                                            child: Text(
                                              _fraseEntrar,
                                              style: estiloFrase,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (t > 0)
                                      Opacity(
                                        opacity: entra,
                                        child: Transform.translate(
                                          offset: Offset(0, 18 * (1 - t)),
                                          child: ExcludeSemantics(
                                            excluding: !widget.registro,
                                            child: Text(
                                              _fraseRegistro,
                                              style: estiloFrase,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Cuadrícula de puntos. [desplazamiento] la mueve de lado sin que se noten los bordes.
class _PintorCuadricula extends CustomPainter {
  _PintorCuadricula(this.color, this.desplazamiento);

  final Color color;
  final double desplazamiento;

  @override
  void paint(Canvas canvas, Size size) {
    const separacion = 26.0;
    final pincel = Paint()..color = color;
    // Primer punto visible: uno antes del borde para que no quede un hueco.
    final inicio =
        ((separacion / 2 + desplazamiento) % separacion) - separacion;
    for (double x = inicio; x < size.width + separacion; x += separacion) {
      for (double y = separacion / 2; y < size.height; y += separacion) {
        canvas.drawCircle(Offset(x, y), 5, pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorCuadricula anterior) {
    return anterior.color != color || anterior.desplazamiento != desplazamiento;
  }
}
