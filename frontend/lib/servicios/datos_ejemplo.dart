import '../modelos/categoria.dart';
import '../modelos/estado.dart';
import '../modelos/evidencia.dart';
import '../modelos/movimiento.dart';
import '../modelos/reporte.dart';
import '../modelos/usuario.dart';

/// Una cuenta de prueba con su contraseña.
class CuentaEjemplo {
  final Usuario usuario;
  final String contrasena;

  const CuentaEjemplo({required this.usuario, required this.contrasena});
}

/// Datos inventados para desarrollar sin servidor.
/// Cada método devuelve listas nuevas, porque el repositorio las modifica.
class DatosEjemplo {
  static const categorias = [
    Categoria(id: 1, nombre: 'Rampas y accesos'),
    Categoria(id: 2, nombre: 'Elevadores'),
    Categoria(id: 3, nombre: 'Rutas y banquetas'),
    Categoria(id: 4, nombre: 'Señalización'),
    Categoria(id: 5, nombre: 'Baños'),
    Categoria(id: 6, nombre: 'Mobiliario'),
    Categoria(id: 7, nombre: 'Iluminación'),
    Categoria(id: 8, nombre: 'Otro'),
  ];

  static const estados = [
    Estado(id: 1, nombre: 'Reportado', orden: 1),
    Estado(id: 2, nombre: 'En análisis', orden: 2),
    Estado(id: 3, nombre: 'En atención', orden: 3),
    Estado(id: 4, nombre: 'Resuelto', orden: 4),
  ];

  static DateTime _haceDias(int dias) {
    return DateTime.now().subtract(Duration(days: dias));
  }

  static List<CuentaEjemplo> cuentas() {
    return [
      CuentaEjemplo(
        usuario: Usuario(
          id: 1,
          nombre: 'Operador de prueba',
          correo: 'operador@waypoint.local',
          rol: 'operador',
          creacion: _haceDias(30),
        ),
        contrasena: 'Operador123!',
      ),
      CuentaEjemplo(
        usuario: Usuario(
          id: 2,
          nombre: 'Ana López',
          correo: 'ana@ejemplo.com',
          rol: 'usuario',
          creacion: _haceDias(20),
        ),
        contrasena: 'contrasena123',
      ),
      CuentaEjemplo(
        usuario: Usuario(
          id: 3,
          nombre: 'Luis Ramírez',
          correo: 'luis@ejemplo.com',
          rol: 'usuario',
          creacion: _haceDias(15),
        ),
        contrasena: 'contrasena123',
      ),
    ];
  }

  // Cinco reportes, uno por cada situación que la app tiene que mostrar.
  static List<Reporte> reportes() {
    final c = cuentas();
    final operador = c[0].usuario;
    final ana = c[1].usuario;
    final luis = c[2].usuario;

    return [
      Reporte(
        id: 1,
        titulo: 'Rampa rota en el edificio 1',
        descripcion:
            'La rampa de la entrada norte tiene una grieta y una parte hundida.',
        ubicacion: 'Edificio 1, entrada norte',
        latitud: 21.913560,
        longitud: -102.315020,
        cancelado: false,
        creacion: _haceDias(6),
        actualizacion: _haceDias(4),
        categoria: categorias[0],
        estado: estados[1],
        usuario: ana.resumen,
        operador: operador.resumen,
      ),
      Reporte(
        id: 2,
        titulo: 'Elevador del edificio 3 sin servicio',
        descripcion: 'El elevador no responde y no hay otra forma de subir.',
        ubicacion: 'Edificio 3, planta baja',
        cancelado: false,
        creacion: _haceDias(1),
        actualizacion: _haceDias(1),
        categoria: categorias[1],
        estado: estados[0],
        usuario: ana.resumen,
      ),
      Reporte(
        id: 3,
        titulo: 'Banqueta sin rampa frente a la biblioteca',
        descripcion: 'No hay rampa para bajar de la banqueta hacia el cruce.',
        ubicacion: 'Frente a la biblioteca',
        latitud: 21.913900,
        longitud: -102.314800,
        cancelado: false,
        creacion: _haceDias(12),
        actualizacion: _haceDias(2),
        categoria: categorias[2],
        estado: estados[3],
        usuario: ana.resumen,
        operador: operador.resumen,
      ),
      Reporte(
        id: 4,
        titulo: 'Falta guía podotáctil en el pasillo principal',
        descripcion: 'El pasillo del edificio 2 no tiene guía en el piso.',
        ubicacion: 'Edificio 2, pasillo principal',
        cancelado: false,
        creacion: _haceDias(9),
        actualizacion: _haceDias(3),
        categoria: categorias[3],
        estado: estados[2],
        usuario: luis.resumen,
        operador: operador.resumen,
      ),
      Reporte(
        id: 5,
        titulo: 'Baño sin barra de apoyo',
        descripcion: 'El baño de la planta baja no tiene barra de apoyo.',
        ubicacion: 'Edificio 4, planta baja',
        cancelado: true,
        razonCancelacion: 'Ya lo repararon antes de que lo revisaran',
        creacion: _haceDias(8),
        actualizacion: _haceDias(7),
        categoria: categorias[4],
        estado: estados[0],
        usuario: ana.resumen,
      ),
    ];
  }

  static Map<int, List<Evidencia>> evidencias() {
    final c = cuentas();
    return {
      1: [
        Evidencia(
          id: 1,
          tipo: 'reporte',
          ruta: '/uploads/ejemplo-1.jpg',
          creacion: _haceDias(6),
          usuario: c[1].usuario.resumen,
        ),
      ],
      3: [
        Evidencia(
          id: 2,
          tipo: 'reporte',
          ruta: '/uploads/ejemplo-2.jpg',
          creacion: _haceDias(12),
          usuario: c[1].usuario.resumen,
        ),
        Evidencia(
          id: 3,
          tipo: 'atencion',
          ruta: '/uploads/ejemplo-3.jpg',
          creacion: _haceDias(2),
          usuario: c[0].usuario.resumen,
        ),
      ],
    };
  }

  static Map<int, List<Movimiento>> historial() {
    final c = cuentas();
    final operador = c[0].usuario.resumen;
    final ana = c[1].usuario.resumen;
    final luis = c[2].usuario.resumen;

    return {
      1: [
        Movimiento(
          id: 1,
          tipo: 'creacion',
          estadoNuevo: estados[0],
          creacion: _haceDias(6),
          usuario: ana,
        ),
        Movimiento(
          id: 2,
          tipo: 'asignacion',
          creacion: _haceDias(5),
          usuario: operador,
        ),
        Movimiento(
          id: 3,
          tipo: 'cambio_estado',
          estadoAnterior: estados[0],
          estadoNuevo: estados[1],
          descripcion: 'Se revisó en sitio',
          creacion: _haceDias(4),
          usuario: operador,
        ),
      ],
      2: [
        Movimiento(
          id: 4,
          tipo: 'creacion',
          estadoNuevo: estados[0],
          creacion: _haceDias(1),
          usuario: ana,
        ),
      ],
      3: [
        Movimiento(
          id: 5,
          tipo: 'creacion',
          estadoNuevo: estados[0],
          creacion: _haceDias(12),
          usuario: ana,
        ),
        Movimiento(
          id: 6,
          tipo: 'asignacion',
          creacion: _haceDias(11),
          usuario: operador,
        ),
        Movimiento(
          id: 7,
          tipo: 'cambio_estado',
          estadoAnterior: estados[0],
          estadoNuevo: estados[1],
          creacion: _haceDias(10),
          usuario: operador,
        ),
        Movimiento(
          id: 8,
          tipo: 'cambio_estado',
          estadoAnterior: estados[1],
          estadoNuevo: estados[2],
          creacion: _haceDias(6),
          usuario: operador,
        ),
        Movimiento(
          id: 9,
          tipo: 'accion_correctiva',
          descripcion: 'Se construyó una rampa de concreto.',
          creacion: _haceDias(3),
          usuario: operador,
        ),
        Movimiento(
          id: 10,
          tipo: 'cambio_estado',
          estadoAnterior: estados[2],
          estadoNuevo: estados[3],
          creacion: _haceDias(2),
          usuario: operador,
        ),
      ],
      4: [
        Movimiento(
          id: 11,
          tipo: 'creacion',
          estadoNuevo: estados[0],
          creacion: _haceDias(9),
          usuario: luis,
        ),
        Movimiento(
          id: 12,
          tipo: 'asignacion',
          creacion: _haceDias(8),
          usuario: operador,
        ),
        Movimiento(
          id: 13,
          tipo: 'cambio_estado',
          estadoAnterior: estados[0],
          estadoNuevo: estados[1],
          creacion: _haceDias(6),
          usuario: operador,
        ),
        Movimiento(
          id: 14,
          tipo: 'cambio_estado',
          estadoAnterior: estados[1],
          estadoNuevo: estados[2],
          creacion: _haceDias(3),
          usuario: operador,
        ),
      ],
      5: [
        Movimiento(
          id: 15,
          tipo: 'creacion',
          estadoNuevo: estados[0],
          creacion: _haceDias(8),
          usuario: ana,
        ),
        Movimiento(
          id: 16,
          tipo: 'cancelacion',
          creacion: _haceDias(7),
          usuario: ana,
        ),
      ],
    };
  }
}
