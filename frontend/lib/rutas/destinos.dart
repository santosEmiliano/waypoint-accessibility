import 'package:flutter/material.dart';

enum Rol { usuario, operador }

enum Seccion { inicio, reportes, nuevo, bandeja, perfil }

/// Estructura de un botón del dock o del encabezado de la versión web.
class Destino {
  const Destino({
    required this.etiqueta,
    required this.icono,
    required this.seccion,
    this.etiquetaLarga,
  });

  final String etiqueta;
  final IconData icono;
  final Seccion seccion;

  /// Texto más largo para el encabezado web, si lo necesita.
  final String? etiquetaLarga;

  /// "Nuevo" no es una pestaña, abre el formulario aparte.
  bool get esAccion => seccion == Seccion.nuevo;
}

/// Los botones que ve cada rol, en el orden en que se muestran.
List<Destino> destinosPara(Rol rol) {
  const inicio = Destino(
    etiqueta: 'Inicio',
    icono: Icons.home_outlined,
    seccion: Seccion.inicio,
  );
  const reportes = Destino(
    etiqueta: 'Reportes',
    icono: Icons.format_list_bulleted,
    seccion: Seccion.reportes,
  );
  const nuevo = Destino(
    etiqueta: 'Nuevo',
    icono: Icons.add,
    seccion: Seccion.nuevo,
    etiquetaLarga: 'Reportar una barrera',
  );
  const bandeja = Destino(
    etiqueta: 'Bandeja',
    icono: Icons.inbox_outlined,
    seccion: Seccion.bandeja,
  );
  const perfil = Destino(
    etiqueta: 'Perfil',
    icono: Icons.person_outline,
    seccion: Seccion.perfil,
  );

  // El operator tiene la pestaña de bandeja para atender los
  // reportes, el usuario normal solo genera nuevos reportes
  if (rol == Rol.operador) return const [inicio, bandeja, reportes, perfil];
  return const [inicio, reportes, nuevo, perfil];
}
