import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Homepage.dart';
import 'catalogo_oficios.dart';
import 'prestador_list_fields.dart';
import 'user_session.dart';

/// Tras elegir "Quiero trabajar": un solo oficio principal, grilla grande.
/// Pensado para poco texto y una decisión a la vez.
class EligeOficioWidget extends StatefulWidget {
  static const String routeName = 'EligeOficio';
  static const String routePath = '/elige-oficio';

  const EligeOficioWidget({super.key});

  @override
  State<EligeOficioWidget> createState() => _EligeOficioWidgetState();
}

class _EligeOficioWidgetState extends State<EligeOficioWidget> {
  static const Color _teal = Color(0xFF28B5CD);

  /// Mismos 8 oficios de la home cliente (labels cortos).
  static const List<Map<String, dynamic>> _oficios = [
    {
      'id': 'electricidad',
      'label': 'Electricista',
      'icon': Icons.electrical_services_rounded,
      'color': Color(0xFF734BE4),
    },
    {
      'id': 'plomeria',
      'label': 'Plomería',
      'icon': Icons.plumbing_rounded,
      'color': Color(0xFF4A90E2),
    },
    {
      'id': 'gasista',
      'label': 'Gasista',
      'icon': Icons.local_fire_department_rounded,
      'color': Color(0xFFF75A6D),
    },
    {
      'id': 'carpinteria',
      'label': 'Carpintería',
      'icon': Icons.carpenter_rounded,
      'color': Color(0xFF28B5CD),
    },
    {
      'id': 'pintura',
      'label': 'Pintura',
      'icon': Icons.format_paint_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'id': 'albanileria',
      'label': 'Construcción',
      'icon': Icons.construction_rounded,
      'color': Color(0xFF3D4756),
    },
    {
      'id': 'jardineria',
      'label': 'Jardinería',
      'icon': Icons.grass_rounded,
      'color': Color(0xFF16A34A),
    },
    {
      'id': 'limpieza',
      'label': 'Limpieza',
      'icon': Icons.cleaning_services_rounded,
      'color': Color(0xFF8B5CF6),
    },
  ];

  bool _saving = false;
  String? _seleccionado;

  Future<void> _guardarYSeguir(String oficioId) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text(
                '¿Qué oficio hacés?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Elegí el principal.\nDespués podés sumar más.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: _oficios.length,
                  itemBuilder: (context, i) {
                    final o = _oficios[i];
                    final id = o['id'] as String;
                    final color = o['color'] as Color;
                    final selected = _seleccionado == id;
                    return Material(
                      color: Colors.white,
                      elevation: selected ? 4 : 1.5,
                      shadowColor: color.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _saving ? null : () => _guardarYSeguir(id),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? color
                                  : color.withOpacity(0.25),
                              width: selected ? 2.5 : 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  o['icon'] as IconData,
                                  size: 30,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                o['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: color,
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
                  padding: EdgeInsets.only(bottom: 8),
                  child: Center(child: CircularProgressIndicator(color: _teal)),
                ),
              TextButton(
                onPressed: _saving ? null : _saltar,
                child: const Text(
                  'Elegir después',
                  style: TextStyle(
                    fontSize: 14,
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
