enum TipoMovimiento { cobro, gasto, retiro }

enum CategoriaGasto {
  materiales,
  transporte,
  herramientas,
  comida,
  ahorro,
  otros,
}

extension CategoriaGastoLabel on CategoriaGasto {
  String get label {
    switch (this) {
      case CategoriaGasto.materiales:
        return 'Materiales';
      case CategoriaGasto.transporte:
        return 'Transporte';
      case CategoriaGasto.herramientas:
        return 'Herramientas';
      case CategoriaGasto.comida:
        return 'Comida / Viaticos';
      case CategoriaGasto.ahorro:
        return 'Ahorro / Meta';
      case CategoriaGasto.otros:
        return 'Otros';
    }
  }
}

class Movimiento {
  Movimiento({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.nota,
    this.categoria,
  });

  final String id;
  final TipoMovimiento tipo;
  final double monto;
  final DateTime fecha;
  final String? nota;
  final CategoriaGasto? categoria;

  bool get esCobro => tipo == TipoMovimiento.cobro;
  bool get esGasto => tipo == TipoMovimiento.gasto;
  bool get esRetiro => tipo == TipoMovimiento.retiro;

  bool get esApartadoMeta =>
      esGasto && categoria == CategoriaGasto.ahorro;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'monto': monto,
        'fecha': fecha.toIso8601String(),
        'nota': nota,
        'categoria': categoria?.name,
      };

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    CategoriaGasto? cat;
    final catName = json['categoria'] as String?;
    if (catName != null) {
      cat = CategoriaGasto.values.cast<CategoriaGasto?>().firstWhere(
            (c) => c?.name == catName,
            orElse: () => CategoriaGasto.otros,
          );
    }
    final tipoName = json['tipo'] as String? ?? 'gasto';
    final tipo = TipoMovimiento.values.cast<TipoMovimiento?>().firstWhere(
          (t) => t?.name == tipoName,
          orElse: () => TipoMovimiento.gasto,
        ) ??
        TipoMovimiento.gasto;
    return Movimiento(
      id: json['id'] as String,
      tipo: tipo,
      monto: (json['monto'] as num).toDouble(),
      fecha: DateTime.parse(json['fecha'] as String),
      nota: json['nota'] as String?,
      categoria: cat,
    );
  }
}
