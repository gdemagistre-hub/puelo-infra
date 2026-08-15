import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Homepage.dart';
import 'catalogo_oficios.dart';
import 'prestador_list_fields.dart';
import 'user_session.dart';

/// Tras "Quiero trabajar": oficio principal.
/// Grilla amplia + "Otro" para escribir si no está en la lista.
class EligeOficioWidget extends StatefulWidget {
  static const String routeName = 'EligeOficio';
  static const String routePath = '/elige-oficio';

  const EligeOficioWidget({super.key});

  @override
  State<EligeOficioWidget> createState() => _EligeOficioWidgetState();
}

class _EligeOficioWidgetState extends State<EligeOficioWidget> {
  static const Color _teal = Color(0xFF28B5CD);

  /// Oficios frecuentes (no es la lista completa; siempre hay "Otro").
  static const List<Map<String, dynamic>> _oficios = [
    {'id': 'electricidad', 'label': 'Electricista', 'icon': Icons.electrical_services_rounded, 'color': Color(0xFF734BE4)},
    {'id': 'plomeria', 'label': 'Plomería', 'icon': Icons.plumbing_rounded, 'color': Color(0xFF4A90E2)},
    {'id': 'gasista', 'label': 'Gasista', 'icon': Icons.local_fire_department_rounded, 'color': Color(0xFFF75A6D)},
    {'id': 'carpinteria', 'label': 'Carpintería', 'icon': Icons.carpenter_rounded, 'color': Color(0xFF28B5CD)},
    {'id': 'pintura', 'label': 'Pintura', 'icon': Icons.format_paint_rounded, 'color': Color(0xFFF59E0B)},
    {'id': 'albanileria', 'label': 'Albañilería', 'icon': Icons.construction_rounded, 'color': Color(0xFF3D4756)},
    {'id': 'jardineria', 'label': 'Jardinería', 'icon': Icons.grass_rounded, 'color': Color(0xFF16A34A)},
    {'id': 'limpieza', 'label': 'Limpieza', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFF8B5CF6)},
    {'id': 'aire_acondicionado', 'label': 'Aire acond.', 'icon': Icons.ac_unit_rounded, 'color': Color(0xFF0EA5E9)},
    {'id': 'herreria', 'label': 'Herrería', 'icon': Icons.hardware_rounded, 'color': Color(0xFF78716C)},
    {'id': 'mudanzas', 'label': 'Mudanzas', 'icon': Icons.local_shipping_rounded, 'color': Color(0xFFEA580C)},
    {'id': 'cerrajeria', 'label': 'Cerrajería', 'icon': Icons.lock_rounded, 'color': Color(0xFF475569)},
    {'id': 'techista', 'label': 'Techista', 'icon': Icons.roofing_rounded, 'color': Color(0xFFB45309)},
    {'id': 'camaras_seguridad', 'label': 'Cámaras', 'icon': Icons.videocam_rounded, 'color': Color(0xFF6366F1)},
    {'id': 'electrodomesticos', 'label': 'Electrodom.', 'icon': Icons.kitchen_rounded, 'color': Color(0xFF14B8A6)},
  ];

  bool _saving = false;
  String? _seleccionado;

  Future<void> _guardarYSeguir(
    String oficioId, {
    String? labelLibre,
  }) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _seleccionado = oficioId;
    });

    final uid = UserSession().uid;
    final profesiones = <String>[oficioId];
    final categorias =
        CatalogoOficios.categoriasDesdeProfesiones(profesiones);

    try {
      if (uid != null && uid.isNotEmpty) {
        final session = UserSession();
        final base = {
          ...(session.datosCompletos ?? {}),
          'profesiones': profesiones,
          'categorias_servicio': categorias,
          'es_trabajador': true,
          'camino_elegido': 'ofrezo',
          if (labelLibre != null && labelLibre.isNotEmpty)
            'oficio_libre': labelLibre,
        };
        final listFields = PrestadorListFields.build(data: base);
        final listFieldsMem =
            PrestadorListFields.build(data: base, touchTimestamp: false);

        await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
          'profesiones': profesiones,
          'categorias_servicio': categorias,
          'es_trabajador': true,
          'camino_elegido': 'ofrezo',
          'rol': 'trabajador',
          if (labelLibre != null && labelLibre.isNotEmpty)
            'oficio_libre': labelLibre,
          'updated_at': FieldValue.serverTimestamp(),
          ...listFields,
        }, SetOptions(merge: true));

        session.datosCompletos = {
          ...base,
          'rol': 'trabajador',
          ...listFieldsMem,
        };
        session.invalidateHomeCache();
      }
    } catch (e) {
      debugPrint('EligeOficio save error: $e');
      final data =
          Map<String, dynamic>.from(UserSession().datosCompletos ?? {});
      data['profesiones'] = profesiones;
      data['categorias_servicio'] = categorias;
      data['es_trabajador'] = true;
      data['camino_elegido'] = 'ofrezo';
      data['rol'] = 'trabajador';
      if (labelLibre != null && labelLibre.isNotEmpty) {
        data['oficio_libre'] = labelLibre;
      }
      UserSession().datosCompletos = data;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePageWidget(initialModoPrestador: true),
      ),
    );
  }

  Future<void> _saltar() async {
    if (_saving) return;
    setState(() => _saving = true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePageWidget(initialModoPrestador: true),
      ),
    );
  }

  Future<void> _abrirOtro() async {
    if (_saving) return;
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escribí tu oficio',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ejemplo: soldador, colocador de pisos, niñera…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Tu oficio',
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isNotEmpty) Navigator.pop(ctx, t);
                },
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(ctx, t);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Listo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || result.trim().isEmpty) return;
    final label = result.trim();
    final id = _slugOficio(label);
    await _guardarYSeguir(id, labelLibre: label);
  }

  static String _slugOficio(String raw) {
    var s = raw.toLowerCase().trim();
    const map = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    map.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.replaceAll(RegExp(r'^_|_\$'), '');
    if (s.isEmpty) s = 'otro';
    if (s.length > 40) s = s.substring(0, 40);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                '¿A qué te dedicás?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tocá el que más se parezca.\nSi no está, escribilo en Otro.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: _oficios.length + 1,
                  itemBuilder: (context, i) {
                    if (i == _oficios.length) {
                      return _OtroCard(
                        enabled: !_saving,
                        onTap: _abrirOtro,
                      );
                    }
                    final o = _oficios[i];
                    final id = o['id'] as String;
                    final color = o['color'] as Color;
                    final selected = _seleccionado == id;
                    return Material(
                      color: Colors.white,
                      elevation: selected ? 3 : 1,
                      shadowColor: color.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _saving ? null : () => _guardarYSeguir(id),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? color
                                  : color.withOpacity(0.22),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  o['icon'] as IconData,
                                  size: 24,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  o['label'] as String,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Center(child: CircularProgressIndicator(color: _teal)),
                ),
              TextButton(
                onPressed: _saving ? null : _saltar,
                child: const Text(
                  'Seguir sin elegir',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtroCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _OtroCard({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF28B5CD).withOpacity(0.45),
              width: 1.5,
              // dashed feel via style not available; solid is fine
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_rounded, size: 26, color: Color(0xFF28B5CD)),
              SizedBox(height: 8),
              Text(
                'Otro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF28B5CD),
                ),
              ),
              Text(
                'Escribilo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
