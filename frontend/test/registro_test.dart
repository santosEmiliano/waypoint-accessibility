import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/aplicacion.dart';
import 'package:waypoint/componentes/dock_flotante.dart';
import 'package:waypoint/servicios/repositorio_falso.dart';
import 'package:waypoint/servicios/sesion.dart';

void main() {
  // Abre la app en un teléfono y pasa a la vista de crear la cuenta.
  Future<void> abrirRegistro(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Sin movimiento activado en el celular, el logo no respira y pumpAndSettle puede terminar.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final sesion = Sesion(
      repositorio: RepositorioFalso(retraso: Duration.zero),
    );
    await tester.pumpWidget(AplicacionWaypoint(sesion: sesion));
    await tester.tap(find.text('Crea tu cuenta'));
    await tester.pumpAndSettle();
  }

  Future<void> escribir(
    WidgetTester tester,
    String nombre,
    String correo,
    String clave,
  ) async {
    await tester.enterText(find.byType(TextFormField).at(0), nombre);
    await tester.enterText(find.byType(TextFormField).at(1), correo);
    await tester.enterText(find.byType(TextFormField).at(2), clave);
  }

  testWidgets('la vista de registro trae sus tres campos y el título', (
    tester,
  ) async {
    await abrirRegistro(tester);

    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    // Ya no está el formulario de entrar.
    expect(find.text('Entrar'), findsNothing);
  });

  testWidgets('si se deja vacío avisa qué falta', (tester) async {
    await abrirRegistro(tester);

    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.text('Escribe tu nombre'), findsOneWidget);
    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe una contraseña'), findsOneWidget);
  });

  testWidgets('una contraseña de menos de 8 caracteres se rechaza', (
    tester,
  ) async {
    await abrirRegistro(tester);

    await escribir(tester, 'Marta Ruiz', 'marta@ejemplo.com', 'corta');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.text('Usa al menos 8 caracteres'), findsOneWidget);
  });

  testWidgets('un correo ya registrado se avisa debajo del correo', (
    tester,
  ) async {
    await abrirRegistro(tester);

    await escribir(tester, 'Otra Ana', 'ana@ejemplo.com', 'contrasena123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Ya existe una cuenta con ese correo'), findsOneWidget);
    expect(find.byType(DockFlotante), findsNothing);
  });

  testWidgets('con datos correctos crea la cuenta y entra a la app', (
    tester,
  ) async {
    await abrirRegistro(tester);

    await escribir(tester, 'Marta Ruiz', 'marta@ejemplo.com', 'contrasena123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.byType(DockFlotante), findsOneWidget);
  });

  testWidgets('Entra regresa al formulario de entrar', (tester) async {
    await abrirRegistro(tester);

    await tester.tap(find.text('Entra'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsNothing);
    expect(find.bySemanticsLabel('Waypoint'), findsOneWidget);
  });

  group('el teclado', () {
    testWidgets('se cierra al tocar fuera de los campos', (tester) async {
      await abrirRegistro(tester);

      await tester.tap(find.byType(TextFormField).first);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.textContaining('Con tu correo puedes'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('sigue abierto al pasar de un campo a otro', (tester) async {
      await abrirRegistro(tester);

      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pump();
      await tester.tap(find.byType(TextFormField).at(1));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isTrue);
    });
  });
}
