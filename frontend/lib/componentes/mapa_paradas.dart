import 'package:flutter/material.dart';

import '../tema/colores_waypoint.dart';

/// Una parada del mapa, el nombre del estado y cuántos reportes hay en él.
typedef Parada = ({String nombre, int cantidad});

/// Las paradas del recorrido estan en una línea, con el número de reportes arriba
/// de cada una. La última (estado "Resuelto") va rellena porque es el destino.
class MapaParadas extends StatelessWidget {
  const MapaParadas({super.key, required this.paradas, this.alTocar});

  final List<Parada> paradas;

  /// Recibe la posición de la parada tocada.
  final ValueChanged<int>? alTocar;

  static const _diametro = 24.0;
  static const _separacion = 8.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;
    final escala = MediaQuery.textScalerOf(context);

    final estiloNumero = texto.headlineLarge!.copyWith(
      fontSize: 34,
      height: 36 / 34,
      letterSpacing: -0.5,
    );
    final estiloNombre = texto.labelSmall!.copyWith(fontSize: 13);

    // La línea pasa por el centro de los círculos, que quedan debajo del número.
    final centroCirculo = escala.scale(36) + _separacion + _diametro / 2;

    return Semantics(
      container: true,
      label: 'Tus reportes por parada',
      child: Stack(
        children: [
          Positioned.fill(
            child: FractionallySizedBox(
              // De la mitad de la primera columna a la mitad de la última.
              widthFactor: 1 - 1 / paradas.length,
              alignment: Alignment.topCenter,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: EdgeInsets.only(top: centroCirculo - 2),
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.tinta,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < paradas.length; i++)
                Expanded(
                  child: _Estacion(
                    parada: paradas[i],
                    destino: i == paradas.length - 1,
                    estiloNumero: estiloNumero,
                    estiloNombre: estiloNombre,
                    alTocar: alTocar == null ? null : () => alTocar!(i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Estacion extends StatelessWidget {
  const _Estacion({
    required this.parada,
    required this.destino,
    required this.estiloNumero,
    required this.estiloNombre,
    this.alTocar,
  });

  final Parada parada;
  final bool destino;
  final TextStyle estiloNumero;
  final TextStyle estiloNombre;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final cantidad = parada.cantidad;
    final reportes = cantidad == 1 ? 'reporte' : 'reportes';

    return Semantics(
      button: alTocar != null,
      label: '${parada.nombre}: $cantidad $reportes',
      excludeSemantics: true,
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            children: [
              Text('$cantidad', style: estiloNumero),
              const SizedBox(height: MapaParadas._separacion),
              Container(
                width: MapaParadas._diametro,
                height: MapaParadas._diametro,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: destino ? c.tinta : c.suelo,
                  border: Border.all(color: c.tinta, width: 4),
                ),
              ),
              const SizedBox(height: MapaParadas._separacion),
              Text(
                parada.nombre,
                textAlign: TextAlign.center,
                style: estiloNombre,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
