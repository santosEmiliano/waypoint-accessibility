import 'package:flutter_test/flutter_test.dart';

import 'package:waypoint/aplicacion.dart';

void main() {
  testWidgets('La aplicación arranca en el inicio de sesión', (tester) async {
    await tester.pumpWidget(const AplicacionWaypoint());

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
