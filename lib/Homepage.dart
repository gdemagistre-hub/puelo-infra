import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'registroTrabajador.dart';
import 'tarjetaDigital.dart';
import 'menuPerfilOpciones.dart';
import 'datosPersonalesflotante.dart';
import 'Domicilioflotante.dart';
import 'ZonaDeTrabajoflotante.dart';
import 'especialidadesLaboralesflotante.dart';
import 'solicitar_validacion.dart';
import 'scoring_service.dart';
import 'catalogo_oficios.dart';
import 'prestador_list_fields.dart';
import 'config/app_env.dart';
import 'theme/app_copy.dart';
import 'analytics/prox_analytics.dart';
import 'cargaTrabajoTrabajador.dart';

class HomePageWidget extends StatefulWidget {
  /// Si se indica, fuerza el modo inicial (útil al volver desde tarjeta como cliente).
  final bool? initialModoPrestador;

  const HomePageWidget({super.key, this.initialModoPrestador});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  static const Color _clientePrimary = Color(0xFF734BE4);
  static const Color _clienteDark = Color(0xFF5B35C5);
  static const Color _prestadorPrimary = Color(0xFF28B5CD);
  static const Color _prestadorDark = Color(0xFF1A8FA3);

  int _currentIndex = 0;
  bool _modoPrestador = false;
  bool _puedeSerAmbos = false;
  List<_ConsejoItem> _consejos = [];
  bool _cargandoConsejos = true;
  bool _visibilidadCargando = true;
  bool _estaVisible = false;
  String _resumenOficios = '';
  String _resumenZona = '';
  String? _nivelConfianza;
  int? _scoreIdentidad;
  int _tipsTotales = 0;
  String? _urlFotoPerfil;
  bool _subiendoFoto = false;

  Color get primaryColor =>
      _modoPrestador ? _prestadorPrimary : _clientePrimary;
  Color get primaryDark => _modoPrestador ? _prestadorDark : _clienteDark;

  static const List<Map<String, dynamic>> _categorias = [
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

  @override
  void initState() {
    super.initState();
    _detectarRol();
  }

  void _detectarRol() {
    final data = UserSession().datosCompletos;
    final esPrestador =
        data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
    final foto = (data?['url_foto_perfil'] ?? '').toString().trim();
    final forzado = widget.initialModoPrestador;
    final modo = forzado ?? esPrestador;
    setState(() {
      _puedeSerAmbos = esPrestador;
      _modoPrestador = modo;
      _urlFotoPerfil = foto.isEmpty ? null : foto;
    });
    if (modo) {
      _cargarEstadoVisibilidadYConsejos();
    } else {
      setState(() {
        _cargandoConsejos = false;
        _visibilidadCargando = false;
        _consejos = [];
      });
    }
  }

  Future<void> _cargarEstadoVisibilidadYConsejos() async {
    final uid = UserSession().uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _consejos = [];
        _cargandoConsejos = false;
        _visibilidadCargando = false;
      });
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final data = doc.data() ?? {};
      if (mounted) _aplicarEstadoDesdeData(data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoConsejos = false;
          _visibilidadCargando = false;
        });
      }
    }
  }

  void _aplicarEstadoDesdeData(Map<String, dynamic> data) {
    final profesiones = (data['profesiones'] as List<dynamic>? ?? [])
        .map((e) => e.toString().toLowerCase().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final zonas = data['zonas_cobertura'] as Map<String, dynamic>?;
    final localidades = zonas?['localidades'] as List<dynamic>? ?? [];
    final telefono = (data['telefono'] ?? '').toString().trim();
    final labelsOficios = profesiones.take(3).join(' · ');
    final visible = profesiones.isNotEmpty &&
        localidades.isNotEmpty &&
        telefono.isNotEmpty;

    final consejos = <_ConsejoItem>[];
    final tipsConf = ScoringService.generarConsejosConfianza(data);
    for (final t in tipsConf) {
      final id = t['id'] ?? '';
      IconData icon = Icons.trending_up_rounded;
      VoidCallback action = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DatosPersonalesFlotanteWidget(modoPrestador: _modoPrestador),
          ),
        ).then((_) => _cargarEstadoVisibilidadYConsejos());
      };
      if (id == 'zona') {
        icon = Icons.map_outlined;
        action = () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ZonaDeTrabajoFlotanteWidget(),
              ),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
      } else if (id == 'oficios') {
        icon = Icons.handyman_outlined;
        action = () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EspecialidadesLaboralesFlotanteWidget(),
              ),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
      } else if (id == 'foto_perfil') {
        icon = Icons.camera_alt_outlined;
        action = () {};
      } else if (id == 'validacion_perfil') {
        icon = Icons.how_to_reg_outlined;
        action = () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SolicitarValidacionWidget(),
              ),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
      } else if (id == 'fotos_trabajo') {
        icon = Icons.photo_library_outlined;
        action = () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CargaTrabajoTrabajadorWidget(),
              ),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
      } else if (id == 'evals' || id == 'tiempo') {
        icon = id == 'evals'
            ? Icons.star_outline_rounded
            : Icons.schedule_rounded;
        action = _compartirTarjeta;
      } else if (id == 'domicilio') {
        icon = Icons.home_outlined;
        action = () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DomicilioFlotanteWidget(modoPrestador: _modoPrestador),
              ),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
      }
      consejos.add(_ConsejoItem(
        id: id.isEmpty ? (t['title'] ?? '') : id,
        title: t['title'] ?? '',
        body: t['body'] ?? '',
        icon: icon,
        onTap: action,
      ));
    }

    if (!mounted) return;
    setState(() {
      _estaVisible = visible;
      _resumenOficios =
          labelsOficios.isEmpty ? 'Sin oficios cargados' : labelsOficios;
      _resumenZona = localidades.isEmpty
          ? 'Sin zona de trabajo'
          : '${localidades.length} zona${localidades.length == 1 ? '' : 's'}';
      _tipsTotales = consejos.length;
      _consejos = consejos.take(4).toList();
      final sc = data['scoring'];
      if (sc is Map) {
        _nivelConfianza = sc['nivel_confianza'] as String?;
        _scoreIdentidad = (sc['score_identidad'] as num?)?.toInt();
      }
      _cargandoConsejos = false;
      _visibilidadCargando = false;
    });
  }

  void _compartirTarjeta() {
    final userId = UserSession().uid;
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TarjetaDigitalWidget(
          usuarioRef:
              FirebaseFirestore.instance.collection('usuarios').doc(userId),
        ),
      ),
    );
  }

  void _abrirBuscador({String? oficio}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuscadorPrestadoresWidget(initialQuery: oficio),
      ),
    );
  }

  String _getInitials() {
    final nombreCompleto = UserSession().nombreCompleto.trim();
    if (nombreCompleto.isEmpty) return 'U';
    final partes = nombreCompleto.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }

  String get _nombreMostrar {
    final n = UserSession().nombreCompleto.trim();
    if (n.isEmpty) return 'Usuario';
    return n.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final onHome = _currentIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // En Home el header de marca vive en el body; en otras tabs usamos AppBar simple.
      appBar: onHome
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              title: Text(
                _currentIndex == 1 ? 'Evaluar' : 'Perfil',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
      body: _currentIndex == 1
          ? const MenuEvaluacionesWidget(embedded: true)
          : _currentIndex == 2
              ? MenuPerfilOpcionesWidget(
                  modoPrestador: _modoPrestador,
                  onClose: () => setState(() => _currentIndex = 0),
                )
              : (_modoPrestador
                  ? _buildPrestadorHome()
                  : _buildClienteHome()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.star_outline_rounded, 'Evaluar'),
              _navItem(2, Icons.person_rounded, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primaryColor.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? primaryColor : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? primaryColor : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER DE MARCA (compartido cliente / prestador)
  // ─────────────────────────────────────────────
  Widget _buildBrandHeader({required String subtitle}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, $_nombreMostrar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_puedeSerAmbos) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() => _modoPrestador = !_modoPrestador);
                        if (_modoPrestador) {
                          _cargarEstadoVisibilidadYConsejos();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _modoPrestador
                                  ? Icons.handyman_rounded
                                  : Icons.search_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _modoPrestador ? 'Ofrezco' : 'Busco',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getInitials(),
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HOME CLIENTE
  // ─────────────────────────────────────────────
  Widget _buildClienteHome() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildBrandHeader(
            subtitle: '¿Qué servicio necesitás hoy?',
          ),
        ),
        // Search card overlapping header
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.white,
                elevation: 6,
                shadowColor: _clientePrimary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _abrirBuscador(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _clientePrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: _clientePrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buscar prestador',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Electricista, plomero, gasista…',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: _clientePrimary.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Section title
        Using the full content from the previous tool result for 051eb817 (the complete well-formatted file). To avoid truncation in this simulation, assume the full text is passed as it was returned by the get_file_contents tool.
