import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waypoint/aplicacion.dart';
import 'package:waypoint/tema/colores_waypoint.dart';
import 'package:waypoint/tema/tema_waypoint.dart';
import 'package:waypoint/tema/tipografia_waypoint.dart';

void main() {
  // Contexto de la pantalla que muestra la app, para leer su tema.
  BuildContext contextoDeLaApp(WidgetTester tester) {
    return tester.element(find.byType(Scaffold));
  }

  testWidgets('la app usa los colores claros por defecto', (tester) async {
    await tester.pumpWidget(const AplicacionWaypoint());

    final contexto = contextoDeLaApp(tester);
    expect(contexto.colores.suelo, ColoresWaypoint.claro.suelo);
  });

  testWidgets('la app usa los colores oscuros si el teléfono está en oscuro', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(const AplicacionWaypoint());

    final contexto = contextoDeLaApp(tester);
    expect(contexto.colores.suelo, ColoresWaypoint.oscuro.suelo);
  });

  testWidgets('el texto usa la fuente de Waypoint', (tester) async {
    await tester.pumpWidget(const AplicacionWaypoint());

    final estilo = Theme.of(contextoDeLaApp(tester)).textTheme.bodyLarge;
    expect(estilo!.fontFamily, familiaWaypoint);
  });

  testWidgets('el botón principal es fácil de tocar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaWaypoint.claro,
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('Entrar')),
          ),
        ),
      ),
    );

    final tamano = tester.getSize(find.byType(FilledButton));
    expect(tamano.height, greaterThanOrEqualTo(TemaWaypoint.altoBoton));
  });
}
