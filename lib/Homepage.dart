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
import 'datosPersonalesflotante.dart';
import 'Domicilioflotante.dart';
import 'solicitar_validacion.dart';
import 'especialidadesLaboralesflotante.dart';
import 'ZonaDeTrabajoflotante.dart';
import 'cargaTrabajoTrabajador.dart';
import 'mis_numeros/mis_numeros_shell.dart';
import 'academia/ui/academia_screen.dart';
import 'mensajes/mensajes_list.dart';
import 'services/fcm_service.dart';

part 'homepage_bodies.dart';

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
  static const Color _misNumerosPrimary = Color(0xFF28B5CD);
  static const Color _misNumerosDark = Color(0xFF1F9BB0);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // 0 Home | 1 Evaluar | 2 Mis números | 3 Mensajes | 4 Academia
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
    FcmService.instance.ensureStarted();
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

  String get _appBarTitle {
    switch (_currentIndex) {
      case 1:
        return 'Evaluar';
      case 2:
        return 'Mis números';
      case 3:
        return 'Mensajes';
      case 4:
        return 'Academia';
      default:
        return '';
    }
  }

  Widget get _tabBody {
    switch (_currentIndex) {
      case 1:
        return const MenuEvaluacionesWidget(embedded: true);
      case 2:
        return MisNumerosShell(onBackToHome: () => setState(() => _currentIndex = 0));
      case 3:
        return const MensajesListScreen(embedded: true);
      case 4:
        return const AcademiaScreen(embedded: true);
      default:
        return _modoPrestador ? _buildPrestadorHome() : _buildClienteHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onHome = _currentIndex == 0;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: Drawer(
        backgroundColor: const Color(0xFFF1F5F9),
        child: SafeArea(
          child: MenuPerfilOpcionesWidget(
            modoPrestador: _modoPrestador,
            onClose: () => Navigator.of(context).pop(),
            onRolPuedeHaberCambiado: _detectarRol,
          ),
        ),
      ),
      appBar: onHome
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.menu_rounded, color: primaryColor),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(
                _appBarTitle,
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800),
              ),
            ),
      body: _tabBody,
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
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _navItem(0, Icons.home_rounded, 'Home'),
                _navItem(1, Icons.star_outline_rounded, 'Evaluar'),
                _centerMisNumerosButton(),
                _mensajesNavItem(),
                _navItem(4, Icons.school_outlined, 'Academia'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerMisNumerosButton() {
    final selected = _currentIndex == 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: selected
                      ? [_misNumerosPrimary, _misNumerosDark]
                      : [_misNumerosPrimary, _misNumerosPrimary.withOpacity(0.88)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _misNumerosPrimary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Mis números',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: selected ? _misNumerosPrimary : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Badge de recibos pendientes de *responder* (no los que yo emití).
  Widget _mensajesNavItem() {
    final uid = UserSession().uid;
    if (uid == null || uid.isEmpty) {
      return _navItem(3, Icons.chat_bubble_outline_rounded, 'Mensajes');
    }
    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('conversaciones')
            .where('participantes', arrayContains: uid)
            .orderBy('last_event_at', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          int pending = 0;
          if (snap.hasData) {
            for (final doc in snap.data!.docs) {
              final d = doc.data();
              final pendingId = d['pending_recibo_event_id'];
              if (pendingId == null) continue;
              final actor = (d['pending_recibo_actor_uid'] ?? '').toString();
              if (actor.isEmpty || actor != uid) {
                pending++;
              }
            }
          }
          return _navItemContent(
            3,
            Icons.chat_bubble_outline_rounded,
            'Mensajes',
            badgeCount: pending,
          );
        },
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, {VoidCallback? onTap, int badgeCount = 0}) {
    return Expanded(
      child: _navItemContent(index, icon, label, onTap: onTap, badgeCount: badgeCount),
    );
  }

  Widget _navItemContent(int index, IconData icon, String label, {VoidCallback? onTap, int badgeCount = 0}) {
    final selected = _currentIndex == index;
    final showBadge = badgeCount > 0;
    final badgeText = badgeCount > 9 ? '9+' : '$badgeCount';
    return InkWell(
      onTap: onTap ?? () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: selected ? 24 : 22,
                  color: selected ? primaryColor : const Color(0xFF94A3B8),
                ),
                if (showBadge)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withOpacity(0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? primaryColor : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

