import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'user_session.dart';
import 'scoring_service.dart';

class PerfilCompletoFlotanteWidget extends StatefulWidget {
  const PerfilCompletoFlotanteWidget({super.key});

  @override
  State<PerfilCompletoFlotanteWidget> createState() =>
      _PerfilCompletoFlotanteWidgetState();
}

class _PerfilCompletoFlotanteWidgetState
    extends State<PerfilCompletoFlotanteWidget> {
  static const Color primaryColor = Color(0xFF734BE4);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF1E293B);

  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        _data = doc.data()!;
      }
    } catch (e) {
      debugPrint('Error cargando perfil completo: $e');
    }

    setState(() => _loading = false);
  }

  String _str(dynamic v) =>
      (v ?? '—').toString().trim().isEmpty ? '—' : v.toString();

  String _fechaNac() {
    final f = _data['fecha_nacimiento'];
    if (f == null) return '—';
    if (f is Timestamp) return DateFormat('dd/MM/yyyy').format(f.toDate());
    if (f is String) {
      final d = DateTime.tryParse(f);
      return d != null ? DateFormat('dd/MM/yyyy').format(d) : f;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final geo = _data['direccion_geo'] as Map<String, dynamic>? ?? {};
    final cobertura = _data['zonas_cobertura'] as Map<String, dynamic>? ?? {};
    final profesiones = (_data['profesiones'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final locsCobertura = (cobertura['localidades'] as List<dynamic>? ?? [])
        .map((l) => l is Map ? (l['nombre'] ?? '').toString() : l.toString())
        .where((s) => s.isNotEmpty)
        .toList();

    final badge = _data['badge_prestador'] as String?;
    final score = _data['score_credito'];
    final telefono = _str(_data['telefono']);
    final whatsapp = _data['tiene_whatsapp'] == true;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: _textColor,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mi perfil completo',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (badge != null &&
                    ScoringService.labelBadge(badge).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        _badgeChip(badge),
                        if (score != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            'Score $score',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                _sectionCard(
                  title: 'Datos personales',
                  children: [
                    _row('Nombre', _str(_data['nombre'])),
                    _row('Apellido', _str(_data['apellido'])),
                    _row(
                      'Celular',
                      telefono == '—'
                          ? '—'
                          : '$telefono${whatsapp ? ' · WhatsApp' : ''}',
                    ),
                    _row(
                      'Tipo de documento',
                      _str(_data['tipo_doc'] ?? _data['tipo_documento']),
                    ),
                    _row(
                      'País de emisión',
                      _str(_data['pais_doc'] ?? _data['pais_emision']),
                    ),
                    _row(
                      'Número de documento',
                      _str(
                        _data['doc_numero'] ?? _data['numero_documento'],
                      ),
                    ),
                    _row('Fecha de nacimiento', _fechaNac()),
                    _row('Email', _str(_data['email'])),
                    _row(
                      'Instagram',
                      _str(
                        _data['instagram'] ?? _data['usuario_instagram'],
                      ),
                    ),
                    if (_data['url_foto_documento'] != null &&
                        _data['url_foto_documento'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Foto del documento',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _data['url_foto_documento'].toString(),
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Text('No se pudo cargar la imagen'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Domicilio particular',
                  children: [
                    _row('Calle', _str(_data['calle'])),
                    _row('Número', _str(_data['numero'])),
                    _row(
                      'Piso / Departamento',
                      _str(_data['piso_depto'] ?? _data['piso']),
                    ),
                    _row('Provincia', _str(geo['provincia_nombre'])),
                    _row('Partido / Departamento', _str(geo['partido_nombre'])),
                    _row('Localidad', _str(geo['localidad_nombre'])),
                    _row(
                      'Código postal',
                      _str(_data['cp'] ?? _data['codigo_postal']),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Información profesional',
                  children: [
                    _row(
                      'Nombre comercial',
                      _str(
                        _data['nombre_comercial'] ?? _data['nombreComercial'],
                      ),
                    ),
                    _row(
                      'Oficios / Especialidades',
                      profesiones.isEmpty ? '—' : profesiones.join(', '),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Zona de cobertura',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _row('Provincia', _str(cobertura['provincia_nombre'])),
                    _row(
                      'Localidades',
                      locsCobertura.isEmpty ? '—' : locsCobertura.join(', '),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _badgeChip(String? badge) {
    final label = ScoringService.labelBadge(badge);
    if (label.isEmpty) return const SizedBox.shrink();
    final c = ScoringService.coloresBadge(badge);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color(c.background),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(c.foreground).withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(c.foreground),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
