import 'package:flutter/material.dart';

import '../componentes/cabecera_marca.dart';
import '../servicios/sesion.dart';
import 'armazon.dart';
import 'inicio_sesion.dart';
import 'registro.dart';

/// Primera pantalla de la app. Es una sola pantalla con dos vistas, iniciar sesión y
/// crear la cuenta, en ambas el header con la marca se queda y solo cambia de tamaño,
/// y los formularios se deslizan de lado.
class PantallaAcceso extends StatefulWidget {
  const PantallaAcceso({super.key, required this.sesion});

  final Sesion sesion;

  @override
  State<PantallaAcceso> createState() => _EstadoAcceso();
}

class _EstadoAcceso extends State<PantallaAcceso> {
  static const _llaveEntrar = ValueKey('entrar');
  static const _llaveRegistro = ValueKey('registro');

  bool _registro = false;

  void _cambiarVista(bool registro) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _registro = registro);
  }

  void _entrarALaApp() {
    // Reemplaza la pantalla para que no se pueda volver al inicio de sesión.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => Armazon(sesion: widget.sesion)),
    );
  }

  Widget _transicion(Widget hijo, Animation<double> animacion) {
    final entrante = hijo.key == (_registro ? _llaveRegistro : _llaveEntrar);
    // Al ir al registro el formulario nuevo llega por la derecha y el viejo se
    // va por la izquierda, mientras que al volver, es al revés.
    final sentido = _registro ? 1.0 : -1.0;
    final desde = Offset((entrante ? sentido : -sentido) * 0.12, 0);

    Widget resultado = FadeTransition(
      opacity: animacion,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: desde,
          end: Offset.zero,
        ).animate(animacion),
        child: hijo,
      ),
    );
    // El formulario que se va ya no se puede tocar ni leer.
    if (!entrante) {
      resultado = IgnorePointer(
        child: ExcludeFocus(child: ExcludeSemantics(child: resultado)),
      );
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        // Al arrastrar la pantalla el teclado se cierra.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            CabeceraMarca(registro: _registro),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              reverseDuration: const Duration(milliseconds: 300),
              // El formulario nuevo espera un poco a que el otro se vaya.
              switchInCurve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
              switchOutCurve: const Interval(0, 0.7),
              transitionBuilder: _transicion,
              layoutBuilder: (actual, anteriores) => Stack(
                alignment: Alignment.topCenter,
                children: [...anteriores, ?actual],
              ),
              child: _registro
                  ? FormularioRegistro(
                      key: _llaveRegistro,
                      sesion: widget.sesion,
                      alEntrar: _entrarALaApp,
                      alIrAEntrar: () => _cambiarVista(false),
                    )
                  : FormularioInicioSesion(
                      key: _llaveEntrar,
                      sesion: widget.sesion,
                      alEntrar: _entrarALaApp,
                      alCrearCuenta: () => _cambiarVista(true),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
