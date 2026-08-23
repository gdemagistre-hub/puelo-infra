import 'package:flutter/material.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'menuPerfilOpciones.dart';
import 'tarjetaDigital.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'capacitacionesflotante.dart';
import 'mis_numeros/mis_numeros_shell.dart';
import 'academia/ui/academia_screen.dart';
import 'mensajes/mensajes_list.dart';
import 'services/fcm_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'onboarding/home_tour_service.dart';
import 'onboarding/home_tour_overlay.dart';
import 'widgets/dev_auth_banner.dart';
import 'contacto/contactos_prestador_card.dart';

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

  /// Alto del area de iconos de la barra (sin SafeArea inferior).
  static const double _navBarHeight = 64;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // 0 Home | 1 Evaluar | 2 Mis números | 3 Mensajes | 4 Academia
  int _currentIndex = 0;
  bool _modoPrestador = false;
  bool _puedeSerAmbos = false;
  bool _landingRolAplicado = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<OficioEspecialidad> _sugerencias = [];

  String? _urlFotoPerfil;
  bool _subiendoFoto = false;

  /// Tips Confianza visitados en esta sesion (UI gris).
  final Set<String> _tipsVisitadosSesion = {};

  /// Tour (showcaseview) — se dispara tras el primer frame.
  bool _tourCheckDone = false;

  void _onProfileRevision() {
    if (!mounted) return;
    setState(() {});
    if (_currentIndex == 0) {
      _refrescarDatosSesion();
    }
  }

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
    UserSession().profileRevision.addListener(_onProfileRevision);
    _detectarRol();
    var foto = (UserSession().datosCompletos?['url_foto_perfil'] ??
            UserSession().datosCompletos?['foto_perfil'] ??
            '')
        .toString()
        .trim();
    if (foto.isEmpty) {
      final authPhoto = FirebaseAuth.instance.currentUser?.photoURL?.trim() ?? '';
      if (authPhoto.isNotEmpty) foto = authPhoto;
    }
    if (foto.isNotEmpty) _urlFotoPerfil = foto;
    // FCM: registra token si hay Auth real (Google). Dev dropdown no tiene token Auth → no-op seguro.
    FcmService.instance.ensureStarted();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartHomeTour());
  }

  @override
  void dispose() {
    UserSession().profileRevision.removeListener(_onProfileRevision);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _detectarRol() {
    final session = UserSession();
    final esPrestador = session.esPrestador;
    setState(() {
      _puedeSerAmbos = esPrestador;
      if (!esPrestador) {
        _modoPrestador = false;
      } else if (!_landingRolAplicado && widget.initialModoPrestador != null) {
        _modoPrestador = widget.initialModoPrestador!;
        _landingRolAplicado = true;
      } else {
        _modoPrestador = session.preferredHomeModoPrestador;
        _landingRolAplicado = true;
      }
    });
  }

  /// Cambia de tab; al volver a Home refresca perfil (estrellas, etc.).
  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    if (index == 0) {
      _refrescarDatosSesion();
    }
  }

  Future<void> _maybeStartHomeTour() async {
    if (!mounted || _currentIndex != 0) return;
    final show = await HomeTourService.instance.shouldShow(
      modoPrestador: _modoPrestador,
    );
    if (!mounted) return;
    _tourCheckDone = true;
    if (show) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _currentIndex != 0) return;
        startHomeTourShowcase(modoPrestador: _modoPrestador);
      });
    }
  }

  Future<void> _finishHomeTour() async {
    await HomeTourService.instance.markDone(modoPrestador: _modoPrestador);
  }

  /// Desde menú · Guía rápida.
  void _requestHomeTour() {
    setState(() => _currentIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      startHomeTourShowcase(modoPrestador: _modoPrestador);
    });
  }

  void _toggleModoPrestador() {
    setState(() => _modoPrestador = !_modoPrestador);
    UserSession().persistHomeModoPrestador(_modoPrestador);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartHomeTour());
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
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasFoto
          ? Image.network(
              _urlFotoPerfil!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Text(
                _getInitials(),
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Text(
                  _getInitials(),
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                );
              },
            )
          : Text(
              _getInitials(),
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
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
        return MisNumerosShell(onBackToHome: () => _selectTab(0));
      case 3:
        return const MensajesListScreen(embedded: true);
      case 4:
        return const AcademiaScreen(embedded: true);
      default:
        return _modoPrestador ? _buildPrestadorHome() : _buildClienteHome();
    }
  }

  /// Contenido con slide desde abajo (detras de la barra flotante).
  Widget _buildAnimatedTabBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>('tab_$_currentIndex${_modoPrestador ? '_p' : '_c'}'),
        child: _tabBody,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onHome = _currentIndex == 0;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    // Espacio para que el contenido no quede bajo la barra (64 + safe + margen boton central).
    final contentBottomPad = _navBarHeight + bottomSafe + 12;

    return ShowCaseWidget(
      onFinish: () {
        _finishHomeTour();
      },
      builder: (context) => Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: Drawer(
        backgroundColor: const Color(0xFFF1F5F9),
        child: SafeArea(
          child: MenuPerfilOpcionesWidget(
            modoPrestador: _modoPrestador,
            onClose: () => Navigator.of(context).pop(),
            onRolPuedeHaberCambiado: _detectarRol,
            onRequestHomeTour: _requestHomeTour,
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
      // Enfoque B: contenido a pantalla completa; barra flotante encima.
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DevAuthBanner(),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: contentBottomPad),
              child: _buildAnimatedTabBody(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: _navBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _navItem(0, Icons.home_rounded, 'Home'),
                  _navItem(1, Icons.star_outline_rounded, 'Evaluar'),
                  _centerMisNumerosButton(),
                  _mensajesNavItem(),
                  _navAcademiaShowcase(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerMisNumerosButton() {
    final selected = _currentIndex == 2;
    return homeShowcase(
      key: HomeTourKeys.navMisNumeros,
      modoPrestador: _modoPrestador,
      accent: primaryColor,
      tooltipPosition: TooltipPosition.top,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      child: GestureDetector(
        onTap: () => _selectTab(2),
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
    ),
    );
  }

  /// Badge de recibos pendientes de responder (no los que yo emití).
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
              final hasRecibo = d['pending_recibo_event_id'] != null;
              final hasCalif = d['pending_calificacion_event_id'] != null;
              if (!hasRecibo && !hasCalif) continue;
              if (hasRecibo) {
                final actor = (d['pending_recibo_actor_uid'] ?? '').toString();
                if (actor.isEmpty || actor != uid) pending++;
              }
              if (hasCalif) {
                final actor = (d['pending_calificacion_actor_uid'] ?? '').toString();
                if (actor.isEmpty || actor != uid) pending++;
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

Widget _navAcademiaShowcase() {
    return homeShowcase(
      key: HomeTourKeys.navAcademia,
      modoPrestador: _modoPrestador,
      accent: primaryColor,
      tooltipPosition: TooltipPosition.top,
      child: _navItem(4, Icons.school_outlined, 'Academia'),
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
      onTap: onTap ?? () => _selectTab(index),
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

  Widget _buildBrandHeader({required String subtitle}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor, primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 40),
          child: Row(
            children: [
              homeShowcase(
                key: HomeTourKeys.menu,
                modoPrestador: _modoPrestador,
                accent: primaryColor,
                child: IconButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                  tooltip: 'Menú',
                ),
              ),
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
                homeShowcase(
                  key: HomeTourKeys.roleToggle,
                  modoPrestador: _modoPrestador,
                  accent: primaryColor,
                  child: GestureDetector(
                    onTap: _toggleModoPrestador,
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
          child: homeShowcase(
            key: HomeTourKeys.searchOrConfianza,
            modoPrestador: false,
            accent: _clientePrimary,
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
          child: homeShowcase(
            key: HomeTourKeys.primaryBlock,
            modoPrestador: false,
            accent: _clientePrimary,
            tooltipPosition: TooltipPosition.top,
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
        ),
      ],
    );
  }

  Map<String, dynamic> get _dp => Map<String, dynamic>.from(UserSession().datosCompletos ?? {});

  bool _noVacio(dynamic v) {
    if (v == null) return false;
    return v.toString().trim().isNotEmpty;
  }

  Future<void> _abrirFlotante(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _refrescarDatosSesion();
  }

  Future<void> _refrescarDatosSesion() async {
    final uid = UserSession().uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!doc.exists || !mounted) return;
      final data = doc.data() ?? {};
      final session = UserSession();
      session.datosCompletos = {...?session.datosCompletos, ...data};
      final foto = (data['url_foto_perfil'] ?? data['foto_perfil'] ?? '').toString().trim();
      if (foto.isNotEmpty) _urlFotoPerfil = foto;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _ejecutarTip(_RecoItem r) async {
    setState(() => _tipsVisitadosSesion.add(r.id));
    await r.onTap();
    if (mounted) await _refrescarDatosSesion();
  }

  List<_RecoItem> _recomendacionesPrestador(Map<String, dynamic> data) {
    final out = <_RecoItem>[];
    void add(_RecoItem r) {
      if (out.length < 5) out.add(r);
    }

    final geo = data['direccion_geo'] is Map
        ? Map<String, dynamic>.from(data['direccion_geo'] as Map)
        : <String, dynamic>{};
    final profesiones = data['profesiones'] as List? ?? [];
    final zonas = data['zonas_cobertura'] is Map
        ? Map<String, dynamic>.from(data['zonas_cobertura'] as Map)
        : <String, dynamic>{};
    final locs = zonas['localidades'] as List? ?? [];
    final vals = data['validaciones_recibidas'] as List? ?? [];
    final fotoPerfil = _noVacio(data['url_foto_perfil'] ?? data['foto_perfil']);
    final docValidado = data['doc_validado'] == true;
    final tieneTel = _noVacio(data['telefono']);
    final tieneEmail = _noVacio(data['email']);
    final tieneLocalidad = _noVacio(geo['localidad_id'] ?? geo['localidad_nombre']);
    final tieneCalle = _noVacio(data['calle']);
    final tieneDoc = _noVacio(data['doc_numero'] ?? data['numero_documento'] ?? data['documento']);

    if (!fotoPerfil) {
      add(_RecoItem(
        id: 'foto_perfil',
        title: 'Sumá una foto de perfil',
        subtitle: 'Selfie clara · suma fuerte a tu Confianza',
        icon: Icons.photo_camera_rounded,
        onTap: () async { _mostrarOpcionesSelfie(); },
      ));
    }
    if (!docValidado) {
      add(_RecoItem(
        id: 'ocr',
        title: 'Validá tu documento con la cámara',
        subtitle: 'El mayor salto de Confianza · DNI escaneado',
        icon: Icons.badge_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    } else if (!_noVacio(data['url_foto_documento'])) {
      add(_RecoItem(
        id: 'foto_doc',
        title: 'Adjuntá la foto de tu documento',
        subtitle: 'Refuerza que el documento es real',
        icon: Icons.image_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (!tieneTel) {
      add(_RecoItem(
        id: 'tel',
        title: 'Cargá tu celular',
        subtitle: 'Para que te contacten por WhatsApp o llamada',
        icon: Icons.phone_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (!tieneLocalidad || !tieneCalle) {
      add(_RecoItem(
        id: 'domicilio',
        title: 'Completá tu domicilio',
        subtitle: 'Provincia, partido y localidad · suma Confianza',
        icon: Icons.home_outlined,
        onTap: () => _abrirFlotante(DomicilioFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (vals.isEmpty) {
      add(_RecoItem(
        id: 'validacion',
        title: 'Pedí que validen quién sos',
        subtitle: 'Un conocido confirma tu perfil · reputación real',
        icon: Icons.how_to_reg_outlined,
        onTap: () => _abrirFlotante(const SolicitarValidacionWidget()),
      ));
    }
    if (!tieneEmail) {
      add(_RecoItem(
        id: 'email',
        title: 'Cargá tu email en el perfil',
        subtitle: 'Suma a tu Confianza y facilita el contacto',
        icon: Icons.email_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (!tieneDoc) {
      add(_RecoItem(
        id: 'doc_numero',
        title: 'Cargá tipo y número de documento',
        subtitle: 'No se muestra al cliente · valida tu identidad',
        icon: Icons.credit_card_outlined,
        onTap: () => _abrirFlotante(DatosPersonalesFlotanteWidget(modoPrestador: true)),
      ));
    }
    if (profesiones.isEmpty) {
      add(_RecoItem(
        id: 'oficios',
        title: 'Indicá los servicios que ofrecés',
        subtitle: 'Así aparecés cuando buscan tu rubro',
        icon: Icons.handyman_outlined,
        onTap: () => _abrirFlotante(const EspecialidadesLaboralesFlotanteWidget()),
      ));
    }
    if (locs.isEmpty) {
      add(_RecoItem(
        id: 'zona',
        title: 'Definí tu zona de trabajo',
        subtitle: 'Para que te encuentren en tu área',
        icon: Icons.map_outlined,
        onTap: () => _abrirFlotante(const ZonaDeTrabajoFlotanteWidget()),
      ));
    }
    if (out.length < 5) {
      add(_RecoItem(
        id: 'fotos_trabajo',
        title: 'Subí fotos de trabajos hechos',
        subtitle: 'Se ven en tu tarjeta digital',
        icon: Icons.photo_library_outlined,
        onTap: () => _abrirFlotante(const CargaTrabajoTrabajadorWidget()),
      ));
    }
    final caps = data['capacitaciones'] as List? ?? [];
    if (caps.isEmpty && out.length < 5) {
      add(_RecoItem(
        id: 'capacitaciones',
        title: 'Sumá un curso o capacitación',
        subtitle: 'Opcional · da solidez a tu perfil',
        icon: Icons.school_outlined,
        onTap: () => _abrirFlotante(const CapacitacionesFlotanteWidget()),
      ));
    }

    return out;
  }

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
    final scoreClamped = score.clamp(0, 100);
    final scoreProgress = scoreClamped / 100.0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildBrandHeader(subtitle: 'Así te ven quienes buscan trabajo'),
        homeShowcase(
          key: HomeTourKeys.searchOrConfianza,
          modoPrestador: true,
          accent: _prestadorPrimary,
          child: Transform.translate(
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
                  gradient: LinearGradient(
                    colors: [Colors.white, _prestadorPrimary.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: _prestadorPrimary.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Así te ven los clientes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
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
                    if (ScoringService.explicacionBadge(badge.isEmpty ? null : badge)
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ScoringService.explicacionBadge(badge.isEmpty ? null : badge),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nEval > 0 ? '${stars.toStringAsFixed(1)} ($nEval)' : '—',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                      Text(
                                        nEval > 0 ? 'Calificación' : 'Sin evaluaciones',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: CircularProgressIndicator(
                                          value: score > 0 ? scoreProgress : 0,
                                          strokeWidth: 5,
                                          backgroundColor: const Color(0xFFE2E8F0),
                                          color: const Color(0xFF16A34A),
                                          strokeCap: StrokeCap.round,
                                        ),
                                      ),
                                      Text(
                                        score > 0 ? '$scoreClamped' : '—',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        score > 0 ? '$scoreClamped / 100' : '—',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'Confianza',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: homeShowcase(
            key: HomeTourKeys.primaryBlock,
            modoPrestador: true,
            accent: _prestadorPrimary,
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
                          Text(
                            'Tu tarjeta digital',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Compartila y que te contacten',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
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
        ),
        ContactosPrestadorCard(
          onIrMensajes: () => _selectTab(3),
        ),
        Builder(
          builder: (context) {
            final recos = _recomendacionesPrestador(_dp);
            if (recos.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Material(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _compartirTarjeta,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Perfil listo para que te encuentren',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF14532D),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Compartí tu tarjeta por WhatsApp',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.ios_share_rounded, color: Color(0xFF16A34A)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            final pendientes = recos
                .where((r) => !_tipsVisitadosSesion.contains(r.id))
                .toList();
            final primero = pendientes.isNotEmpty ? pendientes.first : recos.first;
            final resto = recos.where((r) => r.id != primero.id).toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para subir tu Confianza',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pendientes.length <= 1
                        ? 'Este es el paso que más te conviene ahora'
                        : 'Empezá por el primero · te faltan ${pendientes.length} pasos',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  _tipTile(primero, destacado: true),
                  if (resto.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < resto.length; i++)
                            _tipTile(
                              resto[i],
                              destacado: false,
                              numero: i + 2,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
  Widget _tipTile(_RecoItem r, {required bool destacado, int? numero}) {
    final visitado = _tipsVisitadosSesion.contains(r.id);
    final border = destacado && !visitado
        ? Border.all(color: _prestadorPrimary, width: 1.6)
        : null;
    return Padding(
      padding: EdgeInsets.only(bottom: destacado ? 0 : 6),
      child: Opacity(
        opacity: visitado ? 0.55 : 1,
        child: Material(
          color: visitado
              ? const Color(0xFFF1F5F9)
              : (destacado ? Colors.white : Colors.transparent),
          elevation: destacado && !visitado ? 2 : 0,
          shadowColor: _prestadorPrimary.withOpacity(0.25),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _ejecutarTip(r),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: destacado
                          ? _prestadorPrimary.withOpacity(0.16)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: visitado
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF16A34A), size: 22)
                        : (numero != null
                            ? Text(
                                '$numero',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            : Icon(r.icon, color: _prestadorPrimary, size: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (destacado && !visitado)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              'SIGUIENTE PASO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: Color(0xFF1A8FA3),
                              ),
                            ),
                          ),
                        Text(
                          r.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: destacado ? 15 : 14,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    visitado
                        ? Icons.check_circle_outline_rounded
                        : Icons.chevron_right_rounded,
                    color: visitado
                        ? const Color(0xFF94A3B8)
                        : (destacado
                            ? _prestadorPrimary
                            : Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

class _RecoItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() onTap;
  const _RecoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}
