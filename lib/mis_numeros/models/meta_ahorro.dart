class MetaAhorro {
  MetaAhorro({
    required this.id,
    required this.titulo,
    required this.objetivo,
    required this.ahorrado,
    required this.creada,
    this.esFondoEmergencia = false,
  });

  final String id;
  final String titulo;
  final double objetivo;
  final double ahorrado;
  final DateTime creada;

  /// Colchón para imprevistos (días sin laburo, roturas). Visual y tratamiento distintos.
  final bool esFondoEmergencia;

  double get progreso {
    if (objetivo <= 0) return 0;
    final p = ahorrado / objetivo;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  bool get completada => ahorrado >= objetivo;

  MetaAhorro copyWith({
    String? titulo,
    double? objetivo,
    double? ahorrado,
    bool? esFondoEmergencia,
  }) {
    return MetaAhorro(
      id: id,
      titulo: titulo ?? this.titulo,
      objetivo: objetivo ?? this.objetivo,
      ahorrado: ahorrado ?? this.ahorrado,
      creada: creada,
      esFondoEmergencia: esFondoEmergencia ?? this.esFondoEmergencia,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'objetivo': objetivo,
        'ahorrado': ahorrado,
        'creada': creada.toIso8601String(),
        'esFondoEmergencia': esFondoEmergencia,
      };

  factory MetaAhorro.fromJson(Map<String, dynamic> json) {
    return MetaAhorro(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      objetivo: (json['objetivo'] as num).toDouble(),
      ahorrado: (json['ahorrado'] as num).toDouble(),
      creada: DateTime.parse(json['creada'] as String),
      esFondoEmergencia: json['esFondoEmergencia'] == true,
    );
  }
}
