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
import 'config/app_env.dart';
import 'theme/app_copy.dart';
import 'analytics/prox_analytics.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  static const Color _clientePrimary = Color(0xFF734BE4);
  static const Color _prestadorPrimary = Color(0xFF28B5CD);
  static const Color _accentCoral = Color(0xFFF75A6D);
  static const Color _accentLightBlue = Color(0xFF7AAFFF);
  static const Color _dark = Color(0xFF3D4756);

  final TextEditingController _searchController = TextEditingController();

  int _currentIndex = 0;
  bool _modoPrestador = false;
  bool _puedeSerAmbos = false;

  List<_ServicioItem> _topServicios = [];
  bool _cargandoServicios = true;
  List<_ConsejoItem> _consejos = [];
  bool _cargandoConsejos = true;
  bool _corriendoBatch = false;
  bool _visibilidadCargando = true;
  bool _estaVisible = false;
  String _resumenOficios = '';
  String _resumenZona = '';
  String? _nivelConfianza;
  int? _scoreIdentidad;
  int _tipsTotales = 0;
  final Set<String> _tipsLeidos = {};
  int _pasosCompletos = 0;
  static const int _pasosTotales = 4;
  bool _bannerZonaDescartado = false;
  bool _bannerZonaTracked = false;
  String? _urlFotoPerfil;
  bool _subiendoFoto = false;

  Color get primaryColor =>
      _modoPrestador ? _prestadorPrimary : _clientePrimary;

  static const Map<String, _ServicioMeta> _metaServicios = {
    'electricidad': _ServicioMeta('Electricista', Icons.electrical_services_outlined),
    'plomeria': _ServicioMeta('Plomería', Icons.plumbing),
    'gasista': _ServicioMeta('Gasista', Icons.local_fire_department_outlined),
    'carpinteria': _ServicioMeta('Carpintería', Icons.handyman_outlined),
    'pintura': _ServicioMeta('Pintura', Icons.format_paint_outlined),
    'albanileria': _ServicioMeta('Construcción', Icons.construction_outlined),
    'jardineria': _ServicioMeta('Jardinería', Icons.yard_outlined),
    'limpieza': _ServicioMeta('Limpieza', Icons.cleaning_services_outlined),
  };

  static const List<String> _fallbackOrden = [
    'electricidad', 'carpinteria', 'plomeria', 'jardineria',
    'limpieza', 'pintura', 'gasista', 'albanileria',
  ];

  @override
  void initState() {
    super.initState();
    _detectarRol();
    _cargarTopServicios();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _faltaZonaCliente() {
    final data = UserSession().datosCompletos;
    if (data == null) return true;
    final geo = data['direccion_geo'];
    if (geo is! Map) return true;
    final loc = (geo['localidad_id'] ?? geo['localidad_nombre'] ?? '').toString().trim();
    final part = (geo['partido_id'] ?? geo['partido_nombre'] ?? '').toString().trim();
    final prov = (geo['provincia_id'] ?? geo['provincia_nombre'] ?? '').toString().trim();
    if (loc.isNotEmpty) return false;
    if (prov.isNotEmpty && part.isNotEmpty) return false;
    return true;
  }

  bool get _mostrarBannerZonaCliente =>
      !_modoPrestador && !_bannerZonaDescartado && _faltaZonaCliente();

  void _detectarRol() {
    final data = UserSession().datosCompletos;
    final esPrestador =
        data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
    final foto = (data?['url_foto_perfil'] ?? '').toString().trim();
    setState(() {
      _puedeSerAmbos = esPrestador;
      _modoPrestador = esPrestador;
      _urlFotoPerfil = foto.isEmpty ? null : foto;
    });
    if (esPrestador) {
      _cargarEstadoVisibilidadYConsejos();
    } else {
      setState(() {
        _cargandoConsejos = false;
        _visibilidadCargando = false;
        _consejos = [];
      });
    }
  }

  Future<void> _refrescarSesionDesdeFirestore() async {
    final uid = UserSession().uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        UserSession().iniciarSesion(uid, doc.data()!);
        final foto = (doc.data()!['url_foto_perfil'] ?? '').toString().trim();
        if (mounted) {
          setState(() => _urlFotoPerfil = foto.isEmpty ? null : foto);
        }
      }
    } catch (e) {
      debugPrint('Error refrescando sesión: $e');
    }
  }

  Future<void> _refrescarRolDesdeFirestore() async {
    final uid = UserSession().uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      UserSession().iniciarSesion(uid, data);
      final esPrestador =
          data['es_trabajador'] == true || data['rol'] == 'trabajador';
      final foto = (data['url_foto_perfil'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _puedeSerAmbos = esPrestador;
        _urlFotoPerfil = foto.isEmpty ? null : foto;
        if (esPrestador) {
          _modoPrestador = true;
          _currentIndex = 0;
        }
      });
      if (esPrestador) await _cargarEstadoVisibilidadYConsejos();
    } catch (e) {
      debugPrint('Error refrescando rol: $e');
    }
  }

  Future<void> _irAOfrecerServicios() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegistroTrabajadorWidget()),
    );
    await _refrescarRolDesdeFirestore();
  }

  Future<void> _abrirDomicilioDesdeBanner() async {
    ProxAnalytics.instance.action('banner_zona_cta', screen: '/home');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DomicilioFlotanteWidget()),
    );
    await _refrescarSesionDesdeFirestore();
  }

  void _descartarBannerZona() {
    ProxAnalytics.instance.action('banner_zona_dismiss', screen: '/home');
    setState(() => _bannerZonaDescartado = true);
  }

  Future<void> _cargarTopServicios() async {
    setState(() => _cargandoServicios = true);
    try {
      final statsDoc = await FirebaseFirestore.instance
          .collection('stats')
          .doc('top_servicios')
          .get();
      List<String> ranking = [];
      if (statsDoc.exists) {
        ranking = (statsDoc.data()!['ranking'] as List<dynamic>? ?? [])
            .map((e) => e.toString().toLowerCase().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      _aplicarRanking(ranking.isNotEmpty ? ranking : _fallbackOrden);
    } catch (e) {
      debugPrint('Error cargando top servicios: $e');
      _aplicarRanking(_fallbackOrden);
    }
  }

  void _aplicarRanking(List<String> claves) {
    final items = <_ServicioItem>[];
    final vistos = <String>{};
    for (final clave in claves) {
      if (vistos.contains(clave)) continue;
      final meta = _metaServicios[clave];
      if (meta == null) continue;
      vistos.add(clave);
      items.add(_ServicioItem(clave: clave, label: meta.label, icon: meta.icon));
      if (items.length >= 8) break;
    }
    for (final clave in _fallbackOrden) {
      if (items.length >= 8) break;
      if (vistos.contains(clave)) continue;
      final meta = _metaServicios[clave];
      if (meta == null) continue;
      vistos.add(clave);
      items.add(_ServicioItem(clave: clave, label: meta.label, icon: meta.icon));
    }
    if (mounted) {
      setState(() {
        _topServicios = items;
        _cargandoServicios = false;
      });
    }
  }

  Future<void> _cargarEstadoVisibilidadYConsejos() async {
    setState(() {
      _cargandoConsejos = true;
      _visibilidadCargando = true;
    });
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() {
        _consejos = [];
        _cargandoConsejos = false;
        _visibilidadCargando = false;
        _estaVisible = false;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final data = doc.data() ?? {};
      final profesiones = (data['profesiones'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final zonas = data['zonas_cobertura'] as Map<String, dynamic>?;
      final localidades = zonas?['localidades'] as List<dynamic>? ?? [];
      final telefono = (data['telefono'] ?? '').toString().trim();
      final nombre = (data['nombre'] ?? '').toString().trim();
      final apellido = (data['apellido'] ?? '').toString().trim();
      final labelsOficios = profesiones
          .map((k) => _metaServicios[k]?.label ?? k)
          .take(3)
          .join(' · ');
      int pasos = 0;
      if (profesiones.isNotEmpty) pasos++;
      if (localidades.isNotEmpty) pasos++;
      if (telefono.isNotEmpty) pasos++;
      if (nombre.isNotEmpty && apellido.isNotEmpty) pasos++;
      final visible =
          profesiones.isNotEmpty && localidades.isNotEmpty && telefono.isNotEmpty;
      final consejos = <_ConsejoItem>[];

      // Confianza de perfil: checklist accionable (scoring v1)
      final leidosRaw = data['tips_confianza_leidos'];
      if (leidosRaw is List) {
        _tipsLeidos
          ..clear()
          ..addAll(leidosRaw.map((e) => e.toString()));
      }

      final tipsConf = ScoringService.generarConsejosConfianza(data);
      for (final t in tipsConf) {
        final id = t['id'] ?? '';
        IconData icon = Icons.trending_up_rounded;
        VoidCallback action = () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DatosPersonalesFlotanteWidget()),
          ).then((_) => _cargarEstadoVisibilidadYConsejos());
        };
        if (id == 'zona') {
          icon = Icons.map_outlined;
          action = () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ZonaDeTrabajoFlotanteWidget()),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
          };
        } else if (id == 'oficios') {
          icon = Icons.handyman_outlined;
          action = () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EspecialidadesLaboralesFlotanteWidget(),
              ),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
          };
        } else if (id == 'foto_perfil') {
          icon = Icons.camera_alt_outlined;
          action = () => _mostrarOpcionesSelfie();
        } else if (id == 'evals' || id == 'tiempo') {
          icon = id == 'evals' ? Icons.star_outline_rounded : Icons.schedule_rounded;
          action = _compartirTarjeta;
        } else if (id == 'fotos_trabajo') {
          icon = Icons.photo_library_outlined;
          action = _compartirTarjeta;
        }
        consejos.add(_ConsejoItem(
          id: id.isEmpty ? t['title'] ?? '' : id,
          title: t['title'] ?? '',
          body: t['body'] ?? '',
          icon: icon,
          onTap: () => _abrirConsejoConfianza(
            id.isEmpty ? (t['title'] ?? '') : id,
            action,
          ),
        ));
      }

      if (consejos.isEmpty) {
        final sc = data['scoring'];
        final nivel = sc is Map ? (sc['nivel_confianza'] as String?) : null;
        final score = sc is Map ? (sc['score_identidad'] as num?)?.toInt() : null;
        consejos.add(_ConsejoItem(
          id: 'compartir',
          title: nivel == 'muy_alto'
              ? 'Excelente confianza de perfil'
              : 'Vas bien: compartí tu tarjeta',
          body: score != null
              ? 'Confianza ${ScoringService.labelNivel(nivel)} ($score/100). Pasale tu tarjeta y pedí evaluaciones reales de clientes.'
              : 'Pasale tu tarjeta por WhatsApp y pedí evaluaciones de trabajos reales.',
          icon: Icons.emoji_events_outlined,
          onTap: () => _abrirConsejoConfianza('compartir', _compartirTarjeta),
        ));
      }

      // Mostrar hasta 4 consejos (prioriza confianza)
      if (mounted) {
        setState(() {
          _estaVisible = visible;
          _resumenOficios = labelsOficios.isEmpty ? 'Sin oficios cargados' : labelsOficios;
          _resumenZona = localidades.isEmpty
              ? 'Sin zona de trabajo'
              : '${localidades.length} zona${localidades.length == 1 ? '' : 's'}';
          _pasosCompletos = pasos;
          _tipsTotales = consejos.length;
          _consejos = consejos.take(3).toList();
          final sc = data['scoring'];
          if (sc is Map) {
            _nivelConfianza = sc['nivel_confianza'] as String?;
            _scoreIdentidad = (sc['score_identidad'] as num?)?.toInt();
          } else {
            _nivelConfianza = null;
            _scoreIdentidad = null;
          }
          _cargandoConsejos = false;
          _visibilidadCargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error visibilidad/consejos: $e');
      if (mounted) {
        setState(() {
          _consejos = [];
          _cargandoConsejos = false;
          _visibilidadCargando = false;
        });
      }
    }
  }

  Future<void> _mostrarOpcionesSelfie() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Foto de perfil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Una selfie ayuda a que te reconozcan y generen confianza.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: primaryColor),
                  title: const Text('Tomar selfie'),
                  subtitle: Text(kIsWeb ? 'En web se abre el selector de archivos' : 'Cámara frontal'),
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
                if (_urlFotoPerfil != null && _urlFotoPerfil!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Quitar foto'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _quitarFotoPerfil();
                    },
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Ahora no', style: TextStyle(color: Colors.grey.shade600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _elegirYSubirFoto(ImageSource source) async {
    final uid = UserSession().uid;
    if (uid == null) return;
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() => _subiendoFoto = true);

      final bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance
          .ref()
          .child('usuarios')
          .child(uid)
          .child('foto_perfil.jpg');
      final upload = await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await upload.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'url_foto_perfil': url,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final session = UserSession();
      if (session.datosCompletos != null) {
        session.datosCompletos = {
          ...session.datosCompletos!,
          'url_foto_perfil': url,
        };
      }

      if (mounted) {
        setState(() {
          _urlFotoPerfil = url;
          _subiendoFoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Listo! Tu foto de perfil quedó actualizada.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error subiendo foto perfil: $e');
      if (mounted) {
        setState(() => _subiendoFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir la foto: $e')),
        );
      }
    }
  }

  Future<void> _quitarFotoPerfil() async {
    final uid = UserSession().uid;
    if (uid == null) return;
    try {
      setState(() => _subiendoFoto = true);
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'url_foto_perfil': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      UserSession().datosCompletos?.remove('url_foto_perfil');
      if (mounted) {
        setState(() {
          _urlFotoPerfil = null;
          _subiendoFoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _subiendoFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _compartirTarjeta() async {
    final userId = UserSession().uid;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró la sesión activa.')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(userId).get();
      if (context.mounted) Navigator.pop(context);
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final profesiones = data['profesiones'] as List<dynamic>? ?? [];
      final zonasCobertura = data['zonas_cobertura'] as Map<String, dynamic>? ?? {};
      final localidades = zonasCobertura['localidades'] as List<dynamic>? ?? [];
      final esTrabajador = data['es_trabajador'] == true;
      if (profesiones.isEmpty || localidades.isEmpty || !esTrabajador) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Para que te contacten, primero cargá oficios y zona.')),
          );
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroTrabajadorWidget()))
              .then((_) => _refrescarRolDesdeFirestore());
        }
      } else if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TarjetaDigitalWidget(
              usuarioRef: FirebaseFirestore.instance.collection('usuarios').doc(userId),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _irABuscador([String? query]) {
    final texto = (query ?? _searchController.text).trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuscadorPrestadoresWidget(initialQuery: texto.isEmpty ? null : texto),
      ),
    );
  }

  Widget _buildAvatarHeader() {
    final initials = _getInitials();
    final initialsStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    final hasPhoto = _urlFotoPerfil != null && _urlFotoPerfil!.isNotEmpty;
    if (!hasPhoto) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: primaryColor,
        child: Text(initials, style: initialsStyle),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: primaryColor,
      child: ClipOval(
        child: Image.network(
          _urlFotoPerfil!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 40,
            height: 40,
            color: primaryColor,
            alignment: Alignment.center,
            child: Text(initials, style: initialsStyle),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 40,
              height: 40,
              color: primaryColor,
              alignment: Alignment.center,
              child: Text(initials, style: initialsStyle),
            );
          },
        ),
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

  void _onBottomNavTap(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final nombreMostrar = UserSession().nombreCompleto.isNotEmpty
        ? UserSession().nombreCompleto.split(' ').first
        : 'Usuario';
    if (_mostrarBannerZonaCliente && !_bannerZonaTracked) {
      _bannerZonaTracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ProxAnalytics.instance.action('banner_zona_shown', screen: '/home');
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hola $nombreMostrar',
                style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(
              _modoPrestador ? AppCopy.homePrestadorHint : AppCopy.homeClienteHint,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
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
                      Icon(_modoPrestador ? Icons.handyman_outlined : Icons.search_rounded,
                          size: 16, color: primaryColor),
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
            child: GestureDetector(
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor.withOpacity(0.35), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: _subiendoFoto
                          ? Padding(
                              padding: const EdgeInsets.all(3),
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: primaryColor),
                            )
                          : Icon(Icons.photo_camera_rounded, size: 11, color: primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _currentIndex == 1
            ? const MenuEvaluacionesWidget(
                key: ValueKey('evaluar'),
                embedded: true,
              )
            : _currentIndex == 2
                ? MenuPerfilOpcionesWidget(
                    key: ValueKey('perfil_$_modoPrestador'),
                    modoPrestador: _modoPrestador,
                    onClose: () => setState(() => _currentIndex = 0),
                    onRolPuedeHaberCambiado: _refrescarRolDesdeFirestore,
                  )
                : (_modoPrestador
                    ? _buildPrestadorBody(key: const ValueKey('prestador'))
                    : _buildClienteBody(key: const ValueKey('cliente'))),
      ),
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
        onTap: _onBottomNavTap,
      ),
    );
  }

  Widget _buildBannerZonaCliente() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _clientePrimary.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: _clientePrimary, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Si indicás tu zona, te mostramos prestadores cerca.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.35),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
                    onPressed: _descartarBannerZona,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _descartarBannerZona,
                      child: const Text('Ahora no'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _abrirDomicilioDesdeBanner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _clientePrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Indicar mi zona'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteBody({Key? key}) {
    final colores = [
      _clientePrimary, _accentCoral, _accentLightBlue, _prestadorPrimary,
      _dark, _clientePrimary, _accentCoral, _prestadorPrimary,
    ];
    return SingleChildScrollView(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_mostrarBannerZonaCliente) _buildBannerZonaCliente(),
          if (!_puedeSerAmbos)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Material(
                color: _prestadorPrimary,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _irAOfrecerServicios,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.handyman_outlined, color: Colors.white, size: 26),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text('¿Ofrecés un oficio? Empezá en 3 pasos',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '¿Qué servicio buscas?',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _irABuscador,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(AppCopy.seccionServiciosBuscados,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          if (_cargandoServicios)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topServicios.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final s = _topServicios[index];
                  final color = colores[index % colores.length];
                  return InkWell(
                    onTap: () => _irABuscador(s.label),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(s.icon, size: 30, color: color),
                        ),
                        const SizedBox(height: 8),
                        Text(s.label,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _quickAction(Icons.search, 'Buscar prestadores', () => _irABuscador()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickAction(Icons.check_circle_outline, 'Evaluar trabajos', () {
                    setState(() => _currentIndex = 1);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      ),
    );
  }


  Future<void> _abrirConsejoConfianza(String id, VoidCallback action) async {
    if (id.isNotEmpty) {
      setState(() => _tipsLeidos.add(id));
      final uid = UserSession().uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
            'tips_confianza_leidos': FieldValue.arrayUnion([id]),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    }
    action();
  }

  void _mostrarExplicacionConfianza() {
    final score = _scoreIdentidad;
    final nivel = _nivelConfianza != null
        ? ScoringService.labelNivel(_nivelConfianza)
        : null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: _prestadorPrimary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '¿Qué es la confianza de perfil?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  score != null
                      ? 'Tu puntaje actual: ${score}/100${nivel != null ? ' · $nivel' : ''}'
                      : 'Es un número de 0 a 100 sobre cuán confiable se ve tu perfil.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mide qué tan confiable se ve quien ofrece un servicio, según:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                _explicacionFila(Icons.badge_outlined, 'Datos del perfil',
                    'Documento, foto y datos de contacto verificables.'),
                _explicacionFila(Icons.handyman_outlined, 'Lo que ofrece',
                    'Servicios cargados, zona y fotos de trabajos.'),
                _explicacionFila(Icons.star_outline_rounded, 'Calificación de lo ofertado',
                    'Opiniones y validaciones de clientes sobre su trabajo.'),
                _explicacionFila(Icons.schedule_rounded, 'Tiempo',
                    'La confianza crece con el uso real, no de un día para el otro.'),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _prestadorPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Entendido',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _explicacionFila(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _prestadorPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _prestadorPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0F172A))),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12, height: 1.3, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrestadorBody({Key? key}) {
    final confLabel = _nivelConfianza != null
        ? ScoringService.labelNivel(_nivelConfianza)
        : null;
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // —— Estado de visibilidad (estilo tarjeta) ——
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _visibilidadCargando
                ? const SizedBox(
                    height: 72,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const EspecialidadesLaboralesFlotanteWidget(),
                          ),
                        );
                        await _cargarEstadoVisibilidadYConsejos();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _estaVisible
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _estaVisible
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_outlined,
                                color: _estaVisible
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFEA580C),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _estaVisible
                                              ? const Color(0xFFD1FAE5)
                                              : const Color(0xFFFFEDD5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _estaVisible ? 'Visible' : 'Oculto',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: _estaVisible
                                                ? const Color(0xFF047857)
                                                : const Color(0xFFC2410C),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _estaVisible
                                              ? _resumenOficios
                                              : 'Completá perfil para aparecer',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _estaVisible
                                        ? _resumenZona
                                        : 'Oficios · zona · teléfono',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
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
                  ),
          ),

          // —— Confianza compacta ——
          if (confLabel != null || _scoreIdentidad != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: const Color(0xFFE6F7FA),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _mostrarExplicacionConfianza,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _prestadorPrimary.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_outlined,
                            color: _prestadorPrimary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Confianza de perfil',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _prestadorPrimary.withOpacity(0.9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.info_outline_rounded,
                                      size: 14,
                                      color: _prestadorPrimary.withOpacity(0.75)),
                                ],
                              ),
                              Text(
                                confLabel != null && _scoreIdentidad != null
                                    ? '$confLabel · $_scoreIdentidad/100'
                                    : (confLabel ?? '$_scoreIdentidad/100'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'Tocá para ver cómo se calcula',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: ((_scoreIdentidad ?? 0) / 100).clamp(0.0, 1.0),
                                strokeWidth: 4,
                                backgroundColor: Colors.white,
                                color: _prestadorPrimary,
                              ),
                              Text(
                                '${_scoreIdentidad ?? 0}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _prestadorPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // —— CTA tarjeta ——
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
                        child: const Icon(Icons.qr_code_2_rounded,
                            color: Colors.white, size: 26),
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
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Compartila para que te contacten',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
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

          // —— Mejorá tu perfil (compacto, estilo tarjeta) ——
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Para subir tu confianza',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (_tipsTotales > 0)
                  Text(
                    '$_tipsTotales pendiente${_tipsTotales == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  )
                else if (!_cargandoConsejos)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

          if (_cargandoConsejos)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_consejos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, color: _prestadorPrimary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Perfil sólido. Pedí evaluaciones reales de clientes.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < _consejos.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _ConsejoCard(
                      item: _consejos[i],
                      accent: _prestadorPrimary,
                      index: i + 1,
                      leido: _tipsLeidos.contains(_consejos[i].id),
                    ),
                  ],
                ],
              ),
            ),

          if (AppEnv.showDevTools)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _corriendoBatch
                    ? null
                    : () async {
                        setState(() => _corriendoBatch = true);
                        try {
                          final r = await ScoringService.ejecutarBatchDiario(
                            trigger: 'manual_dev',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Scoring ${r.status}: ${r.actualizados}/${r.procesados}'
                                  ' · timeout ${r.evalsPublicadasTimeout}'
                                  ' · ${r.duracionMs}ms'
                                  '${r.errores.isEmpty ? '' : ' · errs ${r.errores.length}'}',
                                ),
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _corriendoBatch = false);
                          }
                        }
                      },
                icon: const Icon(Icons.refresh),
                label: Text(
                  _corriendoBatch ? 'Batch scoring…' : 'Correr batch scoring (dev)',
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
  final bool leido;

  const _ConsejoCard({
    required this.item,
    required this.accent,
    required this.index,
    this.leido = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = leido ? const Color(0xFF94A3B8) : const Color(0xFF0F172A);
    final bodyColor = leido ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    final iconBg = leido ? const Color(0xFFF1F5F9) : accent.withOpacity(0.12);
    final iconColor = leido ? const Color(0xFF94A3B8) : accent;

    return Material(
      color: leido ? const Color(0xFFF8FAFC) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: leido ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  leido ? Icons.check_circle_outline_rounded : item.icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (leido)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Leído',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: bodyColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                leido ? Icons.done_rounded : Icons.chevron_right_rounded,
                color: leido ? const Color(0xFFCBD5E1) : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicioMeta {
  final String label;
  final IconData icon;
  const _ServicioMeta(this.label, this.icon);
}

class _ServicioItem {
  final String clave;
  final String label;
  final IconData icon;
  _ServicioItem({required this.clave, required this.label, required this.icon});
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
