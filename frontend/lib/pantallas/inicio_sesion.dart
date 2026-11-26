import 'package:flutter/material.dart';

import '../componentes/campo_waypoint.dart';
import '../servicios/error_api.dart';
import '../servicios/sesion.dart';
import '../utilidades/validadores.dart';

/// Formulario para entrar con el correo y la contraseña.
/// Lo muestra [PantallaAcceso] debajo del header.
class FormularioInicioSesion extends StatefulWidget {
  const FormularioInicioSesion({
    super.key,
    required this.sesion,
    required this.alEntrar,
    required this.alCrearCuenta,
  });

  final Sesion sesion;

  /// Se llama cuando la sesión ya se inició.
  final VoidCallback alEntrar;

  /// Se llama al tocar «Crea tu cuenta».
  final VoidCallback alCrearCuenta;

  @override
  State<FormularioInicioSesion> createState() =>
      _EstadoFormularioInicioSesion();
}

class _EstadoFormularioInicioSesion extends State<FormularioInicioSesion> {
  final _llave = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _ocupado = false;
  // Problemas por campo que devolvió el servidor.
  Map<String, String> _errores = {};

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!(_llave.currentState?.validate() ?? false)) return;
    setState(() {
      _ocupado = true;
      _errores = {};
    });
    try {
      await widget.sesion.iniciarSesion(_correo.text.trim(), _contrasena.text);
      if (!mounted) return;
      widget.alEntrar();
    } on ErrorApi catch (e) {
      if (!mounted) return;
      setState(() => _errores = e.campos);
      // Si el error no es de un campo, se avisa con un mensaje.
      if (e.campos.isEmpty) _avisar(e.mensaje);
    } catch (_) {
      if (mounted) _avisar('No se pudo iniciar sesión. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Form(
            key: _llave,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoWaypoint(
                  etiqueta: 'Correo de la universidad',
                  controlador: _correo,
                  pista: 'al123456@edu.uaa.mx',
                  teclado: TextInputType.emailAddress,
                  validador: validarCorreo,
                  errorServidor: _errores['correo_usuario'],
                  alCambiar: (_) => setState(() => _errores = {}),
                  habilitado: !_ocupado,
                ),
                const SizedBox(height: 20),
                CampoWaypoint(
                  etiqueta: 'Contraseña',
                  controlador: _contrasena,
                  esContrasena: true,
                  validador: validarContrasenaEscrita,
                  errorServidor: _errores['contrasena_usuario'],
                  alCambiar: (_) => setState(() => _errores = {}),
                  habilitado: !_ocupado,
                  accion: TextInputAction.done,
                  alEnviar: _entrar,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _ocupado ? null : _entrar,
                  child: _ocupado
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '¿Primera vez aquí?',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: _ocupado ? null : widget.alCrearCuenta,
                      child: const Text('Crea tu cuenta'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
