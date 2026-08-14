enum EstadoFiado { pendiente, cobrado }

class Fiado {
  Fiado({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.creado,
    this.fechaAcordada,
    this.nota,
    this.estado = EstadoFiado.pendiente,
    this.cobradoAt,
  });

  final String id;
  final String nombre;
  final double monto;
  final DateTime creado;
  final DateTime? fechaAcordada;
  final String? nota;
  final EstadoFiado estado;
  final DateTime? cobradoAt;

  bool get esPendiente => estado == EstadoFiado.pendiente;

  Fiado copyWith({
    String? nombre,
    double? monto,
    DateTime? fechaAcordada,
    String? nota,
    EstadoFiado? estado,
    DateTime? cobradoAt,
    bool clearFechaAcordada = false,
  }) {
    return Fiado(
      id: id,
      nombre: nombre ?? this.nombre,
      monto: monto ?? this.monto,
      creado: creado,
      fechaAcordada:
          clearFechaAcordada ? null : (fechaAcordada ?? this.fechaAcordada),
      nota: nota ?? this.nota,
      estado: estado ?? this.estado,
      cobradoAt: cobradoAt ?? this.cobradoAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'monto': monto,
        'creado': creado.toIso8601String(),
        'fechaAcordada': fechaAcordada?.toIso8601String(),
        'nota': nota,
        'estado': estado.name,
        'cobradoAt': cobradoAt?.toIso8601String(),
      };

  factory Fiado.fromJson(Map<String, dynamic> json) {
    final estadoName = json['estado'] as String? ?? 'pendiente';
    final estado = EstadoFiado.values.cast<EstadoFiado?>().firstWhere(
          (e) => e?.name == estadoName,
          orElse: () => EstadoFiado.pendiente,
        ) ??
        EstadoFiado.pendiente;
    return Fiado(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? 'Sin nombre',
      monto: (json['monto'] as num?)?.toDouble() ?? 0,
      creado: DateTime.tryParse(json['creado'] as String? ?? '') ??
          DateTime.now(),
      fechaAcordada: json['fechaAcordada'] != null
          ? DateTime.tryParse(json['fechaAcordada'] as String)
          : null,
      nota: json['nota'] as String?,
      estado: estado,
      cobradoAt: json['cobradoAt'] != null
          ? DateTime.tryParse(json['cobradoAt'] as String)
          : null,
    );
  }
}
