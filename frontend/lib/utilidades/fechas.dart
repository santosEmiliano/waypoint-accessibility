const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Fecha corta como "18 nov". Si no es de este año, le agrega el año: "18 nov 2025".
String fechaCorta(DateTime fecha, {DateTime? hoy}) {
  final local = fecha.toLocal();
  final texto = '${local.day} ${_meses[local.month - 1]}';
  final anioActual = (hoy ?? DateTime.now()).year;
  return local.year == anioActual ? texto : '$texto ${local.year}';
}
