import 'package:flutter/material.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'menuPerfilOpciones.dart';
import 'tarjetaDigital.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'platform_capabilities.dart';
import 'catalogo_oficios.dart';
import 'scoring_service.dart';

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
  static const Color _clienteDark = Color(0xFF5B35C5);
  static const Color _prestadorPrimary = Color(0xFF28B5CD);
  static const Color _prestadorDark = Color(0xFF1A8FA3);

  int _currentIndex = 0;
  bool _modoPrestador = false;
  bool _puedeSerAmbos = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<OficioEspecialidad> _sugerencias = [];

  String? _urlFotoPerfil;
  bool _subiendoFoto = false;

  Color get primaryColor => _modoPrestador ? _prestadorPrimary : _clientePrimary;
  Color get primaryDark => _modoPrestador ? _prestadorDark : _clienteDark;

  static const List<Map<String, dynamic>> _categorias = [
    {'id': 'electricidad', 'label': 'Electricista', 'icon': Icons.electrical_services_rounded, 'color': Color(0xFF734BE4)},
    {'id': 'plomeria', 'label': 'Plomería', 'icon': Icons.plumbing_rounded, 'color': Color(0xFF4A90E2)},
    {'id': 'gasista', 'label': 'Gasista', 'icon': Icons.local_fire_department_rounded, 'color': Color(0xFFF75A6D)},
    {'id': 'carpinteria', 'label': 'Carpintería', 'icon': Icons.carpenter_rounded, 'color': Color(0xFF28B5CD)},
    {'id': 'pintura', 'label': 'Pintura', 'icon': Icons.format_paint_rounded, 'color': Color(0xFFF59E0B)},
    {'id': 'albanileria', 'label': 'Construcción', 'icon': Icons.construction_rounded, 'color': Color(0xFF3D4756)},
    {'id': 'jardineria', 'label': 'Jardinería', 'icon': Icons.grass_rounded, 'color': Color(0xFF16A34A)},
    {'id': 'limpieza', 'label': 'Limpieza', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _detectarRol();
    final foto = (UserSession().datosCompletos?['url_foto_perfil'] ?? UserSession().datosCompletos?['foto_perfil'] ?? '').toString().trim();
    if (foto.isNotEmpty) _urlFotoPerfil = foto;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _detectarRol() {
    final data = UserSession().datosCompletos;
    final esPrestador = data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
    setState(() {
      _puedeSerAmbos = esPrestador;
      _modoPrestador = widget.initialModoPrestador ?? esPrestador;
    });
  }

  String _getInitials() {
    final n = UserSession().nombreCompleto.trim();
    if (n.isEmpty) return 'U';
    final p = n.split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p[0][0].toUpperCase();
  }

  String get _nombreMostrar {
    final n = UserSession().nombreCompleto.trim();
    if (n.isEmpty) return 'Usuario';
    return n.split(' ').first;
  }

  void _abrirBuscador({String? oficio}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BuscadorPrestadoresWidget(initialQuery: oficio)));
  }

  void _onSearchChanged(String value) {
    setState(() => _sugerencias = CatalogoOficios.sugerencias(value, limit: 8));
  }

  void _submitBusqueda([String? raw]) {
    final q = (raw ?? _searchCtrl.text).trim();
    _searchFocus.unfocus();
    setState(() => _sugerencias = []);
    if (q.isEmpty) {
      _abrirBuscador();
      return;
    }
    _abrirBuscador(oficio: q);
  }

  void _elegirSugerencia(OficioEspecialidad e) {
    _searchCtrl.text = e.label;
    _submitBusqueda(e.id);
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

  void _mostrarOpcionesSelfie() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Foto de perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (PlatformCapabilities.supportsCamera)
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: primaryColor),
                  title: const Text('Tomar selfie'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _elegirYSubirFoto(ImageSource.camera);
                  },
                ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: primaryColor),
                title: const Text('Elegir de galería'),
                onTap: () {
                  Navigator.pop(ctx);
                  _elegirYSubirFoto(ImageSource.gallery);
                },
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ahora no')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _elegirYSubirFoto(ImageSource source) async {
    final uid = UserSession().uid;
    if (uid == null) return;
    if (source == ImageSource.camera && !PlatformCapabilities.supportsCamera) return;
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85, preferredCameraDevice: CameraDevice.front);
      if (file == null) return;
      if (!mounted) return;
      setState(() => _subiendoFoto = true);
      final bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child('usuarios').child(uid).child('foto_perfil.jpg');
      final upload = await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'image/jpeg'));
      final url = await upload.ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({'url_foto_perfil': url, 'foto_perfil': url, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      final session = UserSession();
      if (session.datosCompletos != null) {
        session.datosCompletos = {...session.datosCompletos!, 'url_foto_perfil': url, 'foto_perfil': url};
      }
      if (!mounted) return;
      setState(() {
        _urlFotoPerfil = url;
        _subiendoFoto = false;
      });
    } catch (e) {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Widget _buildAvatarHeader() {
    final hasFoto = _urlFotoPerfil != null && _urlFotoPerfil!.isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        image: hasFoto ? DecorationImage(image: NetworkImage(_urlFotoPerfil!), fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: hasFoto ? null : Text(_getInitials(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onHome = _currentIndex == 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: onHome
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Text(_currentIndex == 1 ? 'Evaluar' : 'Perfil', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800)),
            ),
      body: _currentIndex == 1
          ? const MenuEvaluacionesWidget(embedded: true)
          : _currentIndex == 2
              ? MenuPerfilOpcionesWidget(modoPrestador: _modoPrestador, onClose: () => setState(() => _currentIndex = 0))
              : (_modoPrestador ? _buildPrestadorHome() : _buildClienteHome()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            _navItem(0, Icons.home_rounded, 'Home'),
            _navItem(1, Icons.star_outline_rounded, 'Evaluar'),
            _navItem(2, Icons.person_rounded, 'Perfil'),
          ]),
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
          decoration: BoxDecoration(color: selected ? primaryColor.withOpacity(0.14) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: selected ? 26 : 24, color: selected ? primaryColor : const Color(0xFF94A3B8)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? primaryColor : const Color(0xFF94A3B8))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader({required String subtitle}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor, primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 40),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hola, $_nombreMostrar', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.15)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.90), fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (_puedeSerAmbos) ...[
                GestureDetector(
                  onTap: () => setState(() => _modoPrestador = !_modoPrestador),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.35))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_modoPrestador ? Icons.handyman_rounded : Icons.search_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_modoPrestador ? 'Ofrezco' : 'Busco', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: _subiendoFoto ? null : _mostrarOpcionesSelfie,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildAvatarHeader(),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.photo_camera_rounded, size: 11, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClienteHome() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildBrandHeader(subtitle: '¿Qué servicio necesitás hoy?'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Material(
            color: Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _submitBusqueda,
              decoration: InputDecoration(
                hintText: '¿Qué servicio necesitás?',
                prefixIcon: Icon(Icons.search_rounded, color: _clientePrimary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        if (_sugerencias.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: _sugerencias
                    .map((e) => ListTile(
                          dense: true,
                          title: Text(e.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () => _elegirSugerencia(e),
                        ))
                    .toList(),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text('Oficios', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categorias.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final cat = _categorias[index];
              final Color accent = (cat['color'] as Color?) ?? _clientePrimary;
              return InkWell(
                onTap: () => _abrirBuscador(oficio: cat['id'] as String),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
                      ),
                      child: Icon(cat['icon'] as IconData, color: accent, size: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(cat['label'] as String, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Material(
            borderRadius: BorderRadius.circular(20),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _abrirBuscador(),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: [_clientePrimary, _clienteDark]),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prestadores con más confianza', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          SizedBox(height: 6),
                          Text('Ordenados por zona y calificación', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.verified_user_rounded, color: Colors.white, size: 34),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> get _dp => Map<String, dynamic>.from(UserSession().datosCompletos ?? {});

  Widget _buildPrestadorHome() {
    final badge = (_dp['list_badge'] ?? _dp['badge_prestador'] ?? '').toString().trim();
    final label = ScoringService.labelBadge(badge.isEmpty ? null : badge);
    final colors = ScoringService.coloresBadge(badge.isEmpty ? null : badge);
    final starsRaw = _dp['list_promedio'] ?? _dp['promedioEstrellas'] ?? 0;
    final stars = starsRaw is num ? starsRaw.toDouble() : (double.tryParse('$starsRaw') ?? 0);
    final nRaw = _dp['list_n_evaluaciones'] ?? _dp['nEvaluaciones'] ?? _dp['cantidad_evaluaciones'] ?? 0;
    final nEval = nRaw is num ? nRaw.toInt() : (int.tryParse('$nRaw') ?? 0);
    final scoreRaw = _dp['list_score_identidad'];
    int score = 0;
    if (scoreRaw is num) {
      score = scoreRaw.toInt();
    } else {
      final sc = _dp['scoring'];
      if (sc is Map && sc['score_identidad'] is num) score = (sc['score_identidad'] as num).toInt();
    }
    String motiv;
    if (nEval > 0 && stars > 0) {
      motiv = 'Los clientes ya confían en vos · seguí sumando trabajos';
    } else if ({'bronce', 'bronce_plus', 'plata', 'oro', 'diamante', 'registrado'}.contains(badge)) {
      motiv = 'Vas bien · compartí tu tarjeta para que te contacten';
    } else {
      motiv = 'Completá tu perfil y pedí una validación para subir tu confianza';
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildBrandHeader(subtitle: 'Tu perfil profesional en Puelo'),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              borderRadius: BorderRadius.circular(22),
              elevation: 8,
              shadowColor: _prestadorPrimary.withOpacity(0.35),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(colors: [Colors.white, _prestadorPrimary.withOpacity(0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: _prestadorPrimary.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tu confianza', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Text(
                      label.isNotEmpty ? label : 'Sin nivel aún',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: label.isNotEmpty ? Color(colors.foreground) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                            child: Row(
                              children: [
                                Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(nEval > 0 ? '${stars.toStringAsFixed(1)} ($nEval)' : '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                      Text(nEval > 0 ? 'Calificación' : 'Sin evaluaciones', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                            child: Row(
                              children: [
                                Icon(Icons.verified_user_outlined, color: _prestadorPrimary, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(score > 0 ? '$score' : '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                      Text(score > 0 ? 'Confianza' : 'Sin score', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (nEval == 0) ...[
                      const SizedBox(height: 12),
                      Text('Todavía no tenés evaluaciones · pedí que te califiquen tras un trabajo', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: _prestadorPrimary.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                      child: Text(motiv, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _prestadorDark)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Material(
            borderRadius: BorderRadius.circular(18),
            elevation: 3,
            child: InkWell(
              onTap: _compartirTarjeta,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [_prestadorPrimary, _prestadorDark]),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tu tarjeta digital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                          SizedBox(height: 2),
                          Text('Compartila y que te contacten', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}
