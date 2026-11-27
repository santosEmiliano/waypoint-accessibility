import 'package:flutter/material.dart';

import '../componentes/mapa_paradas.dart';
import '../componentes/marca_waypoint.dart';
import '../componentes/nombre_waypoint.dart';
import '../componentes/ruta_paradas.dart';
import '../modelos/estado.dart';
import '../modelos/reporte.dart';
import '../servicios/error_api.dart';
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
    this.alVerReportes,
    this.alReportar,
  });

  final Sesion sesion;

  /// Lleva a la pestaña de Reportes.
  final VoidCallback? alVerReportes;

  /// Abre el formulario de un reporte nuevo.
  final VoidCallback? alReportar;

  @override
  State<PantallaPrincipal> createState() => _EstadoPantallaPrincipal();
}

// Lo que la pantalla necesita del servidor.
class _Resumen {
  _Resumen(List<Estado> estados, this.reportes)
    : estados = [...estados]..sort((a, b) => a.orden.compareTo(b.orden));

  final List<Estado> estados;
  final List<Reporte> reportes;

  int cuantosEn(Estado estado) =>
      reportes.where((r) => r.estado.id == estado.id).length;

  bool esFinal(Estado estado) => estado.id == estados.last.id;

  int get resueltos => cuantosEn(estados.last);

  int get enCamino => reportes.length - resueltos;

  /// Los tres que se movieron más recientemente.
  List<Reporte> get recientes {
    final ordenados = [...reportes]
      ..sort((a, b) => b.actualizacion.compareTo(a.actualizacion));
    return ordenados.take(3).toList();
  }
}

class _EstadoPantallaPrincipal extends State<PantallaPrincipal> {
  late Future<_Resumen> _carga = _cargar();

  Future<_Resumen> _cargar() async {
    final repositorio = widget.sesion.repositorio;
    // Las dos peticiones salen al mismo tiempo.
    final resultados = await Future.wait<Object>([
      repositorio.listarEstados(),
      repositorio.listarReportes(),
    ]);
    return _Resumen(
      resultados[0] as List<Estado>,
      resultados[1] as List<Reporte>,
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
              final error = estado.error;
              return _Error(
                mensaje: error is ErrorApi
                    ? error.mensaje
                    : 'No se pudieron cargar tus reportes.',
                alReintentar: _recargar,
              );
            }
            final resumen = estado.data;
            if (resumen == null) return const _Cargando();
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
    final sinReportes = resumen.reportes.isEmpty;

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
              // TODO(#26): abrir el listado filtrado por la parada tocada.
              alTocar: widget.alVerReportes == null
                  ? null
                  : (_) => widget.alVerReportes!(),
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

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MarcaWaypoint(tamano: 48, respira: true),
          const SizedBox(height: 16),
          Text(
            'Cargando tus reportes',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.alReintentar});

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: alReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
