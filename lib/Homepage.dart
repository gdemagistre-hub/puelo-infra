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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _clientePrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Oficios',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Category grid — heavier cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = _categorias[index];
                final Color accent =
                    (cat['color'] as Color?) ?? _clientePrimary;
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () =>
                        _abrirBuscador(oficio: cat['id'] as String),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: accent.withOpacity(0.18),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            accent.withOpacity(0.08),
                            Colors.white,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              cat['icon'] as IconData,
                              color: accent,
                              size: 24,
                            ),
                          ),
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: accent.withOpacity(0.95),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: _categorias.length,
            ),
          ),
        ),
        // Banner valor
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Material(
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _abrirBuscador(),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [_clientePrimary, _clienteDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _clientePrimary.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Prestadores con\nconfianza verificada',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Ver todos →',
                                style: TextStyle(
                                  color: _clientePrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HOME PRESTADOR
  // ─────────────────────────────────────────────
  Widget _buildPrestadorHome() {
    final confLabel = _nivelConfianza != null
        ? ScoringService.labelNivel(_nivelConfianza)
        : null;
    final score = _scoreIdentidad ?? 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildBrandHeader(
            subtitle: 'Tu perfil profesional en Puelo',
          ),
        ),
        // Value block: score + visibility
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.white,
                elevation: 6,
                shadowColor: _prestadorPrimary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: _visibilidadCargando
                      ? const SizedBox(
                          height: 72,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                // Big score
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _prestadorPrimary.withOpacity(0.15),
                                        _prestadorPrimary.withOpacity(0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$score',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: _prestadorPrimary,
                                          height: 1,
                                        ),
                                      ),
                                      Text(
                                        '/100',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _prestadorPrimary
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        confLabel ?? 'Confianza de perfil',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _estaVisible
                                                  ? const Color(0xFFD1FAE5)
                                                  : const Color(0xFFFFEDD5),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _estaVisible
                                                  ? '● Visible'
                                                  : '● Oculto',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: _estaVisible
                                                    ? const Color(0xFF047857)
                                                    : const Color(0xFFC2410C),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _estaVisible
                                            ? _resumenOficios
                                            : 'Completá oficios · zona · teléfono',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!_estaVisible) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const EspecialidadesLaboralesFlotanteWidget(),
                                      ),
                                    );
                                    await _cargarEstadoVisibilidadYConsejos();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _prestadorPrimary,
                                    side: BorderSide(
                                      color: _prestadorPrimary,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    'Completar perfil para aparecer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        // Tarjeta digital — primary CTA
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Material(
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _compartirTarjeta,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [_prestadorPrimary, _prestadorDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _prestadorPrimary.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tu tarjeta digital',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Compartila y que te contacten',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.ios_share_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Validación rápida
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SolicitarValidacionWidget(),
                    ),
                  ).then((_) => _cargarEstadoVisibilidadYConsejos());
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _prestadorPrimary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.how_to_reg_outlined,
                          color: _prestadorPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pedí que validen quién sos',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Un conocido confirma tu perfil · suma confianza',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Checklist
        if (_cargandoConsejos)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.checklist_rounded,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Checklist · subir confianza',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          if (_tipsTotales > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                '$_tipsTotales',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Al día',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_consejos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Text(
                          'Perfil sólido. Compartí tu tarjeta y pedí evaluaciones reales.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      )
                    else
                      ...List.generate(_consejos.length, (i) {
                        return Column(
                          children: [
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.grey.shade200,
                                indent: 16,
                                endIndent: 16,
                              ),
                            _ConsejoCard(
                              item: _consejos[i],
                              accent: _prestadorPrimary,
                              index: i + 1,
                            ),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 36)),
      ],
    );
  }
}

class _ConsejoCard extends StatelessWidget {
  final _ConsejoItem item;
  final Color accent;
  final int index;

  const _ConsejoCard({
    required this.item,
    required this.accent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsejoItem {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
  _ConsejoItem({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
  });
}
