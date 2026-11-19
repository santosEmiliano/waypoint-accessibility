import 'package:flutter_test/flutter_test.dart';

import 'package:waypoint/aplicacion.dart';

void main() {
  testWidgets('La aplicación arranca y muestra el nombre', (tester) async {
    await tester.pumpWidget(const AplicacionWaypoint());

    expect(find.text('Waypoint'), findsOneWidget);
  });
}
