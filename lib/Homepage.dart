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
  final bool? initialModoPrestador;

  const HomePageWidget({super.key, this.initialModoPrestador});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  static const Color _clientePrimary = Color(0xFF734BE4);
  static const Color _prestadorPrimary = Color(0xFF28B5CD);

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

  Color get primaryColor => _modoPrestador ? _prestadorPrimary : _clientePrimary;

  static const List<Map<String, dynamic>> _categorias = [
    {'id': 'electricidad', 'label': 'Electricista', 'icon': Icons.electrical_services_rounded, 'color': Color(0xFF734BE4)},
    {'id': 'plomeria', 'label': 'Plomer\u00eda', 'icon': Icons.plumbing_rounded, 'color': Color(0xFF7AAFFF)},
    {'id': 'gasista', 'label': 'Gasista', 'icon': Icons.local_fire_department_rounded, 'color': Color(0xFFF75A6D)},
    {'id': 'carpinteria', 'label': 'Carpinter\u00eda', 'icon': Icons.carpenter_rounded, 'color': Color(0xFF28B5CD)},
    {'id': 'pintura', 'label': 'Pintura', 'icon': Icons.format_paint_rounded, 'color': Color(0xFFF59E0B)},
    {'id': 'albanileria', 'label': 'Construcci\u00f3n', 'icon': Icons.construction_rounded, 'color': Color(0xFF3D4756)},
    {'id': 'jardineria', 'label': 'Jardiner\u00eda', 'icon': Icons.grass_rounded, 'color': Color(0xFF16A34A)},
    {'id': 'limpieza', 'label': 'Limpieza', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFF734BE4)},
  ];

  @override
  void initState() {
    super.initState();
    _detectarRol();
  }

  void _detectarRol() {
    final data = UserSession().datosCompletos;
    final esPrestador = data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
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

    // Sprint 1: cache en sesión (TTL ~45s) — evita re-fetch al volver.
    final cached = UserSession().homeCacheIfFresh;
    if (cached != null) {
      if (mounted) _aplicarEstadoDesdeData(cached);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final data = doc.data() ?? {};
      UserSession().setHomeCache(data);
      if (mounted) _aplicarEstadoDesdeData(data);
    } catch (e) {
      if (mounted) setState(() {
        _cargandoConsejos = false;
        _visibilidadCargando = false;
      });
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
    final labelsOficios = profesiones.take(3).join(' \u00b7 ');
    final visible = profesiones.isNotEmpty && localidades.isNotEmpty && telefono.isNotEmpty;

    final consejos = <_ConsejoItem>[];
    final tipsConf = ScoringService.generarConsejosConfianza(data);
    for (final t in tipsConf) {
      final id = t['id'] ?? '';
      IconData icon = Icons.trending_up_rounded;
      VoidCallback action = () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DatosPersonalesFlotanteWidget()))
            .then((_) {
          UserSession().invalidateHomeCache();
          return _cargarEstadoVisibilidadYConsejos();
        });
      };
      if (id == 'zona') {
        icon = Icons.map_outlined;
        action = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ZonaDeTrabajoFlotanteWidget()))
            .then((_) {
          UserSession().invalidateHomeCache();
          return _cargarEstadoVisibilidadYConsejos();
        });
      } else if (id == 'oficios') {
        icon = Icons.handyman_outlined;
        action = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EspecialidadesLaboralesFlotanteWidget()))
            .then((_) {
          UserSession().invalidateHomeCache();
          return _cargarEstadoVisibilidadYConsejos();
        });
      } else if (id == 'foto_perfil') {
        icon = Icons.camera_alt_outlined;
        action = () {};
      } else if (id == 'validacion_perfil') {
        icon = Icons.how_to_reg_outlined;
        action = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SolicitarValidacionWidget()))
            .then((_) {
          UserSession().invalidateHomeCache();
          return _cargarEstadoVisibilidadYConsejos();
        });
      } else if (id == 'fotos_trabajo') {
        icon = Icons.photo_library_outlined;
        action = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CargaTrabajoTrabajadorWidget()))
            .then((_) {
          UserSession().invalidateHomeCache();
          return _cargarEstadoVisibilidadYConsejos();
        });
      } else if (id == 'evals' || id == 'tiempo') {
        icon = id == 'evals' ? Icons.star_outline_rounded : Icons.schedule_rounded;
        action = _compartirTarjeta;
      } else if (id == 'domicilio') {
        icon = Icons.home_outlined;
        action = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DomicilioFlotanteWidget()))
            .then((_) {
          UserSession().invalidateHomeCache();
          return _cargarEstadoVisibilidadYConsejos();
        });
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
      _resumenOficios = labelsOficios.isEmpty ? 'Sin oficios cargados' : labelsOficios;
      _resumenZona = localidades.isEmpty ? 'Sin zona de trabajo' : '${localidades.length} zona${localidades.length == 1 ? '' : 's'}';
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
          usuarioRef: FirebaseFirestore.instance.collection('usuarios').doc(userId),
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
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    return partes[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final nombreMostrar = UserSession().nombreCompleto.isNotEmpty
        ? UserSession().nombreCompleto.split(' ').first
        : 'Usuario';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola $nombreMostrar',
              style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              _modoPrestador ? '\u00bfQu\u00e9 vas a ofrecer hoy?' : '\u00bfQu\u00e9 servicio busc\u00e1s?',
              style: TextStyle(color: primaryColor.withOpacity(0.75), fontSize: 14),
            ),
          ],
        ),
        actions: [
          if (_puedeSerAmbos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _modoPrestador = !_modoPrestador);
                  if (_modoPrestador) _cargarEstadoVisibilidadYConsejos();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_modoPrestador ? Icons.handyman_outlined : Icons.search_rounded, size: 16, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(_modoPrestador ? 'Ofrezco trabajo' : 'Busco trabajo',
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: primaryColor,
              child: Text(_getInitials(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _currentIndex == 1
          ? const MenuEvaluacionesWidget(embedded: true)
          : _currentIndex == 2
              ? MenuPerfilOpcionesWidget(
                  modoPrestador: _modoPrestador,
                  onClose: () => setState(() => _currentIndex = 0),
                )
              : (_modoPrestador ? _buildPrestadorBody() : _buildClienteBody()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Evaluar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }

  Widget _buildClienteBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _abrirBuscador(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: _clientePrimary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Buscar electricista, plomero, gasista...',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _clientePrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '\u00bfQu\u00e9 necesit\u00e1s?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.6,
            ),
            itemCount: _categorias.length,
            itemBuilder: (context, index) {
              final cat = _categorias[index];
              final Color accent = (cat['color'] as Color?) ?? _clientePrimary;
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _abrirBuscador(oficio: cat['id'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withOpacity(0.22)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(cat['icon'] as IconData, color: accent, size: 17),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent.withOpacity(0.95),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Material(
            color: _clientePrimary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _abrirBuscador(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Ver todos los prestadores',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrestadorBody() {
    final confLabel = _nivelConfianza != null ? ScoringService.labelNivel(_nivelConfianza) : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _visibilidadCargando
                ? const SizedBox(height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                : Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const EspecialidadesLaboralesFlotanteWidget()));
                        await _cargarEstadoVisibilidadYConsejos();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _estaVisible ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _estaVisible ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                                color: _estaVisible ? const Color(0xFF059669) : const Color(0xFFEA580C),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _estaVisible ? const Color(0xFFD1FAE5) : const Color(0xFFFFEDD5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _estaVisible ? 'Visible' : 'Oculto',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: _estaVisible ? const Color(0xFF047857) : const Color(0xFFC2410C),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _estaVisible ? _resumenOficios : 'Complet\u00e1 perfil para aparecer',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _estaVisible ? _resumenZona : 'Oficios \u00b7 zona \u00b7 tel\u00e9fono',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          if (confLabel != null || _scoreIdentidad != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: const Color(0xFFE6F7FA),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _prestadorPrimary.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: _prestadorPrimary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Confianza de perfil', style: TextStyle(fontSize: 12, color: _prestadorPrimary.withOpacity(0.9), fontWeight: FontWeight.w600)),
                            Text(
                              confLabel != null && _scoreIdentidad != null ? '$confLabel \u00b7 $_scoreIdentidad/100' : (confLabel ?? '$_scoreIdentidad/100'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: _prestadorPrimary,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _compartirTarjeta,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tu tarjeta digital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            SizedBox(height: 2),
                            Text('Compartila para que te contacten', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.ios_share_rounded, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_cargandoConsejos)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(
                        children: [
                          Icon(Icons.checklist_rounded, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Checklist \u00b7 subir confianza',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                            ),
                          ),
                          if (_tipsTotales > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text('$_tipsTotales', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                            ),
                        ],
                      ),
                    ),
                    if (_consejos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                        child: Text(
                          'Perfil s\u00f3lido. Compart\u00ed tu tarjeta y ped\u00ed evaluaciones reales.',
                          style: TextStyle(fontSize: 13, height: 1.35, color: Colors.grey.shade700),
                        ),
                      )
                    else
                      ...List.generate(_consejos.length, (i) {
                        return Column(
                          children: [
                            if (i > 0) Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 14, endIndent: 14),
                            _ConsejoCard(item: _consejos[i], accent: _prestadorPrimary, index: i + 1),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsejoCard extends StatelessWidget {
  final _ConsejoItem item;
  final Color accent;
  final int index;

  const _ConsejoCard({required this.item, required this.accent, required this.index});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                child: Text('$index', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.3, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade400),
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
  _ConsejoItem({required this.id, required this.title, required this.body, required this.icon, required this.onTap});
}
