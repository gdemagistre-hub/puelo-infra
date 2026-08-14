class Vencimiento {
  Vencimiento({
    required this.id,
    required this.titulo,
    required this.fecha,
    this.monto,
    this.pagado = false,
  });

  final String id;
  final String titulo;
  final DateTime fecha;
  final double? monto;
  final bool pagado;

  Vencimiento copyWith({bool? pagado}) {
    return Vencimiento(
      id: id,
      titulo: titulo,
      fecha: fecha,
      monto: monto,
      pagado: pagado ?? this.pagado,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'fecha': fecha.toIso8601String(),
        'monto': monto,
        'pagado': pagado,
      };

  factory Vencimiento.fromJson(Map<String, dynamic> json) {
    return Vencimiento(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      monto: json['monto'] != null ? (json['monto'] as num).toDouble() : null,
      pagado: json['pagado'] as bool? ?? false,
    );
  }
}
