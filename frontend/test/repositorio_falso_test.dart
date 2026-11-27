import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/servicios/error_api.dart';
import 'package:waypoint/servicios/repositorio_falso.dart';
import 'package:waypoint/servicios/repositorio_waypoint.dart';

// Comprueba que el error tenga el código esperado.
Future<void> debeFallarCon(Future<dynamic> accion, String codigo) {
  return expectLater(
    accion,
    throwsA(isA<ErrorApi>().having((e) => e.codigo, 'codigo', codigo)),
  );
}

void main() {
  late RepositorioFalso repo;

  setUp(() {
    repo = RepositorioFalso(retraso: Duration.zero);
  });

  group('Sesión', () {
    test('con una contraseña incorrecta no deja entrar', () async {
      await debeFallarCon(
        repo.iniciarSesion('ana@ejemplo.com', 'incorrecta'),
        'CREDENCIALES_INVALIDAS',
      );
    });

    test('no se puede registrar un correo repetido', () async {
      await debeFallarCon(
        repo.registrar('Otra Ana', 'ana@ejemplo.com', 'contrasena123'),
        'CORREO_REGISTRADO',
      );
    });

    test('una contraseña corta se rechaza', () async {
      try {
        await repo.registrar('Pedro', 'pedro@ejemplo.com', 'corta');
        fail('Debió lanzar un error');
      } on ErrorApi catch (e) {
        expect(e.codigo, 'VALIDACION');
        expect(e.campos.containsKey('contrasena_usuario'), isTrue);
      }
    });

    test('sin iniciar sesión no se puede pedir nada', () async {
      await debeFallarCon(repo.listarReportes(), 'NO_AUTENTICADO');
    });
  });

  group('Reportes del usuario', () {
    setUp(() async {
      await repo.iniciarSesion('ana@ejemplo.com', 'contrasena123');
    });

    test('Ana solo ve sus reportes', () async {
      final lista = await repo.listarReportes();
      expect(lista.length, 3);
      expect(lista.every((r) => r.usuario.nombre == 'Ana López'), isTrue);
    });

    test(
      'un reporte nuevo nace en Reportado y aparece en el listado',
      () async {
        final nuevo = await repo.crearReporte(
          titulo: 'Puerta muy pesada',
          descripcion: 'No se puede abrir con una sola mano.',
          idCategoria: 1,
          ubicacion: 'Edificio 5',
        );
        expect(nuevo.estado.nombre, 'Reportado');
        expect((await repo.listarReportes()).length, 4);
      },
    );

    test('el listado viene por páginas sin repetir reportes', () async {
      for (var i = 0; i < 4; i++) {
        await repo.crearReporte(
          titulo: 'Reporte $i',
          descripcion: 'Algo',
          idCategoria: 1,
          ubicacion: 'Edificio 5',
        );
      }
      final primera = await repo.listarReportes(limite: 4);
      final segunda = await repo.listarReportes(limite: 4, desde: 4);
      expect(primera.length, 4);
      expect(segunda.length, 3);
      final ids = {...primera.map((r) => r.id), ...segunda.map((r) => r.id)};
      expect(ids.length, 7);
    });

    test('se puede ordenar por el último cambio', () async {
      final lista = await repo.listarReportes(
        orden: OrdenReportes.actualizacion,
      );
      for (var i = 1; i < lista.length; i++) {
        expect(
          lista[i - 1].actualizacion.isBefore(lista[i].actualizacion),
          isFalse,
        );
      }
    });

    test('el resumen cuenta por estado sin los cancelados', () async {
      // Ana: uno Reportado, uno En análisis, uno Resuelto y uno cancelado.
      expect(await repo.resumenReportes(), {1: 1, 2: 1, 3: 0, 4: 1});
      expect(await repo.resumenReportes(texto: 'elevador'), {
        1: 1,
        2: 0,
        3: 0,
        4: 0,
      });
    });

    test('un reporte sin título se rechaza', () async {
      await debeFallarCon(
        repo.crearReporte(
          titulo: '',
          descripcion: 'Algo',
          idCategoria: 1,
          ubicacion: 'Edificio 5',
        ),
        'VALIDACION',
      );
    });

    test('se puede cancelar un reporte que sigue en Reportado', () async {
      final cancelado = await repo.cancelarReporte(
        2,
        razon: 'Ya no hace falta',
      );
      expect(cancelado.cancelado, isTrue);
      expect(cancelado.razonCancelacion, 'Ya no hace falta');
    });

    test('no se puede cancelar uno que ya está en análisis', () async {
      await debeFallarCon(repo.cancelarReporte(1), 'REPORTE_NO_EDITABLE');
    });

    test('no se puede ver el reporte de otra persona', () async {
      await debeFallarCon(repo.obtenerReporte(4), 'NO_ENCONTRADO');
    });
  });

  group('Operador', () {
    setUp(() async {
      await repo.iniciarSesion('operador@waypoint.local', 'Operador123!');
    });

    test('ve los reportes de todos', () async {
      expect((await repo.listarReportes()).length, 4);
    });

    test('no puede crear reportes', () async {
      await debeFallarCon(
        repo.crearReporte(
          titulo: 'Algo',
          descripcion: 'Algo',
          idCategoria: 1,
          ubicacion: 'Algún lugar',
        ),
        'SIN_PERMISO',
      );
    });

    test('puede tomar un reporte sin operador', () async {
      final tomado = await repo.asignarReporte(2);
      expect(tomado.operador?.nombre, 'Operador de prueba');
    });

    test('no puede saltarse un estado', () async {
      // El reporte 1 está en análisis; pasar directo a Resuelto no se permite.
      await debeFallarCon(repo.cambiarEstado(1, 4), 'TRANSICION_INVALIDA');
    });

    test('pasa al siguiente estado', () async {
      final avanzado = await repo.cambiarEstado(1, 3);
      expect(avanzado.estado.nombre, 'En atención');
    });

    test('no resuelve sin la foto de la atención', () async {
      // El reporte 4 está en atención y todavía no tiene foto de atención.
      await debeFallarCon(repo.cambiarEstado(4, 4), 'FALTA_EVIDENCIA_ATENCION');

      await repo.subirEvidencia(4, Uint8List(0), 'atencion.jpg');
      final resuelto = await repo.cambiarEstado(4, 4);
      expect(resuelto.estado.nombre, 'Resuelto');
    });

    test('cada cambio queda en el historial', () async {
      final antes = (await repo.obtenerHistorial(1)).length;
      await repo.cambiarEstado(1, 3, comentario: 'Se empezó la obra');
      final historial = await repo.obtenerHistorial(1);
      expect(historial.length, antes + 1);
      expect(historial.last.tipo, 'cambio_estado');
    });
  });
}
