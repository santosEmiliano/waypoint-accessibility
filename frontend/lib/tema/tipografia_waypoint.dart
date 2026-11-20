import 'package:flutter/material.dart';

import 'colores_waypoint.dart';

/// Nombre de la fuente declarada en el pubspec.
const String familiaWaypoint = 'AtkinsonHyperlegibleNext';

/// Estilos de texto de la app, con los tamaños del diseño hecho en los mockups.
TextTheme textoWaypoint(ColoresWaypoint c) {
  // Crea un estilo con su tamaño, alto de línea en px, peso y espaciado.
  TextStyle estilo(
    double tamano,
    double alto,
    FontWeight peso, {
    double espaciado = 0,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: familiaWaypoint,
      fontSize: tamano,
      // Flutter pide el alto de línea como múltiplo del tamaño.
      height: alto / tamano,
      fontWeight: peso,
      letterSpacing: espaciado,
      color: color ?? c.tinta,
      // Los números tienen el mismo ancho, así las columnas no quedan desfazadas.
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  return TextTheme(
    displayLarge: estilo(58, 58, FontWeight.w800, espaciado: -1.6),
    headlineLarge: estilo(32, 36, FontWeight.w800, espaciado: -0.8),
    headlineMedium: estilo(27, 31, FontWeight.w800, espaciado: -0.5),
    titleLarge: estilo(20, 26, FontWeight.w800),
    titleMedium: estilo(17, 22, FontWeight.w700),
    titleSmall: estilo(15, 20, FontWeight.w700),
    bodyLarge: estilo(17, 24, FontWeight.w400),
    bodyMedium: estilo(15, 21, FontWeight.w400),
    bodySmall: estilo(14, 19, FontWeight.w400, color: c.tinta2),
    labelLarge: estilo(18, 22, FontWeight.w800),
    labelMedium: estilo(15, 20, FontWeight.w700),
    labelSmall: estilo(12.5, 16, FontWeight.w700),
  );
}
