import 'package:flutter/material.dart';

import 'colores_waypoint.dart';
import 'tipografia_waypoint.dart';

/// Temas claro y oscuro de Waypoint.
class TemaWaypoint {
  TemaWaypoint._();

  static final ThemeData claro = _construir(
    ColoresWaypoint.claro,
    Brightness.light,
  );

  static final ThemeData oscuro = _construir(
    ColoresWaypoint.oscuro,
    Brightness.dark,
  );

  static const double radioCampo = 14;
  static const double radioBoton = 16;
  static const double altoBoton = 56;

  /// Ningún objetivo táctil debe medir menos de esto.
  static const double altoMinimoTactil = 44;

  static ThemeData _construir(ColoresWaypoint c, Brightness brillo) {
    // Traduce nuestros colores a los que "Material" espera.
    final esquema = ColorScheme(
      brightness: brillo,
      primary: c.tinta,
      onPrimary: c.suelo,
      secondary: c.guia,
      onSecondary: c.sobreGuia,
      error: c.aviso,
      onError: brillo == Brightness.light ? c.placa : c.sobreGuia,
      surface: c.suelo,
      onSurface: c.tinta,
      onSurfaceVariant: c.tinta2,
      surfaceContainerLowest: c.suelo,
      surfaceContainerLow: c.placa,
      surfaceContainer: c.placa,
      surfaceContainerHigh: c.placa2,
      surfaceContainerHighest: c.placa2,
      outline: c.linea2,
      outlineVariant: c.linea,
      inverseSurface: c.tinta,
      onInverseSurface: c.suelo,
    );

    final texto = textoWaypoint(c);
    final formaBoton = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radioBoton),
    );

    // Borde de un botón, con el foco desde el teclado se engrosa a 3 px.
    WidgetStateBorderSide contorno({required Color color, double grosor = 2}) {
      return WidgetStateBorderSide.resolveWith((estados) {
        if (estados.contains(WidgetState.focused)) {
          return BorderSide(color: c.tinta, width: 3);
        }
        return BorderSide(color: color, width: grosor);
      });
    }

    // Borde de un campo de texto.
    OutlineInputBorder bordeCampo(Color color, double grosor) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(radioCampo),
        borderSide: BorderSide(color: color, width: grosor),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      scaffoldBackgroundColor: c.suelo,
      canvasColor: c.suelo,
      fontFamily: familiaWaypoint,
      textTheme: texto,
      primaryTextTheme: texto,
      // Aquí es donde se utiliza la paletade Waypoint para leerla con context.colores.
      extensions: [c],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerTheme: DividerThemeData(color: c.linea, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.tinta, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: c.suelo,
        foregroundColor: c.tinta,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: texto.headlineLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.placa,
        hintStyle: texto.bodyLarge!.copyWith(color: c.tinta2),
        errorStyle: texto.bodySmall!.copyWith(color: c.aviso),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: bordeCampo(c.linea, 2),
        enabledBorder: bordeCampo(c.linea, 2),
        focusedBorder: bordeCampo(c.tinta, 3),
        errorBorder: bordeCampo(c.aviso, 2),
        focusedErrorBorder: bordeCampo(c.aviso, 3),
      ),
      // Botón principal, de tinta.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.tinta,
          foregroundColor: c.suelo,
          disabledBackgroundColor: c.placa2,
          disabledForegroundColor: c.tinta2,
          minimumSize: const Size(64, altoBoton),
          shape: formaBoton,
          textStyle: texto.labelLarge,
        ).copyWith(side: contorno(color: Colors.transparent, grosor: 0)),
      ),
      // Botón secundario, con contorno.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.tinta,
          minimumSize: const Size(64, altoBoton),
          shape: formaBoton,
          textStyle: texto.labelLarge!.copyWith(fontSize: 16),
        ).copyWith(side: contorno(color: c.tinta)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.tinta,
          minimumSize: const Size(64, altoMinimoTactil),
          textStyle: texto.labelMedium!.copyWith(
            decoration: TextDecoration.underline,
            decorationThickness: 2,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.tinta,
          minimumSize: const Size(altoMinimoTactil, altoMinimoTactil),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.tinta,
        contentTextStyle: texto.bodyMedium!.copyWith(color: c.suelo),
        shape: formaBoton,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.guia),
    );
  }
}
