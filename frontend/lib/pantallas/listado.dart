import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../componentes/estados_carga.dart';
import '../componentes/tramo_rio.dart';
import '../modelos/categoria.dart';
import '../modelos/estado.dart';
import '../modelos/reporte.dart';
import '../servicios/sesion.dart';
import '../tema/colores_waypoint.dart';
import '../utilidades/fechas.dart';
import 'detalle.dart';

/// Los reportes agrupados por parada sobre una línea vertical.
///
/// No trae todo de una vez, los conteos vienen del resumen, y cada parada pide
/// sus reportes de 10 en 10 y Resuelto no pide nada hasta que se despliega.
/// La lista se construye conforme se ve, así que solo existen en memoria los
/// renglones que están en pantalla.
class PantallaListado extends StatefulWidget {
  const PantallaListado({super.key, required this.sesion, this.paradaPedida});

  final Sesion sesion;

  final ValueNotifier<int?>? paradaPedida;

  @override
  State<PantallaListado> createState() => _EstadoPantallaListado();
}

// Una parada del río con los reportes que ya llegaron.
class _Seccion {
  _Seccion(this.estado, this.total);

  final Estado estado;
  final int total;
  final reportes = <Reporte>[];
  bool cargando = false;
  bool desplegada = true;

  bool get hayMas => reportes.length < total;
  int get faltan => total - reportes.length;
}

// Un renglón del río. La clave sirve para no repetir la animación.
sealed class _Fila {
  const _Fila(this.clave, this.linea);
  final String clave;
  final LineaRio linea;
}

class _FilaParada extends _Fila {
  const _FilaParada(super.clave, super.linea, this.seccion, this.esFinal);
  final _Seccion seccion;
  final bool esFinal;
}

class _FilaReporte extends _Fila {
  const _FilaReporte(super.clave, super.linea, this.reporte, this.primero);
  final Reporte reporte;
  final bool primero;
}

class _FilaMas extends _Fila {
  const _FilaMas(super.clave, super.linea, this.seccion);
  final _Seccion seccion;
}

class _EstadoPantallaListado extends State<PantallaListado> {
  static const _porPagina = 10;
  static const _pausaEntreRenglones = Duration(milliseconds: 45);

  final _buscador = TextEditingController();
  Timer? _esperaBusqueda;

  List<Estado>? _estados;
  List<Categoria>? _categorias;
  List<_Seccion> _secciones = [];
  bool _cargando = true;
  Object? _error;

  // Filtros activos.
  String _texto = '';
  Categoria? _categoria;
  int? _idEstado;

  int _version = 0;

  // Renglones que ya aparecieron no se vuelven a animar y, para los que
  // van a aparecer, su turno y cuándo llegó su lote.
  final _vistos = <String>{};
  final _turnos = <String, (int, DateTime)>{};

  // Cambia cuando se vuelve a animar todo, para que los renglones se creen de nuevo.
  int _generacion = 0;

  bool get _hayFiltros =>
      _texto.isNotEmpty || _categoria != null || _idEstado != null;

  @override
  void initState() {
    super.initState();
    widget.paradaPedida?.addListener(_atenderParadaPedida);
    if (widget.paradaPedida?.value != null) {
      _atenderParadaPedida();
    } else {
      _cargar();
    }
  }

  @override
  void dispose() {
    widget.paradaPedida?.removeListener(_atenderParadaPedida);
    _esperaBusqueda?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  void _atenderParadaPedida() {
    final id = widget.paradaPedida?.value;
    if (id == null) return;
    // Se vacía para que tocar la misma parada otra vez también funcione.
    widget.paradaPedida!.value = null;
    _idEstado = id;
    _cargar(desdeCero: true);
  }

  // Ordena las categorías por nombre y deja "Otro" al final.
  static int _compararCategorias(Categoria a, Categoria b) {
    if (a.nombre == 'Otro') return 1;
    if (b.nombre == 'Otro') return -1;
    return a.nombre.compareTo(b.nombre);
  }

  Future<List<Reporte>> _pedir(_Seccion seccion, {int desde = 0}) {
    return widget.sesion.repositorio.listarReportes(
      idEstado: seccion.estado.id,
      idCategoria: _categoria?.id,
      texto: _texto.isEmpty ? null : _texto,
      limite: _porPagina,
      desde: desde,
    );
  }

  /// Carga los conteos y la primera página de cada parada desplegada.
  /// Con [desdeCero] los renglones se vuelven a animar (cambió un filtro).
  Future<void> _cargar({bool desdeCero = false}) async {
    final version = ++_version;
    if (_secciones.isEmpty || desdeCero) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final repositorio = widget.sesion.repositorio;
      final estados = _estados ??= [...await repositorio.listarEstados()]
        ..sort((a, b) => a.orden.compareTo(b.orden));
      final conteos = await repositorio.resumenReportes(
        idCategoria: _categoria?.id,
        texto: _texto.isEmpty ? null : _texto,
      );

      final anteriores = {for (final s in _secciones) s.estado.id: s};
      final idFinal = estados.last.id;
      final secciones = [
        for (final e in estados)
          if (_idEstado == null || e.id == _idEstado)
            _Seccion(e, conteos[e.id] ?? 0)
              // Resuelto empieza plegado, salvo que se pidió esa parada o ya
              // estaba abierto.
              ..desplegada =
                  e.id != idFinal ||
                  _idEstado == idFinal ||
                  (anteriores[e.id]?.desplegada ?? false),
      ];

      final paginas = await Future.wait([
        for (final s in secciones)
          s.desplegada && s.total > 0 ? _pedir(s) : Future.value(<Reporte>[]),
      ]);
      if (!mounted || version != _version) return;

      for (var i = 0; i < secciones.length; i++) {
        secciones[i].reportes.addAll(paginas[i]);
      }
      setState(() {
        if (desdeCero) {
          _vistos.clear();
          _turnos.clear();
          _generacion++;
        }
        _secciones = secciones;
        _cargando = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(() {
        _cargando = false;
        // Si ya había algo en pantalla se deja y solo se avisa.
        if (_secciones.isEmpty || desdeCero) {
          _secciones = [];
          _error = error;
        }
      });
      if (_error == null) _avisar(ErrorWaypoint.mensajeDe(error));
    }
  }

  Future<void> _cargarMas(_Seccion seccion) async {
    if (seccion.cargando || !seccion.hayMas) return;
    final version = _version;
    setState(() => seccion.cargando = true);
    try {
      final pagina = await _pedir(seccion, desde: seccion.reportes.length);
      if (!mounted || version != _version) return;
      setState(() {
        seccion.reportes.addAll(pagina);
        seccion.cargando = false;
      });
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(() => seccion.cargando = false);
      _avisar(ErrorWaypoint.mensajeDe(error));
    }
  }

  void _desplegar(_Seccion seccion) {
    setState(() => seccion.desplegada = !seccion.desplegada);
    if (seccion.desplegada && seccion.reportes.isEmpty) _cargarMas(seccion);
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _alEscribir(String texto) {
    // Se espera a que deje de escribir para no pedir una vez por letra.
    _esperaBusqueda?.cancel();
    _esperaBusqueda = Timer(const Duration(milliseconds: 350), () {
      final limpio = texto.trim();
      if (limpio == _texto) return;
      _texto = limpio;
      _cargar(desdeCero: true);
    });
  }

  void _quitarFiltros() {
    _esperaBusqueda?.cancel();
    _buscador.clear();
    _texto = '';
    _categoria = null;
    _idEstado = null;
    _cargar(desdeCero: true);
  }

  Future<void> _elegirCategoria() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      _categorias ??= [...await widget.sesion.repositorio.listarCategorias()]
        ..sort(_compararCategorias);
    } catch (error) {
      _avisar(ErrorWaypoint.mensajeDe(error));
      return;
    }
    if (!mounted) return;

    // Se devuelve una lista para distinguir "Todas" (lista vacía) de cerrar
    // la hoja sin elegir (null).
    final eleccion = await showModalBottomSheet<List<Categoria>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _HojaCategorias(categorias: _categorias!, actual: _categoria),
    );
    if (eleccion == null) return;
    final nueva = eleccion.isEmpty ? null : eleccion.first;
    if (nueva?.id == _categoria?.id) return;
    _categoria = nueva;
    _cargar(desdeCero: true);
  }

  void _abrirReporte(Reporte reporte) {
    // TODO(#32): pasarle el reporte cuando el detalle exista.
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PantallaDetalle()));
  }

  // Arma los renglones del río en el orden en que se ven.
  List<_Fila> _filas() {
    final filas = <_Fila>[];
    final varias = _secciones.length > 1;
    for (var i = 0; i < _secciones.length; i++) {
      final s = _secciones[i];
      final esUltima = i == _secciones.length - 1;
      final esFinal = s.estado.id == _estados!.last.id;

      final lineaParada = !varias
          ? LineaRio.ninguna
          : i == 0
          ? LineaRio.desdeElCentro
          : esUltima
          ? LineaRio.hastaElCentro
          : LineaRio.completa;
      // Lo que va debajo de la última parada ya no lleva línea.
      final lineaResto = varias && !esUltima
          ? LineaRio.completa
          : LineaRio.ninguna;

      filas.add(_FilaParada('p${s.estado.id}', lineaParada, s, esFinal));
      if (!s.desplegada) continue;
      for (var j = 0; j < s.reportes.length; j++) {
        final r = s.reportes[j];
        filas.add(_FilaReporte('r${r.id}', lineaResto, r, j == 0));
      }
      if (s.hayMas) filas.add(_FilaMas('m${s.estado.id}', lineaResto, s));
    }
    return filas;
  }

  // Les da turno a los renglones nuevos, en orden, para la cascada.
  void _darTurnos(List<_Fila> filas) {
    final ahora = DateTime.now();
    var turno = 0;
    for (final f in filas) {
      if (_vistos.contains(f.clave) || _turnos.containsKey(f.clave)) continue;
      _turnos[f.clave] = (turno++, ahora);
    }
  }

  // Cuánto espera un renglón antes de aparecer. Si se construye tarde (porque
  // se bajó hasta él), ya no espera.
  Duration _retraso(String clave) {
    final (turno, llegada) = _turnos[clave] ?? (0, DateTime.now());
    final previsto = _pausaEntreRenglones * math.min(turno, 12);
    final pasado = DateTime.now().difference(llegada);
    return previsto > pasado ? previsto - pasado : Duration.zero;
  }

  bool _alDesplazar(ScrollNotification aviso) {
    // Resuelto es lo último del río: al acercarse al final se pide más.
    if (aviso.metrics.extentAfter > 400 || _secciones.isEmpty) return false;
    final ultima = _secciones.last;
    if (ultima.desplegada && ultima.hayMas) _cargarMas(ultima);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final esOperador = widget.sesion.usuario?.esOperador ?? false;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, medidas) {
            final lado = ((medidas.maxWidth - 560) / 2).clamp(
              20.0,
              double.infinity,
            );
            return RefreshIndicator(
              onRefresh: _cargar,
              child: NotificationListener<ScrollNotification>(
                onNotification: _alDesplazar,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(lado, 16, lado, 0),
                      sliver: SliverToBoxAdapter(
                        child: _encabezado(context, esOperador),
                      ),
                    ),
                    ..._cuerpo(context, lado, esOperador),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _encabezado(BuildContext context, bool esOperador) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;
    final conCategoria = _categoria != null;
    final estadoFiltrado = _idEstado == null
        ? null
        : _estados?.where((e) => e.id == _idEstado).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            esOperador ? 'Reportes' : 'Mis reportes',
            style: texto.headlineLarge,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _buscador,
                onChanged: _alEscribir,
                textInputAction: TextInputAction.search,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: InputDecoration(
                  hintText: 'Buscar por lugar o problema',
                  prefixIcon: Icon(Icons.search, color: c.tinta2),
                  // El lector de pantalla anuncia esto en lugar de la pista.
                  labelText: esOperador
                      ? 'Buscar en los reportes'
                      : 'Buscar en mis reportes',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              selected: conCategoria,
              label: 'Filtrar por categoría',
              excludeSemantics: true,
              child: Material(
                color: conCategoria ? c.tinta : c.placa,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: conCategoria ? c.tinta : c.linea,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: _elegirCategoria,
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.square(
                    dimension: 56,
                    child: Icon(
                      Icons.filter_list,
                      color: conCategoria ? c.suelo : c.tinta,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (estadoFiltrado != null || _categoria != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (estadoFiltrado != null)
                InputChip(
                  label: Text('Parada: ${estadoFiltrado.nombre}'),
                  deleteButtonTooltipMessage: 'Quitar el filtro de parada',
                  onDeleted: () {
                    _idEstado = null;
                    _cargar(desdeCero: true);
                  },
                ),
              if (_categoria != null)
                InputChip(
                  label: Text('Categoría: ${_categoria!.nombre}'),
                  deleteButtonTooltipMessage: 'Quitar el filtro de categoría',
                  onDeleted: () {
                    _categoria = null;
                    _cargar(desdeCero: true);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }

  List<Widget> _cuerpo(BuildContext context, double lado, bool esOperador) {
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorWaypoint(
            mensaje: ErrorWaypoint.mensajeDe(_error),
            alReintentar: () => _cargar(desdeCero: true),
          ),
        ),
      ];
    }
    if (_cargando) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: CargandoWaypoint()),
      ];
    }
    if (_secciones.every((s) => s.total == 0)) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _SinReportes(
            conFiltros: _hayFiltros,
            esOperador: esOperador,
            alQuitarFiltros: _quitarFiltros,
          ),
        ),
      ];
    }

    final filas = _filas();
    _darTurnos(filas);
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(lado, 0, lado, 24),
        sliver: SliverList.builder(
          itemCount: filas.length,
          // Solo se construyen los renglones que se ven (y unos cuantos más).
          itemBuilder: (context, i) {
            final fila = filas[i];
            final animar = _vistos.add(fila.clave);
            final retraso = animar ? _retraso(fila.clave) : Duration.zero;
            _turnos.remove(fila.clave);
            return TramoRio(
              key: ValueKey('$_generacion/${fila.clave}'),
              linea: fila.linea,
              parada: fila is _FilaParada,
              destino: fila is _FilaParada && fila.esFinal,
              animar: animar,
              retraso: retraso,
              child: switch (fila) {
                _FilaParada(:final seccion, :final esFinal) => _Parada(
                  seccion: seccion,
                  esFinal: esFinal,
                  alDesplegar: () => _desplegar(seccion),
                ),
                _FilaReporte(:final reporte, :final primero) => _Renglon(
                  reporte: reporte,
                  primero: primero,
                  alTocar: () => _abrirReporte(reporte),
                ),
                _FilaMas(:final seccion) => _BotonMas(
                  seccion: seccion,
                  porPagina: _porPagina,
                  alTocar: () => _cargarMas(seccion),
                ),
              },
            );
          },
        ),
      ),
    ];
  }
}

class _Parada extends StatelessWidget {
  const _Parada({
    required this.seccion,
    required this.esFinal,
    required this.alDesplegar,
  });

  final _Seccion seccion;
  final bool esFinal;
  final VoidCallback alDesplegar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;
    final total = seccion.total;
    final nombre = seccion.estado.nombre;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              label: '$nombre: $total ${total == 1 ? 'reporte' : 'reportes'}',
              excludeSemantics: true,
              child: Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    nombre,
                    style: texto.titleMedium!.copyWith(fontSize: 18),
                  ),
                  Text(
                    '$total',
                    style: texto.titleMedium!.copyWith(
                      fontSize: 16,
                      color: c.tinta2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Solo la última parada se pliega, y solo si tiene algo que mostrar.
          if (esFinal && total > 0)
            Semantics(
              expanded: seccion.desplegada,
              child: OutlinedButton(
                onPressed: alDesplegar,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(seccion.desplegada ? 'Ocultar' : 'Mostrar'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.reporte,
    required this.primero,
    required this.alTocar,
  });

  final Reporte reporte;
  final bool primero;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final texto = Theme.of(context).textTheme;
    final fecha = fechaCorta(reporte.creacion);

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: alTocar,
          child: Container(
            padding: EdgeInsets.only(top: primero ? 4 : 12, bottom: 12),
            decoration: BoxDecoration(
              border: primero ? null : Border(top: BorderSide(color: c.linea)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(reporte.titulo, style: texto.titleMedium),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      fecha,
                      style: texto.bodySmall!.copyWith(height: 22 / 14),
                      semanticsLabel: 'reportado el $fecha',
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  reporte.ubicacion,
                  style: texto.bodyMedium!.copyWith(color: c.tinta2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonMas extends StatelessWidget {
  const _BotonMas({
    required this.seccion,
    required this.porPagina,
    required this.alTocar,
  });

  final _Seccion seccion;
  final int porPagina;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final siguientes = math.min(seccion.faltan, porPagina);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextButton(
          onPressed: seccion.cargando ? null : alTocar,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            seccion.cargando
                ? 'Cargando más reportes…'
                : 'Mostrar $siguientes más de ${seccion.estado.nombre}',
          ),
        ),
      ),
    );
  }
}

class _SinReportes extends StatelessWidget {
  const _SinReportes({
    required this.conFiltros,
    required this.esOperador,
    required this.alQuitarFiltros,
  });

  final bool conFiltros;
  final bool esOperador;
  final VoidCallback alQuitarFiltros;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final c = context.colores;

    final titulo = conFiltros
        ? 'No hay reportes con esa búsqueda'
        : esOperador
        ? 'Todavía no hay reportes'
        : 'Aún no tienes reportes';
    final bajada = conFiltros
        ? 'Prueba con otras palabras o quita los filtros.'
        : 'Cuando se reporte una barrera, aparecerá aquí.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(titulo, textAlign: TextAlign.center, style: texto.titleLarge),
          const SizedBox(height: 8),
          Text(
            bajada,
            textAlign: TextAlign.center,
            style: texto.bodyMedium!.copyWith(color: c.tinta2),
          ),
          if (conFiltros) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: alQuitarFiltros,
              child: const Text('Quitar filtros'),
            ),
          ],
        ],
      ),
    );
  }
}

// Hoja de abajo para elegir una categoría. Devuelve [] para "Todas".
class _HojaCategorias extends StatelessWidget {
  const _HojaCategorias({required this.categorias, required this.actual});

  final List<Categoria> categorias;
  final Categoria? actual;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    Widget opcion(String nombre, bool elegida, List<Categoria> resultado) {
      return Semantics(
        selected: elegida,
        child: ListTile(
          title: Text(nombre, style: texto.titleMedium),
          trailing: elegida ? const Icon(Icons.check) : null,
          minTileHeight: 52,
          onTap: () => Navigator.of(context).pop(resultado),
        ),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                header: true,
                child: Text('Filtrar por categoría', style: texto.titleLarge),
              ),
            ),
            opcion('Todas', actual == null, const []),
            for (final c in categorias)
              opcion(c.nombre, actual?.id == c.id, [c]),
          ],
        ),
      ),
    );
  }
}
