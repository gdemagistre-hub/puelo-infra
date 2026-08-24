import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Homepage.dart';
import 'registroTrabajador.dart';
import 'catalogo_oficios.dart';
import 'prestador_list_fields.dart';
import 'user_session.dart';

class EligeOficioWidget extends StatefulWidget {
  static const String routeName = 'EligeOficio';
  static const String routePath = '/elige-oficio';

  const EligeOficioWidget({super.key});

  @override
  State<EligeOficioWidget> createState() => _EligeOficioWidgetState();
}

class _EligeOficioWidgetState extends State<EligeOficioWidget> {
  static const Color _teal = Color(0xFF28B5CD);

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
        await session.persistHomeModoPrestador(true);
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
      await UserSession().persistHomeModoPrestador(true);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const RegistroTrabajadorWidget(),
      ),
    );
  }

  Future<void> _saltar() async {
    if (_saving) return;
    setState(() => _saving = true);
    final session = UserSession();
    session.datosCompletos = {
      ...(session.datosCompletos ?? {}),
      'es_trabajador': true,
      'camino_elegido': 'ofrezo',
      'rol': 'trabajador',
    };
    await session.persistHomeModoPrestador(true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePageWidget(initialModoPrestador: true),
      ),
    );
  }
