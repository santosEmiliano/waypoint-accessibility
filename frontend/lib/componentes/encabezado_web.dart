import 'package:flutter/material.dart';

import '../rutas/destinos.dart';
import '../tema/colores_waypoint.dart';
import 'marca_waypoint.dart';

/// Barra superior para web y escritorio.
class EncabezadoWeb extends StatelessWidget {
  const EncabezadoWeb({
    super.key,
    required this.destinos,
    required this.indice,
    required this.alElegir,
  });

  final List<Destino> destinos;
  final int indice;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;

    // Las secciones van al centro e izquierda, las acciónes y el perfil, a la derecha.
    final secciones = [
      for (var i = 0; i < destinos.length; i++)
        if (!destinos[i].esAccion && destinos[i].seccion != Seccion.perfil) i,
    ];
    final acciones = [
      for (var i = 0; i < destinos.length; i++)
        if (destinos[i].esAccion) i,
    ];
    final perfil = destinos.indexWhere((d) => d.seccion == Seccion.perfil);

    return Container(
      height: 72,
      color: c.dock,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          MarcaWaypoint(tamano: 34, colorPuntos: c.linea2, colorBorde: c.dock),
          const SizedBox(width: 10),
          Text(
            'Waypoint',
            style: texto.titleLarge!.copyWith(
              fontSize: 21,
              color: c.dockActivo,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 32),
          for (final i in secciones)
            _EnlaceSeccion(
              destino: destinos[i],
              activo: i == indice,
              alTocar: () => alElegir(i),
            ),
          const Spacer(),
          for (final i in acciones)
            FilledButton.icon(
              onPressed: () => alElegir(i),
              style: FilledButton.styleFrom(
                backgroundColor: c.dockActivo,
                foregroundColor: c.sobreGuia,
                minimumSize: const Size(64, 44),
              ),
              icon: Icon(destinos[i].icono),
              label: Text(destinos[i].etiquetaLarga ?? destinos[i].etiqueta),
            ),
          if (perfil != -1)
            TextButton.icon(
              onPressed: () => alElegir(perfil),
              style: TextButton.styleFrom(foregroundColor: c.dockActivo),
              icon: Icon(destinos[perfil].icono),
              label: Text(destinos[perfil].etiqueta),
            ),
        ],
      ),
    );
  }
}

class _EnlaceSeccion extends StatelessWidget {
  const _EnlaceSeccion({
    required this.destino,
    required this.activo,
    required this.alTocar,
  });

  final Destino destino;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final estilo = Theme.of(context).textTheme.labelMedium!;

    return Semantics(
      button: true,
      selected: activo,
      child: InkWell(
        onTap: alTocar,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // La sección activa lleva una línea amarilla debajo.
            border: activo
                ? Border(bottom: BorderSide(color: c.guia, width: 5))
                : null,
          ),
          child: Text(
            destino.etiqueta,
            style: estilo.copyWith(
              fontSize: 16,
              color: activo ? c.dockActivo : c.dockTexto,
            ),
          ),
        ),
      ),
    );
  }
}
