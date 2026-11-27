import 'package:flutter/material.dart';

/// Colores del tema de Waypoint. Se leen con `context.colores`.
@immutable
class ColoresWaypoint extends ThemeExtension<ColoresWaypoint> {
  const ColoresWaypoint({
    required this.suelo,
    required this.placa,
    required this.placa2,
    required this.tinta,
    required this.tinta2,
    required this.linea,
    required this.linea2,
    required this.guia,
    required this.sobreGuia,
    required this.aviso,
    required this.dock,
    required this.dockPastilla,
    required this.dockTexto,
    required this.dockActivo,
    required this.dockBorde,
  });

  /// Fondo de las pantallas.
  final Color suelo;

  /// Campos y zonas elevadas.
  final Color placa;

  /// Fotos vacías y rellenos suaves.
  final Color placa2;

  /// Texto, botón principal y línea del recorrido.
  final Color tinta;

  /// Texto de apoyo.
  final Color tinta2;

  /// Bordes y separadores.
  final Color linea;

  /// Paradas y tramos pendientes.
  final Color linea2;

  /// El punto amarillo que marca dónde va un reporte.
  final Color guia;

  /// Texto y contorno sobre el amarillo.
  final Color sobreGuia;

  /// Lo que falta o falló.
  final Color aviso;

  /// Fondo del dock y del header web.
  final Color dock;

  /// Fondo del botón activo del dock.
  final Color dockPastilla;

  /// Texto del dock inactivo.
  final Color dockTexto;

  /// Texto del dock activo.
  final Color dockActivo;

  /// Borde del dock.
  final Color dockBorde;

  static const claro = ColoresWaypoint(
    suelo: Color(0xFFE8E8E3),
    placa: Color(0xFFF8F8F5),
    placa2: Color(0xFFDCDCD5),
    tinta: Color(0xFF1A1B18),
    tinta2: Color(0xFF54554E),
    linea: Color(0xFFC9C9C1),
    linea2: Color(0xFF7A7C73),
    guia: Color(0xFFD9B654),
    sobreGuia: Color(0xFF1A1B18),
    aviso: Color(0xFFA3392B),
    dock: Color(0xFF1A1B18),
    dockPastilla: Color(0xFF34362F),
    dockTexto: Color(0xFFC9CAC2),
    dockActivo: Color(0xFFF4F4EE),
    dockBorde: Color(0xFF1A1B18),
  );

  static const oscuro = ColoresWaypoint(
    suelo: Color(0xFF1B1C19),
    placa: Color(0xFF262723),
    placa2: Color(0xFF33352F),
    tinta: Color(0xFFEEEEE8),
    tinta2: Color(0xFFAEAFA6),
    linea: Color(0xFF3D3F39),
    linea2: Color(0xFF73756C),
    guia: Color(0xFFCFAE55),
    sobreGuia: Color(0xFF1A1B18),
    aviso: Color(0xFFE8A193),
    dock: Color(0xFF2C2E29),
    dockPastilla: Color(0xFF3F4139),
    dockTexto: Color(0xFFBDBEB5),
    dockActivo: Color(0xFFF4F4EE),
    dockBorde: Color(0xFF45473F),
  );

  @override
  ColoresWaypoint copyWith({
    Color? suelo,
    Color? placa,
    Color? placa2,
    Color? tinta,
    Color? tinta2,
    Color? linea,
    Color? linea2,
    Color? guia,
    Color? sobreGuia,
    Color? aviso,
    Color? dock,
    Color? dockPastilla,
    Color? dockTexto,
    Color? dockActivo,
    Color? dockBorde,
  }) {
    return ColoresWaypoint(
      suelo: suelo ?? this.suelo,
      placa: placa ?? this.placa,
      placa2: placa2 ?? this.placa2,
      tinta: tinta ?? this.tinta,
      tinta2: tinta2 ?? this.tinta2,
      linea: linea ?? this.linea,
      linea2: linea2 ?? this.linea2,
      guia: guia ?? this.guia,
      sobreGuia: sobreGuia ?? this.sobreGuia,
      aviso: aviso ?? this.aviso,
      dock: dock ?? this.dock,
      dockPastilla: dockPastilla ?? this.dockPastilla,
      dockTexto: dockTexto ?? this.dockTexto,
      dockActivo: dockActivo ?? this.dockActivo,
      dockBorde: dockBorde ?? this.dockBorde,
    );
  }

  @override
  ColoresWaypoint lerp(ThemeExtension<ColoresWaypoint>? other, double t) {
    if (other is! ColoresWaypoint) return this;
    return ColoresWaypoint(
      suelo: Color.lerp(suelo, other.suelo, t)!,
      placa: Color.lerp(placa, other.placa, t)!,
      placa2: Color.lerp(placa2, other.placa2, t)!,
      tinta: Color.lerp(tinta, other.tinta, t)!,
      tinta2: Color.lerp(tinta2, other.tinta2, t)!,
      linea: Color.lerp(linea, other.linea, t)!,
      linea2: Color.lerp(linea2, other.linea2, t)!,
      guia: Color.lerp(guia, other.guia, t)!,
      sobreGuia: Color.lerp(sobreGuia, other.sobreGuia, t)!,
      aviso: Color.lerp(aviso, other.aviso, t)!,
      dock: Color.lerp(dock, other.dock, t)!,
      dockPastilla: Color.lerp(dockPastilla, other.dockPastilla, t)!,
      dockTexto: Color.lerp(dockTexto, other.dockTexto, t)!,
      dockActivo: Color.lerp(dockActivo, other.dockActivo, t)!,
      dockBorde: Color.lerp(dockBorde, other.dockBorde, t)!,
    );
  }
}

/// Atajo para escribir `context.colores.guia` en cualquier widget.
extension ColoresDelContexto on BuildContext {
  ColoresWaypoint get colores => Theme.of(this).extension<ColoresWaypoint>()!;
}
