import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/aplicacion.dart';
import 'package:waypoint/componentes/dock_flotante.dart';
import 'package:waypoint/servicios/repositorio_falso.dart';
import 'package:waypoint/servicios/sesion.dart';

void main() {
  // Abre la app en un teléfono.
  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final sesion = Sesion(
      repositorio: RepositorioFalso(retraso: Duration.zero),
    );
    await tester.pumpWidget(AplicacionWaypoint(sesion: sesion));
  }

  Future<void> escribir(
    WidgetTester tester,
    String correo,
    String clave,
  ) async {
    await tester.enterText(find.byType(TextFormField).at(0), correo);
    await tester.enterText(find.byType(TextFormField).at(1), clave);
  }

  testWidgets('si se deja vacío avisa qué falta', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
  });

  testWidgets('un correo sin formato se rechaza', (tester) async {
    await abrir(tester);

    await escribir(tester, 'ana', 'contrasena123');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Escribe un correo válido'), findsOneWidget);
  });

  testWidgets('con datos incorrectos muestra el aviso del servidor', (
    tester,
  ) async {
    await abrir(tester);

    await escribir(tester, 'ana@ejemplo.com', 'incorrecta');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(
      find.text('El correo o la contraseña no son correctos'),
      findsOneWidget,
    );
    // Sigue en el inicio de sesión.
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('con datos correctos entra a la app', (tester) async {
    await abrir(tester);

    await escribir(tester, 'ana@ejemplo.com', 'contrasena123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.byType(DockFlotante), findsOneWidget);
  });

  testWidgets('la contraseña se puede mostrar y ocultar', (tester) async {
    await abrir(tester);

    expect(find.text('Mostrar'), findsOneWidget);
    await tester.tap(find.text('Mostrar'));
    await tester.pump();

    expect(find.text('Ocultar'), findsOneWidget);
  });

  testWidgets('Crea tu cuenta abre el registro', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Crea tu cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}
