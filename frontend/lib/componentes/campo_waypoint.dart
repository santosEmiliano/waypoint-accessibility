import 'package:flutter/material.dart';

/// Campo de texto con una título arriba.
/// Si es de contraseña, trae el botón para mostrarla u ocultarla.
class CampoWaypoint extends StatefulWidget {
  const CampoWaypoint({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.pista, // El placeholder
    this.validador, // Validaciones que aplican al input
    this.teclado, // Tipo de teclado que utiliza
    this.mayusculas = TextCapitalization.none, // Por ejemplo, para nombres
    this.ayuda, // Texto debajo del input para dar mensajes o instrucciones (como "Mínimo 8 caracteres")
    this.esContrasena = false, // Muestra o no la opción para ocultar el texto
    this.errorServidor, // Errores que vienen del backend
    this.alCambiar,
    this.habilitado = true,
    this.accion = TextInputAction.next,
    this.alEnviar,
  });

  final String etiqueta;
  final TextEditingController controlador;

  /// Texto de ejemplo que se ve mientras el campo está vacío.
  final String? pista;

  final String? Function(String?)? validador;
  final TextInputType? teclado;
  final TextCapitalization mayusculas;

  /// Texto que se ve debajo mientras el campo no tenga un error.
  final String? ayuda;
  final bool esContrasena;

  /// Problema de este campo que devolvió el servidor.
  final String? errorServidor;

  final ValueChanged<String>? alCambiar;
  final bool habilitado;
  final TextInputAction accion;
  final VoidCallback? alEnviar;

  @override
  State<CampoWaypoint> createState() => _EstadoCampo();
}

class _EstadoCampo extends State<CampoWaypoint> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    final botonMostrar = TextButton.icon(
      onPressed: () => setState(() => _oculta = !_oculta),
      icon: Icon(
        _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      label: Text(_oculta ? 'Mostrar' : 'Ocultar'),
      style: TextButton.styleFrom(textStyle: texto.labelMedium),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La etiqueta se lee junto con el campo, no por separado.
        ExcludeSemantics(
          child: Text(widget.etiqueta, style: texto.labelMedium),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: widget.etiqueta,
          child: TextFormField(
            controller: widget.controlador,
            enabled: widget.habilitado,
            keyboardType: widget.teclado,
            textCapitalization: widget.mayusculas,
            textInputAction: widget.accion,
            obscureText: widget.esContrasena && _oculta,
            autocorrect: !widget.esContrasena,
            enableSuggestions: !widget.esContrasena,
            validator: widget.validador,
            forceErrorText: widget.errorServidor,
            onChanged: widget.alCambiar,
            // En IOS, el teclado no se cierra solo, entonces, al tocar fuera de los
            // campos se quita el foco. Tocar otro campo no cuenta como fuera.
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onFieldSubmitted: (_) => widget.alEnviar?.call(),
            style: texto.bodyLarge,
            decoration: InputDecoration(
              hintText: widget.pista,
              helperText: widget.ayuda,
              suffixIcon: widget.esContrasena ? botonMostrar : null,
            ),
          ),
        ),
      ],
    );
  }
}
