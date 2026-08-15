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
    this.notificadoVtoDia,
  });

  final String id;
  final String nombre;
  final double monto;
  final DateTime creado;
  final DateTime? fechaAcordada;
  final String? nota;
  final EstadoFiado estado;
  final DateTime? cobradoAt;

  /// Último día (yyyy-MM-dd) en que el batch envió push de vencimiento.
  /// Queda en claro en Firestore (no es dato sensible).
  final String? notificadoVtoDia;

  bool get esPendiente => estado == EstadoFiado.pendiente;

  /// Día de vencimiento yyyy-MM-dd (para índice / batch).
  String? get vtoDia {
    final f = fechaAcordada;
    if (f == null) return null;
    final y = f.year.toString().padLeft(4, '0');
    final m = f.month.toString().padLeft(2, '0');
    final d = f.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Fiado copyWith({
    String? nombre,
    double? monto,
    DateTime? fechaAcordada,
    String? nota,
    EstadoFiado? estado,
    DateTime? cobradoAt,
    String? notificadoVtoDia,
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
      notificadoVtoDia: notificadoVtoDia ?? this.notificadoVtoDia,
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
        'notificado_vto_dia': notificadoVtoDia,
        // Campo claro para collectionGroup query del batch (no cifrado).
        'vto_dia': vtoDia,
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
      notificadoVtoDia: json['notificado_vto_dia'] as String?,
    );
  }
}
