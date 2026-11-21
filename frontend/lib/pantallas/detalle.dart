import 'package:flutter/material.dart';

class PantallaDetalle extends StatelessWidget {
  const PantallaDetalle({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: Text(
            'Detalle del reporte',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
      ),
    );
  }
}
