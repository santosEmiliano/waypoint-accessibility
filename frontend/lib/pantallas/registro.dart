import 'package:flutter/material.dart';

import '../componentes/campo_waypoint.dart';
import '../servicios/error_api.dart';
import '../servicios/sesion.dart';
import '../utilidades/validadores.dart';

/// Formulario para crear la cuenta con nombre, correo y contraseña.
/// Lo muestra [PantallaAcceso] debajo de la cabecera.
class FormularioRegistro extends StatefulWidget {
  const FormularioRegistro({
    super.key,
    required this.sesion,
    required this.alEntrar,
    required this.alIrAEntrar,
  });

  final Sesion sesion;

  /// Se llama cuando la cuenta ya se creó y la sesión quedó iniciada.
  final VoidCallback alEntrar;

  /// Se llama al tocar «Entra».
  final VoidCallback alIrAEntrar;

  @override
  State<FormularioRegistro> createState() => _EstadoFormularioRegistro();
}

class _EstadoFormularioRegistro extends State<FormularioRegistro> {
  final _llave = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _ocupado = false;
  // Problemas por campo que devolvió el servidor.
  Map<String, String> _errores = {};

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    if (!(_llave.currentState?.validate() ?? false)) return;
    setState(() {
      _ocupado = true;
      _errores = {};
    });
    try {
      await widget.sesion.registrar(
        _nombre.text.trim(),
        _correo.text.trim(),
        _contrasena.text,
      );
      if (!mounted) return;
      widget.alEntrar();
    } on ErrorApi catch (e) {
      if (!mounted) return;
      if (e.codigo == 'CORREO_REGISTRADO') {
        // Se muestra debajo del campo del correo.
        setState(() => _errores = {'correo_usuario': e.mensaje});
      } else {
        setState(() => _errores = e.campos);
        if (e.campos.isEmpty) _avisar(e.mensaje);
      }
    } catch (_) {
      if (mounted) _avisar('No se pudo crear la cuenta. Inténtalo de nuevo.');
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
                  etiqueta: 'Nombre',
                  controlador: _nombre,
                  pista: 'Tu nombre completo',
                  teclado: TextInputType.name,
                  mayusculas: TextCapitalization.words,
                  validador: validarNombre,
                  errorServidor: _errores['nombre_usuario'],
                  alCambiar: (_) => setState(() => _errores = {}),
                  habilitado: !_ocupado,
                ),
                const SizedBox(height: 20),
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
                  ayuda: 'Mínimo 8 caracteres.',
                  validador: validarContrasenaNueva,
                  errorServidor: _errores['contrasena_usuario'],
                  alCambiar: (_) => setState(() => _errores = {}),
                  habilitado: !_ocupado,
                  accion: TextInputAction.done,
                  alEnviar: _crearCuenta,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _ocupado ? null : _crearCuenta,
                  child: _ocupado
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes cuenta?',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: _ocupado ? null : widget.alIrAEntrar,
                      child: const Text('Entra'),
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
