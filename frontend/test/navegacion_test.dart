import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waypoint/aplicacion.dart';
import 'package:waypoint/componentes/dock_flotante.dart';
import 'package:waypoint/componentes/encabezado_web.dart';
import 'package:waypoint/servicios/repositorio_falso.dart';
import 'package:waypoint/servicios/sesion.dart';

void main() {
  // Simula la pantalla de un teléfono o de una computadora.
  void usarPantalla(WidgetTester tester, double ancho, double alto) {
    tester.view.physicalSize = Size(ancho, alto);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // Abre la app y entra escribiendo el correo y la contraseña.
  Future<void> entrarCon(
    WidgetTester tester,
    String correo,
    String contrasena,
  ) async {
    // Sin movimiento: el logo no respira y pumpAndSettle puede terminar.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final sesion = Sesion(
      repositorio: RepositorioFalso(retraso: Duration.zero),
    );
    await tester.pumpWidget(AplicacionWaypoint(sesion: sesion));
    await tester.enterText(find.byType(TextFormField).at(0), correo);
    await tester.enterText(find.byType(TextFormField).at(1), contrasena);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
  }

  Future<void> entrarComoUsuario(WidgetTester tester) =>
      entrarCon(tester, 'ana@ejemplo.com', 'contrasena123');

  Future<void> entrarComoOperador(WidgetTester tester) =>
      entrarCon(tester, 'operador@waypoint.local', 'Operador123!');

  testWidgets('el usuario ve Inicio, Reportes, Nuevo y Perfil', (tester) async {
    usarPantalla(tester, 390, 844);
    await entrarComoUsuario(tester);

    for (final nombre in ['Inicio', 'Reportes', 'Nuevo', 'Perfil']) {
      expect(find.text(nombre), findsOneWidget);
    }
    expect(find.text('Bandeja'), findsNothing);
  });

  testWidgets('el operador ve la Bandeja en lugar de Nuevo', (tester) async {
    usarPantalla(tester, 390, 844);
    await entrarComoOperador(tester);

    expect(find.text('Bandeja'), findsOneWidget);
    expect(find.text('Nuevo'), findsNothing);
  });

  testWidgets('al tocar Reportes se ve el listado', (tester) async {
    usarPantalla(tester, 390, 844);
    await entrarComoUsuario(tester);

    await tester.tap(find.text('Reportes'));
    await tester.pumpAndSettle();

    expect(find.text('Mis reportes'), findsOneWidget);
  });

  testWidgets('Nuevo abre el formulario y se puede volver', (tester) async {
    usarPantalla(tester, 390, 844);
    await entrarComoUsuario(tester);

    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo reporte'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Lo último'), findsOneWidget);
  });

  testWidgets('desde el listado se llega al detalle', (tester) async {
    usarPantalla(tester, 390, 844);
    await entrarComoUsuario(tester);

    await tester.tap(find.text('Reportes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elevador del edificio 3 sin servicio'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del reporte'), findsOneWidget);
  });

  testWidgets('en el celular se usa el dock', (tester) async {
    usarPantalla(tester, 390, 844);
    await entrarComoUsuario(tester);

    expect(find.byType(DockFlotante), findsOneWidget);
    expect(find.byType(EncabezadoWeb), findsNothing);
  });

  testWidgets('en pantalla ancha se usa el encabezado', (tester) async {
    usarPantalla(tester, 1280, 800);
    await entrarComoUsuario(tester);

    expect(find.byType(EncabezadoWeb), findsOneWidget);
    expect(find.byType(DockFlotante), findsNothing);
  });

  testWidgets('el perfil muestra con quién se inició sesión', (tester) async {
    usarPantalla(tester, 390, 844);
    await entrarComoUsuario(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Ana López'), findsOneWidget);
  });

  testWidgets('Salir regresa al inicio de sesión', (tester) async {
    usarPantalla(tester, 390, 844);
    await entrarComoUsuario(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
  });
}
