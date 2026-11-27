class UsuarioResumen {
  final int id;
  final String nombre;

  const UsuarioResumen({required this.id, required this.nombre});

  factory UsuarioResumen.desdeJson(Map<String, dynamic> m) {
    return UsuarioResumen(
      id: m['id_usuario'] as int,
      nombre: m['nombre_usuario'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id_usuario': id, 'nombre_usuario': nombre};
  }
}
