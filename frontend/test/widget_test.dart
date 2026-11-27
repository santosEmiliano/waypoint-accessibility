import 'package:flutter_test/flutter_test.dart';

import 'package:waypoint/aplicacion.dart';

void main() {
  testWidgets('La aplicación arranca en el inicio de sesión', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const AplicacionWaypoint());

    expect(find.bySemanticsLabel('Waypoint'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
