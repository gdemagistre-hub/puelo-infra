import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Homepage.dart';
import 'catalogo_oficios.dart';
import 'prestador_list_fields.dart';
import 'user_session.dart';

/// Tras "Quiero trabajar": oficio principal desde el catálogo.
/// Typeahead sobre CatalogoOficios (ids + labels + sinónimos).
/// Texto libre solo como excepción, con aviso de riesgo de no aparecer en buscador.
class EligeOficioWidget extends StatefulWidget {
  static const String routeName = 'EligeOficio';
  static const String routePath = '/elige-oficio';

  const EligeOficioWidget({super.key});

  @override
  State<EligeOficioWidget> createState() => _EligeOficioWidgetState();
}

class _EligeOficioWidgetState extends State<EligeOficioWidget> {
  static const Color _teal = Color(0xFF28B5CD);

  /// Atajos frecuentes (mismo catálogo; solo UX rápida).
  static const List<Map<String, dynamic>> _atajos = [
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
  ];

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _saving = false;
  String? _seleccionado;
  List<OficioEspecialidad> _sugerencias = const [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _sugerencias = CatalogoOficios.sugerencias(value, limit: 12);
    });
  }

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

        final patch = <String, dynamic>{
          'profesiones': profesiones,
          'categorias_servicio': categorias,
          'es_trabajador': true,
          'camino_elegido': 'ofrezo',
          'rol': 'trabajador',
          'updated_at': FieldValue.serverTimestamp(),
          ...listFields,
        };
        if (labelLibre != null && labelLibre.isNotEmpty) {
          patch['oficio_libre'] = labelLibre;
        } else {
          // Si eligió del catálogo, limpiamos un libre previo.
          patch['oficio_libre'] = FieldValue.delete();
        }

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .set(patch, SetOptions(merge: true));

        session.datosCompletos = {
          ...base,
          'rol': 'trabajador',
          if (labelLibre == null || labelLibre.isEmpty) 'oficio_libre': null,
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

  Future<void> _abrirExcepcionLibre() async {
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
                '¿No está en la lista?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: const Text(
                  'Si lo escribís vos, puede que no te encuentren '
                  'cuando alguien busque ese trabajo.\n'
                  'Mejor elegí el más parecido de la lista.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Tu oficio (solo si no hay parecido)',
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
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(ctx, t);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Guardar igual (puede no aparecer en búsquedas)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Volver a la lista',
                  style: TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || result.trim().isEmpty) return;
    final label = result.trim();
    await _guardarYSeguir(_slugOficio(label), labelLibre: label);
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
    final buscando = _searchCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              const Text(
                '¿A qué te dedicás?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Escribí y elegí de la lista.\nAsí te encuentran cuando busquen ese trabajo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                enabled: !_saving,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Ej: plomería, cerámicos, mudanzas…',
                  prefixIcon: const Icon(Icons.search_rounded, color: _teal),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _teal.withOpacity(0.35)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _teal.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _teal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: buscando
                    ? _buildSugerencias()
                    : _buildAtajos(),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Center(child: CircularProgressIndicator(color: _teal)),
                ),
              TextButton(
                onPressed: _saving ? null : _abrirExcepcionLibre,
                child: const Text(
                  'No está en la lista',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _saving ? null : _saltar,
                child: const Text(
                  'Seguir sin elegir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSugerencias() {
    if (_sugerencias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text(
                'No encontramos eso en el catálogo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Probá con otras palabras o tocá un atajo abajo.\n'
                'Si no aparece, usá “No está en la lista”.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.35),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _searchCtrl.clear();
                  _onSearchChanged('');
                  _searchFocus.unfocus();
                },
                child: const Text(
                  'Ver atajos',
                  style: TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _sugerencias.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final esp = _sugerencias[i];
        final selected = _seleccionado == esp.id;
        final icon = CatalogoOficios.iconFor(esp.id);
        return Material(
          color: Colors.white,
          elevation: selected ? 2 : 0.5,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _saving ? null : () => _guardarYSeguir(esp.id),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _teal : const Color(0xFFE2E8F0),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: _teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esp.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (esp.sinonimos.isNotEmpty)
                          Text(
                            esp.sinonimos.take(3).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAtajos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Atajos frecuentes',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: _atajos.length,
            itemBuilder: (context, i) {
              final o = _atajos[i];
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
                        color: selected ? color : color.withOpacity(0.22),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            o['icon'] as IconData,
                            size: 22,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
      ],
    );
  }
}
