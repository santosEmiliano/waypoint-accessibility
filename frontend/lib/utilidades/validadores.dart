// Validaciones de los formularios. Siguen las reglas del contrato de la API.
// Cada una devuelve el mensaje de error, o null si el texto está bien.

String? validarCorreo(String? texto) {
  final correo = texto?.trim() ?? '';
  if (correo.isEmpty) return 'Escribe tu correo';
  if (correo.length > 200) return 'El correo es demasiado largo';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) {
    return 'Escribe un correo válido';
  }
  return null;
}

/// Para iniciar sesión, por el momento solo se pide que no esté vacía.
String? validarContrasenaEscrita(String? texto) {
  if (texto == null || texto.isEmpty) return 'Escribe tu contraseña';
  return null;
}

/// Para crear una cuenta se piden al menos 8 caracteres.
String? validarContrasenaNueva(String? texto) {
  if (texto == null || texto.isEmpty) return 'Escribe una contraseña';
  if (texto.length < 8) return 'Usa al menos 8 caracteres';
  return null;
}

String? validarNombre(String? texto) {
  final nombre = texto?.trim() ?? '';
  if (nombre.isEmpty) return 'Escribe tu nombre';
  if (nombre.length > 100) return 'El nombre es demasiado largo';
  return null;
}
