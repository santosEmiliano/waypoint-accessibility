class Estado {
  final int id;
  final String nombre;
  // Según la convención de la bd, 1 = Reportado ... 4 = Resuelto.
  // Con esto se va llevando el avance del seguimiento de los reportes.

  final int orden;

  const Estado({required this.id, required this.nombre, required this.orden});

  factory Estado.desdeJson(Map<String, dynamic> m) {
    return Estado(
      id: m['id_estado'] as int,
      nombre: m['nombre_estado'] as String,
      orden: m['orden_estado'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id_estado': id, 'nombre_estado': nombre, 'orden_estado': orden};
  }
}
