import 'package:waypoint/modelos/reporte.dart';
import 'package:waypoint/servicios/error_api.dart';
import 'package:waypoint/servicios/repositorio_falso.dart';
import 'package:waypoint/servicios/repositorio_waypoint.dart';

/// Repositorio falso sin espera que puede quedarse sin reportes o fallar
/// las primeras [fallas] peticiones de reportes.
class RepositorioPrueba extends RepositorioFalso {
  RepositorioPrueba({this.vacio = false, this.fallas = 0})
    : super(retraso: Duration.zero);

  final bool vacio;
  int fallas;

  /// Cuántas veces se pidió la lista de reportes, con qué filtros.
  final pedidos = <({int? idEstado, int? limite, int desde})>[];

  void _quizaFallar() {
    if (fallas > 0) {
      fallas--;
      throw const ErrorApi.sinConexion();
    }
  }

  @override
  Future<List<Reporte>> listarReportes({
    int? idEstado,
    int? idCategoria,
    String? texto,
    bool cancelados = false,
    int? limite,
    int desde = 0,
    OrdenReportes orden = OrdenReportes.creacion,
  }) async {
    pedidos.add((idEstado: idEstado, limite: limite, desde: desde));
    _quizaFallar();
    if (vacio) return [];
    return super.listarReportes(
      idEstado: idEstado,
      idCategoria: idCategoria,
      texto: texto,
      cancelados: cancelados,
      limite: limite,
      desde: desde,
      orden: orden,
    );
  }

  @override
  Future<Map<int, int>> resumenReportes({
    int? idCategoria,
    String? texto,
  }) async {
    final conteo = await super.resumenReportes(
      idCategoria: idCategoria,
      texto: texto,
    );
    return vacio ? conteo.map((id, _) => MapEntry(id, 0)) : conteo;
  }
}
