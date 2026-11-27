import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waypoint/aplicacion.dart';
import 'package:waypoint/modelos/reporte.dart';
import 'package:waypoint/servicios/datos_ejemplo.dart';
import 'package:waypoint/servicios/repositorio_falso.dart';
import 'package:waypoint/servicios/sesion.dart';
import 'package:waypoint/utilidades/fechas.dart';

import 'ayudas/repositorio_prueba.dart';

void main() {
  // Abre la app en un teléfono y entra como Ana.
  Future<void> entrarComoAna(
    WidgetTester tester, {
    RepositorioFalso? repositorio,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Sin movimiento: el logo no respira y pumpAndSettle puede terminar.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final sesion = Sesion(
      repositorio: repositorio ?? RepositorioFalso(retraso: Duration.zero),
    );
    await tester.pumpWidget(AplicacionWaypoint(sesion: sesion));
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@ejemplo.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'contrasena123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
  }

  testWidgets('saluda y dice cuántos reportes van en camino', (tester) async {
    await entrarComoAna(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
    // Ana tiene uno Reportado, uno En análisis y uno Resuelto (el cancelado no cuenta).
    expect(find.text('2 reportes siguen en camino'), findsOneWidget);
    expect(
      find.text('1 ya se resolvió. Toca una parada para ver sus reportes.'),
      findsOneWidget,
    );
  });

  testWidgets('el mapa cuenta los reportes de cada parada', (tester) async {
    await entrarComoAna(tester);

    expect(find.bySemanticsLabel('Reportado: 1 reporte'), findsOneWidget);
    expect(find.bySemanticsLabel('En análisis: 1 reporte'), findsOneWidget);
    expect(find.bySemanticsLabel('En atención: 0 reportes'), findsOneWidget);
    expect(find.bySemanticsLabel('Resuelto: 1 reporte'), findsOneWidget);
  });

  testWidgets('Lo último muestra los que se movieron más recientemente', (
    tester,
  ) async {
    await entrarComoAna(tester);

    final reportes = DatosEjemplo.reportes();
    final elevador = find.text(reportes[1].titulo);
    final banqueta = find.text(reportes[2].titulo);
    final rampa = find.text(reportes[0].titulo);
    // En el teléfono el último queda abajo del dock, así que se baja hasta él.
    await tester.scrollUntilVisible(rampa, 200);
    expect(elevador, findsOneWidget);
    expect(banqueta, findsOneWidget);
    expect(rampa, findsOneWidget);

    // El orden es por la fecha del último cambio, de más nuevo a más viejo.
    final y = tester.getTopLeft;
    expect(y(elevador).dy, lessThan(y(banqueta).dy));
    expect(y(banqueta).dy, lessThan(y(rampa).dy));

    expect(
      find.text('Reportado el ${fechaCorta(reportes[1].creacion)}'),
      findsOneWidget,
    );
    expect(
      find.text(
        'En análisis desde el ${fechaCorta(reportes[0].actualizacion)}',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Resuelto el ${fechaCorta(reportes[2].actualizacion)}'),
      findsOneWidget,
    );
  });

  testWidgets('cada reporte dice en qué parada va', (tester) async {
    await entrarComoAna(tester);
    final reportes = DatosEjemplo.reportes();
    await tester.scrollUntilVisible(find.text(reportes[0].titulo), 200);

    // La fila se lee completa (título, parada y fecha).
    String anuncio(Reporte r) => tester.getSemantics(find.text(r.titulo)).label;
    expect(anuncio(reportes[1]), contains('Parada 1 de 4'));
    expect(anuncio(reportes[0]), contains('Parada 2 de 4'));
    expect(anuncio(reportes[2]), contains('Parada 4 de 4'));
  });

  testWidgets('tocar una parada abre el listado filtrado por ella', (
    tester,
  ) async {
    await entrarComoAna(tester);

    await tester.tap(find.bySemanticsLabel('En análisis: 1 reporte'));
    await tester.pumpAndSettle();

    expect(find.text('Mis reportes'), findsOneWidget);
    expect(find.text('Parada: En análisis'), findsOneWidget);
  });

  testWidgets('el botón de reportar abre el formulario', (tester) async {
    await entrarComoAna(tester);

    await tester.tap(find.text('Reportar una barrera'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo reporte'), findsOneWidget);
  });

  testWidgets('tocar un reporte abre el detalle', (tester) async {
    await entrarComoAna(tester);

    await tester.tap(find.text(DatosEjemplo.reportes()[1].titulo));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del reporte'), findsOneWidget);
  });

  testWidgets('sin reportes invita a reportar el primero', (tester) async {
    await entrarComoAna(tester, repositorio: RepositorioPrueba(vacio: true));

    expect(find.text('Aún no tienes reportes'), findsOneWidget);
    expect(find.text('Lo último'), findsNothing);
    expect(find.text('Reportar una barrera'), findsOneWidget);
  });

  testWidgets('si falla la carga se puede reintentar', (tester) async {
    await entrarComoAna(tester, repositorio: RepositorioPrueba(fallas: 1));

    expect(find.text('No se pudo conectar con el servidor'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('2 reportes siguen en camino'), findsOneWidget);
  });

  testWidgets('no pide la lista completa de reportes', (tester) async {
    final repositorio = RepositorioPrueba();
    await entrarComoAna(tester, repositorio: repositorio);

    expect(repositorio.pedidos, isNotEmpty);
    // Nadie pide la lista completa, el Inicio pide 3 y el listado pide de 10 en 10.
    expect(repositorio.pedidos.every((p) => p.limite != null), isTrue);
  });

  group('fechaCorta', () {
    final hoy = DateTime(2026, 11, 26);

    test('en este año solo pone día y mes', () {
      expect(fechaCorta(DateTime(2026, 11, 18), hoy: hoy), '18 nov');
      expect(fechaCorta(DateTime(2026, 1, 3), hoy: hoy), '3 ene');
    });

    test('de otro año le agrega el año', () {
      expect(fechaCorta(DateTime(2025, 12, 31), hoy: hoy), '31 dic 2025');
    });
  });
}
