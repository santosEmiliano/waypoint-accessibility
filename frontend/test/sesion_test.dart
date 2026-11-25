import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/servicios/error_api.dart';
import 'package:waypoint/servicios/repositorio_falso.dart';
import 'package:waypoint/servicios/sesion.dart';

void main() {
  late Sesion sesion;

  setUp(() {
    sesion = Sesion(repositorio: RepositorioFalso(retraso: Duration.zero));
  });

  test('al empezar no hay sesión', () {
    expect(sesion.iniciada, isFalse);
  });

  test('al iniciar sesión se guarda el usuario', () async {
    await sesion.iniciarSesion('ana@ejemplo.com', 'contrasena123');
    expect(sesion.iniciada, isTrue);
    expect(sesion.usuario?.nombre, 'Ana López');
  });

  test('con datos incorrectos no se inicia sesión', () async {
    await expectLater(
      sesion.iniciarSesion('ana@ejemplo.com', 'incorrecta'),
      throwsA(isA<ErrorApi>()),
    );
    expect(sesion.iniciada, isFalse);
  });

  test('el operador se reconoce por su rol', () async {
    await sesion.iniciarSesion('operador@waypoint.local', 'Operador123!');
    expect(sesion.usuario?.esOperador, isTrue);
  });

  test('al cerrar la sesión se borra el usuario', () async {
    await sesion.iniciarSesion('ana@ejemplo.com', 'contrasena123');
    await sesion.cerrar();
    expect(sesion.iniciada, isFalse);
  });
}
