import 'package:flutter/material.dart';

import '../rutas/destinos.dart';
import '../tema/colores_waypoint.dart';

/// Barra de navegación flotante para celular.
class DockFlotante extends StatelessWidget {
  const DockFlotante({
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
    final c = context.colores; // Colores de la paleta de Waypoint importados desde el contexto de la app

    return Container(
      height: 70,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: c.dock, // Color del dock establecido en la paleta
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: c.dockBorde),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          for (
            var i = 0;
            i < destinos.length;
            i++
          ) // Destinos establecidos en destinos.dart
            Expanded(
              child: _BotonDock(
                destino: destinos[i],
                activo: i == indice,
                alTocar: () => alElegir(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _BotonDock extends StatelessWidget {
  // Botones individuales del dock (Destinos de los usuarios)
  const _BotonDock({
    required this.destino,
    required this.activo,
    required this.alTocar,
  });

  final Destino destino;
  final bool activo; // Si esta activo o no
  final VoidCallback alTocar; // Callback que se ejecuta al tocar el botón

  @override
  Widget build(BuildContext context) {
    final c = context.colores; // Colores de la paleta de Waypoint importados desde el contexto de la app
    final estiloEtiqueta = Theme.of(context)
        .textTheme
        .labelSmall!; // Estilo de la etiqueta establecido en la paleta

    return Semantics(
      button: true,
      selected: activo,
      label: destino.etiqueta,
      excludeSemantics: true,
      child: Material(
        color: activo ? c.dockPastilla : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: alTocar,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                destino.icono,
                size: 24,
                // Solo el ícono activo lleva el amarillo.
                color: activo ? c.guia : c.dockTexto,
              ),
              const SizedBox(height: 3),
              Text(
                destino.etiqueta,
                // Una sola línea: si no cabe, se corta con puntos suspensivos.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: estiloEtiqueta.copyWith(
                  color: activo ? c.dockActivo : c.dockTexto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
