import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'textos_legales.dart';

/// Pantalla de lectura de un documento legal.
class DocumentoLegalScreen extends StatelessWidget {
  final TipoDocumentoLegal tipo;
  final bool modoPrestador;

  const DocumentoLegalScreen({
    super.key,
    required this.tipo,
    this.modoPrestador = false,
  });

  Color get _accent =>
      modoPrestador ? AppColors.prestador : AppColors.cliente;

  String get _titulo {
    switch (tipo) {
      case TipoDocumentoLegal.terminos:
        return TextosLegales.terminosTitulo;
      case TipoDocumentoLegal.privacidad:
        return TextosLegales.privacidadTitulo;
      case TipoDocumentoLegal.buenasPracticas:
        return TextosLegales.buenasTitulo;
      case TipoDocumentoLegal.csae:
        return TextosLegales.csaeTitulo;
    }
  }

  String get _bajada {
    switch (tipo) {
      case TipoDocumentoLegal.terminos:
        return TextosLegales.terminosBajada;
      case TipoDocumentoLegal.privacidad:
        return TextosLegales.privacidadBajada;
      case TipoDocumentoLegal.buenasPracticas:
        return TextosLegales.buenasBajada;
      case TipoDocumentoLegal.csae:
        return TextosLegales.csaeBajada;
    }
  }

  List<LegalSection> get _secciones {
    switch (tipo) {
      case TipoDocumentoLegal.terminos:
        return TextosLegales.terminos;
      case TipoDocumentoLegal.privacidad:
        return TextosLegales.privacidad;
      case TipoDocumentoLegal.buenasPracticas:
        return TextosLegales.buenasPracticas;
      case TipoDocumentoLegal.csae:
        return TextosLegales.csae;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          tipo == TipoDocumentoLegal.csae
              ? 'Protección infantil'
              : _titulo,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            _bajada,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vigencia: ${TextosLegales.vigencia}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          if (TextosLegales.packNota().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              TextosLegales.packNota(),
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          ..._secciones.map((s) => _bloque(s)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              TextosLegales.pieLegal,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloque(LegalSection s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
