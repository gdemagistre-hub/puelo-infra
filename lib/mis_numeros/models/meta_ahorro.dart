class MetaAhorro {
  MetaAhorro({
    required this.id,
    required this.titulo,
    required this.objetivo,
    required this.ahorrado,
    required this.creada,
  });

  final String id;
  final String titulo;
  final double objetivo;
  final double ahorrado;
  final DateTime creada;

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
  }) {
    return MetaAhorro(
      id: id,
      titulo: titulo ?? this.titulo,
      objetivo: objetivo ?? this.objetivo,
      ahorrado: ahorrado ?? this.ahorrado,
      creada: creada,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'objetivo': objetivo,
        'ahorrado': ahorrado,
        'creada': creada.toIso8601String(),
      };

  factory MetaAhorro.fromJson(Map<String, dynamic> json) {
    return MetaAhorro(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      objetivo: (json['objetivo'] as num).toDouble(),
      ahorrado: (json['ahorrado'] as num).toDouble(),
      creada: DateTime.parse(json['creada'] as String),
    );
  }
}
