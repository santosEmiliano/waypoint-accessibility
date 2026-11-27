import 'package:flutter/material.dart';

import '../componentes/estados_carga.dart';
import '../componentes/mapa_paradas.dart';
import '../componentes/marca_waypoint.dart';
import '../componentes/nombre_waypoint.dart';
import '../componentes/ruta_paradas.dart';
import '../modelos/estado.dart';
import '../modelos/reporte.dart';
import '../servicios/repositorio_waypoint.dart';
import '../servicios/sesion.dart';
import '../tema/colores_waypoint.dart';
import '../utilidades/fechas.dart';
import 'detalle.dart';

/// Inicio del usuario: cuántos reportes van en camino, el mapa de paradas,
/// el botón para reportar y los últimos reportes que se movieron.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({
    super.key,
    required this.sesion,
    this.alVerParada,
    this.alReportar,
  });

  final Sesion sesion;

  /// Lleva al listado filtrado por la parada tocada (recibe el id del estado).
  final ValueChanged<int>? alVerParada;

  /// Abre el formulario de un reporte nuevo.
  final VoidCallback? alReportar;

  @override
  State<PantallaPrincipal> createState() => _EstadoPantallaPrincipal();
}

// Lo que la pantalla necesita del servidor.
class _Resumen {
  _Resumen(List<Estado> estados, this.conteos, this.recientes)
    : estados = [...estados]..sort((a, b) => a.orden.compareTo(b.orden));

  final List<Estado> estados;

  /// Cuántos reportes hay en cada estado (por id).
  final Map<int, int> conteos;

  /// Los que se movieron más recientemente.
  final List<Reporte> recientes;

  int cuantosEn(Estado estado) => conteos[estado.id] ?? 0;

  bool esFinal(Estado estado) => estado.id == estados.last.id;

  int get total => conteos.values.fold(0, (suma, n) => suma + n);

  int get resueltos => cuantosEn(estados.last);

  int get enCamino => total - resueltos;
}

class _EstadoPantallaPrincipal extends State<PantallaPrincipal> {
  late Future<_Resumen> _carga = _cargar();

  Future<_Resumen> _cargar() async {
    final repositorio = widget.sesion.repositorio;
    // Las tres peticiones salen al mismo tiempo. No se traen todos los
    // reportes: los conteos vienen del resumen y de la lista solo los 3 últimos.
    final resultados = await Future.wait<Object>([
      repositorio.listarEstados(),
      repositorio.resumenReportes(),
      repositorio.listarReportes(limite: 3, orden: OrdenReportes.actualizacion),
    ]);
    return _Resumen(
      resultados[0] as List<Estado>,
      resultados[1] as Map<int, int>,
      resultados[2] as List<Reporte>,
    );
  }

  Future<void> _recargar() async {
    final carga = _cargar();
    setState(() {
      _carga = carga;
    });
    try {
      await carga;
    } catch (_) {
      // El error ya lo muestra el FutureBuilder.
    }
  }

  void _abrirReporte(Reporte reporte) {
    // TODO(#32): pasarle el reporte cuando el detalle exista.
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PantallaDetalle()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_Resumen>(
          future: _carga,
          builder: (context, estado) {
            if (estado.hasError) {
              return ErrorWaypoint(
                mensaje: ErrorWaypoint.mensajeDe(estado.error),
                alReintentar: _recargar,
              );
            }
            final resumen = estado.data;
            if (resumen == null) return const CargandoWaypoint();
            return RefreshIndicator(
              onRefresh: _recargar,
              child: _contenido(context, resumen),
            );
          },
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, _Resumen resumen) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;
    final nombre = widget.sesion.usuario?.nombre.split(' ').first ?? '';

    final enCamino = resumen.enCamino;
    final resueltos = resumen.resueltos;
    final sinReportes = resumen.total == 0;

    final titulo = switch (enCamino) {
      _ when sinReportes => 'Aún no tienes reportes',
      0 => 'Todos tus reportes se resolvieron',
      1 => '1 reporte sigue en camino',
      _ => '$enCamino reportes siguen en camino',
    };
    final yaResueltos = switch (resueltos) {
      _ when enCamino == 0 => '',
      0 => '',
      1 => '1 ya se resolvió. ',
      _ => '$resueltos ya se resolvieron. ',
    };
    final bajada = sinReportes
        ? 'Cuando reportes una barrera, aquí verás por dónde va.'
        : '${yaResueltos}Toca una parada para ver sus reportes.';

    return LayoutBuilder(
      builder: (context, medidas) {
        // En pantallas anchas el contenido no pasa de 560 y queda centrado.
        final lado = ((medidas.maxWidth - 560) / 2).clamp(
          20.0,
          double.infinity,
        );
        return ListView(
          // Para que se pueda jalar y recargar aunque quepa todo en pantalla.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(lado, 16, lado, 24),
          children: [
            // El nombre ya se anuncia en el título de la app; aquí es decorado.
            ExcludeSemantics(
              child: Row(
                children: [
                  const MarcaWaypoint(tamano: 32),
                  const SizedBox(width: 10),
                  NombreWaypoint(
                    estilo: texto.titleLarge!.copyWith(letterSpacing: -0.3),
                    colorPunto: c.guia,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hola, $nombre',
              style: texto.bodyLarge!.copyWith(
                color: c.tinta2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Semantics(
              header: true,
              child: Text(titulo, style: texto.headlineLarge),
            ),
            const SizedBox(height: 6),
            Text(bajada, style: texto.bodyMedium!.copyWith(color: c.tinta2)),
            const SizedBox(height: 16),
            MapaParadas(
              paradas: [
                for (final e in resumen.estados)
                  (nombre: e.nombre, cantidad: resumen.cuantosEn(e)),
              ],
              alTocar: widget.alVerParada == null
                  ? null
                  : (i) => widget.alVerParada!(resumen.estados[i].id),
            ),
            const SizedBox(height: 16),
            _BotonReportar(alTocar: widget.alReportar),
            if (!sinReportes) ...[
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Lo último', style: texto.titleMedium),
                ),
              ),
              for (final r in resumen.recientes)
                _FilaReporte(
                  reporte: r,
                  total: resumen.estados.length,
                  esFinal: resumen.esFinal(r.estado),
                  alTocar: () => _abrirReporte(r),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _BotonReportar extends StatelessWidget {
  const _BotonReportar({this.alTocar});

  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      child: Material(
        color: c.tinta,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: alTocar,
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.guia,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: c.sobreGuia, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reportar una barrera',
                          style: texto.titleLarge!.copyWith(
                            fontSize: 19,
                            height: 24 / 19,
                            color: c.suelo,
                          ),
                        ),
                        Text(
                          'Toma una foto y marca dónde está',
                          style: texto.bodySmall!.copyWith(
                            color: c.suelo,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaReporte extends StatelessWidget {
  const _FilaReporte({
    required this.reporte,
    required this.total,
    required this.esFinal,
    required this.alTocar,
  });

  final Reporte reporte;
  final int total;
  final bool esFinal;
  final VoidCallback alTocar;

  // "Reportado el 18 nov", "En análisis desde el 17 nov" o "Resuelto el 20 nov".
  String get _cuando {
    final estado = reporte.estado;
    if (estado.orden == 1) {
      return '${estado.nombre} el ${fechaCorta(reporte.creacion)}';
    }
    final fecha = fechaCorta(reporte.actualizacion);
    return esFinal
        ? '${estado.nombre} el $fecha'
        : '${estado.nombre} desde el $fecha';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: alTocar,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.linea)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reporte.titulo, style: texto.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          RutaParadas(
                            parada: reporte.estado.orden,
                            total: total,
                          ),
                          Text(_cuando, style: texto.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.chevron_right, color: c.tinta2, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
