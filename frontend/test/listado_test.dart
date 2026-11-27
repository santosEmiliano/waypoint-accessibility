import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waypoint/aplicacion.dart';
import 'package:waypoint/servicios/sesion.dart';

import 'ayudas/repositorio_prueba.dart';

void main() {
  const elevador = 'Elevador del edificio 3 sin servicio';
  const rampa = 'Rampa rota en el edificio 1';
  const banqueta = 'Banqueta sin rampa frente a la biblioteca';

  // Abre la app en un teléfono, entra y va a la pestaña Reportes.
  Future<void> abrirListado(
    WidgetTester tester, {
    RepositorioPrueba? repositorio,
    String correo = 'ana@ejemplo.com',
    String contrasena = 'contrasena123',
    Future<void> Function(RepositorioPrueba)? antes,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Sin movimiento: el logo no respira y pumpAndSettle puede terminar.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = repositorio ?? RepositorioPrueba();
    if (antes != null) await tester.runAsync(() => antes(repo));
    await tester.pumpWidget(
      AplicacionWaypoint(sesion: Sesion(repositorio: repo)),
    );
    await tester.enterText(find.byType(TextFormField).at(0), correo);
    await tester.enterText(find.byType(TextFormField).at(1), contrasena);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reportes'));
    await tester.pumpAndSettle();
  }

  // Escribe en el buscador y espera a que pase la pausa de la búsqueda.
  Future<void> buscar(WidgetTester tester, String texto) async {
    await tester.enterText(find.byType(TextField).last, texto);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('agrupa los reportes por parada con su conteo', (tester) async {
    await abrirListado(tester);

    expect(find.text('Mis reportes'), findsOneWidget);
    expect(find.bySemanticsLabel('Reportado: 1 reporte'), findsWidgets);
    expect(find.bySemanticsLabel('En atención: 0 reportes'), findsWidgets);

    // Cada reporte queda debajo de su parada.
    final y = tester.getTopLeft;
    expect(y(find.text(elevador)).dy, lessThan(y(find.text(rampa)).dy));
  });

  testWidgets('Resuelto empieza plegado y no se pide hasta abrirlo', (
    tester,
  ) async {
    final repo = RepositorioPrueba();
    await abrirListado(tester, repositorio: repo);

    expect(find.text(banqueta), findsNothing);
    expect(repo.pedidos.where((p) => p.idEstado == 4), isEmpty);

    await tester.tap(find.text('Mostrar'));
    await tester.pumpAndSettle();

    expect(find.text(banqueta), findsOneWidget);
    expect(find.text('Ocultar'), findsOneWidget);
    expect(repo.pedidos.where((p) => p.idEstado == 4), isNotEmpty);
  });

  testWidgets('pide los reportes de 10 en 10', (tester) async {
    final repo = RepositorioPrueba();
    await abrirListado(
      tester,
      repositorio: repo,
      antes: (repo) async {
        await repo.iniciarSesion('ana@ejemplo.com', 'contrasena123');
        for (var i = 1; i <= 12; i++) {
          await repo.crearReporte(
            titulo: 'Reporte de prueba $i',
            descripcion: 'Algo',
            idCategoria: 1,
            ubicacion: 'Edificio 5',
          );
        }
      },
    );

    final lista = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    // Reportado tiene 13: llegan 10 y faltan 3.
    expect(repo.pedidos.every((p) => p.limite == 10 || p.limite == 3), isTrue);
    final mas = find.text('Mostrar 3 más de Reportado');
    await tester.scrollUntilVisible(mas, 300, scrollable: lista);
    await tester.tap(mas);
    await tester.pumpAndSettle();

    expect(mas, findsNothing);
    expect(repo.pedidos.any((p) => p.idEstado == 1 && p.desde == 10), isTrue);
    await tester.scrollUntilVisible(
      find.text(elevador),
      300,
      scrollable: lista,
    );
    expect(find.text(elevador), findsOneWidget);
  });

  testWidgets('la búsqueda filtra los reportes', (tester) async {
    await abrirListado(tester);

    await buscar(tester, 'elevador');

    expect(find.text(elevador), findsOneWidget);
    expect(find.text(rampa), findsNothing);
    expect(find.bySemanticsLabel('En análisis: 0 reportes'), findsOneWidget);
  });

  testWidgets('sin resultados se pueden quitar los filtros', (tester) async {
    await abrirListado(tester);

    await buscar(tester, 'no existe nada así');
    expect(find.text('No hay reportes con esa búsqueda'), findsOneWidget);

    await tester.tap(find.text('Quitar filtros'));
    await tester.pumpAndSettle();
    expect(find.text(elevador), findsOneWidget);
    expect(find.text(rampa), findsOneWidget);
  });

  testWidgets('se puede filtrar por categoría', (tester) async {
    await abrirListado(tester);

    await tester.tap(find.bySemanticsLabel('Filtrar por categoría'));
    await tester.pumpAndSettle();
    // "Otro" va al final de la lista.
    final y = tester.getTopLeft;
    expect(
      y(find.text('Otro')).dy,
      greaterThan(y(find.text('Señalización')).dy),
    );

    await tester.tap(find.text('Elevadores'));
    await tester.pumpAndSettle();

    expect(find.text('Categoría: Elevadores'), findsOneWidget);
    expect(find.text(elevador), findsOneWidget);
    expect(find.text(rampa), findsNothing);

    // Quitar el chip regresa todo.
    await tester.tap(find.byTooltip('Quitar el filtro de categoría'));
    await tester.pumpAndSettle();
    expect(find.text(rampa), findsOneWidget);
  });

  testWidgets('el operador ve "Reportes" con los de todos', (tester) async {
    await abrirListado(
      tester,
      correo: 'operador@waypoint.local',
      contrasena: 'Operador123!',
    );

    expect(find.text('Reportes'), findsWidgets);
    expect(find.text('Mis reportes'), findsNothing);
    expect(
      find.text('Falta guía podotáctil en el pasillo principal'),
      findsOneWidget,
    );
  });

  testWidgets('tocar un reporte abre el detalle', (tester) async {
    await abrirListado(tester);

    await tester.tap(find.text(elevador));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del reporte'), findsOneWidget);
  });

  testWidgets('si falla la carga se puede reintentar', (tester) async {
    // Fallan las 2 peticiones de reportes de Inicio... y la del listado.
    final repo = RepositorioPrueba(fallas: 2);
    await abrirListado(tester, repositorio: repo);

    expect(find.text('No se pudo conectar con el servidor'), findsWidgets);
    await tester.tap(find.text('Reintentar').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text(elevador), findsOneWidget);
  });
}
