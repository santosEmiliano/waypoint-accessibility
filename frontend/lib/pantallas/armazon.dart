import 'package:flutter/material.dart';

import '../componentes/dock_flotante.dart';
import '../componentes/encabezado_web.dart';
import '../rutas/destinos.dart';
import '../servicios/sesion.dart';
import 'administracion.dart';
import 'formulario.dart';
import 'listado.dart';
import 'perfil.dart';
import 'principal.dart';

/// Desde este ancho se usa el encabezado en lugar del dock.
const double anchoEscritorio = 840;

/// Marco con la navegación de la app, el dock en el celular, encabezado en web y escritorio.
class Armazon extends StatefulWidget {
  const Armazon({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<Armazon> createState() => _EstadoArmazon();
}

class _EstadoArmazon extends State<Armazon> {
  // Posición de la sección que se está viendo.
  int _indice = 0;

  Widget _pagina(Seccion seccion, List<Destino> destinos) {
    return switch (seccion) {
      Seccion.inicio => PantallaPrincipal(
        sesion: widget.sesion,
        alVerReportes: () => setState(() {
          _indice = destinos.indexWhere((d) => d.seccion == Seccion.reportes);
        }),
        alReportar: _abrirFormulario,
      ),
      Seccion.reportes => const PantallaListado(),
      Seccion.bandeja => const PantallaAdministracion(),
      Seccion.perfil => PantallaPerfil(sesion: widget.sesion),
      // "Nuevo" no es una sección, es un formulario, por lo que aquí no se muestra.
      Seccion.nuevo => const SizedBox.shrink(),
    };
  }

  void _abrirFormulario() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PantallaFormulario()));
  }

  void _elegir(Destino destino, int indice) {
    if (destino.esAccion) {
      _abrirFormulario();
      return;
    }
    setState(() => _indice = indice);
  }

  @override
  Widget build(BuildContext context) {
    // Los botones salen del rol de quien inició sesión.
    final esOperador = widget.sesion.usuario?.esOperador ?? false;
    final destinos = destinosPara(esOperador ? Rol.operador : Rol.usuario);
    void alElegir(int i) => _elegir(destinos[i], i);

    // IndexedStack deja cada sección cargada al cambiar de una a otra.
    final contenido = IndexedStack(
      index: _indice,
      children: [for (final d in destinos) _pagina(d.seccion, destinos)],
    );

    return LayoutBuilder(
      builder: (context, medidas) {
        if (medidas.maxWidth >= anchoEscritorio) {
          return Scaffold(
            body: Column(
              children: [
                EncabezadoWeb(
                  destinos: destinos,
                  indice: _indice,
                  alElegir: alElegir,
                ),
                Expanded(child: contenido),
              ],
            ),
          );
        }

        // El dock flota encima de las páginas. Se suma su alto al margen de
        // abajo para que el SafeArea de cada página no deje nada tapado.
        final medios = MediaQuery.of(context);
        final abajo = medios.padding.bottom < 16 ? 16.0 : medios.padding.bottom;
        return Scaffold(
          body: Stack(
            children: [
              MediaQuery(
                data: medios.copyWith(
                  padding: medios.padding.copyWith(bottom: abajo + 70),
                ),
                child: contenido,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: DockFlotante(
                    destinos: destinos,
                    indice: _indice,
                    alElegir: alElegir,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
