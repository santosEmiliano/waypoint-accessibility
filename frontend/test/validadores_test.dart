import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/utilidades/validadores.dart';

void main() {
  group('Correo', () {
    test('no puede estar vacío', () {
      expect(validarCorreo(''), 'Escribe tu correo');
      expect(validarCorreo('   '), 'Escribe tu correo');
    });

    test('tiene que parecer un correo', () {
      expect(validarCorreo('ana'), 'Escribe un correo válido');
      expect(validarCorreo('ana@ejemplo'), 'Escribe un correo válido');
    });

    test('uno correcto pasa', () {
      expect(validarCorreo('al123456@edu.uaa.mx'), isNull);
      expect(validarCorreo('  ana@ejemplo.com '), isNull);
    });
  });

  group('Contraseña', () {
    test('para entrar solo se pide que no esté vacía', () {
      expect(validarContrasenaEscrita(''), 'Escribe tu contraseña');
      expect(validarContrasenaEscrita('corta'), isNull);
    });

    test('para crear la cuenta se piden 8 caracteres', () {
      expect(validarContrasenaNueva(''), 'Escribe una contraseña');
      expect(validarContrasenaNueva('1234567'), 'Usa al menos 8 caracteres');
      expect(validarContrasenaNueva('12345678'), isNull);
    });
  });

  group('Nombre', () {
    test('no puede estar vacío', () {
      expect(validarNombre(' '), 'Escribe tu nombre');
    });

    test('no puede pasar de 100 caracteres', () {
      expect(validarNombre('a' * 101), 'El nombre es demasiado largo');
      expect(validarNombre('Ana López'), isNull);
    });
  });
}
