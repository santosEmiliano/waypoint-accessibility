class Categoria {
  final int id;
  final String nombre;

  const Categoria({required this.id, required this.nombre});

  factory Categoria.desdeJson(Map<String, dynamic> m) {
    return Categoria(
      id: m['id_categoria'] as int,
      nombre: m['nombre_categoria'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id_categoria': id, 'nombre_categoria': nombre};
  }
}
