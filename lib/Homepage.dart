import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  int _pasosCompletos = 0;
  static const int _pasosTotales = 4;

  bool _bannerZonaDescartado = false;
  bool _bannerZonaTracked = false;

  Color get primaryColor =>
      _modoPrestador ? _prestadorPrimary : _clientePrimary;

  static const Map<String, _ServicioMeta> _metaServicios = {
    'electricidad':
        _ServicioMeta('Electricista', Icons.electrical_services_outlined),
    'plomeria': _ServicioMeta('Plomería', Icons.plumbing),
    'gasista':
        _ServicioMeta('Gasista', Icons.local_fire_department_outlined),
    'carpinteria': _ServicioMeta('Carpintería', Icons.handyman_outlined),
    'pintura': _ServicioMeta('Pintura', Icons.format_paint_outlined),
    'albanileria':
        _ServicioMeta('Construcción', Icons.construction_outlined),
    'jardineria': _ServicioMeta('Jardinería', Icons.yard_outlined),
    'limpieza': _ServicioMeta('Limpieza', Icons.cleaning_services_outlined),
  };

  static const List<String> _fallbackOrden = [
    'electricidad',
    'carpinteria',
    'plomeria',
    'jardineria',
    'limpieza',
    'pintura',
    'gasista',
    'albanileria',
  ];

  @override
  void initState() {
    super.initState();
    _detectarRol();
    _cargarTopServicios();
  }

  bool _faltaZonaCliente() {
    final data = UserSession().datosCompletos;
    if (data == null) return true;
    final geo = data['direccion_geo'];
    if (geo is! Map) return true;
    final loc = (geo['localidad_id'] ?? geo['localidad_nombre'] ?? '')
        .toString()
        .trim();
    final part =
        (geo['partido_id'] ?? geo['partido_nombre'] ?? '').toString().trim();
    final prov = (geo['provincia_id'] ?? geo['provincia_nombre'] ?? '')
        .toString()
        .trim();
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
    setState(() {
      _puedeSerAmbos = esPrestador;
      _modoPrestador = esPrestador;
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
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        UserSession().iniciarSesion(uid, doc.data()!);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error refrescando sesión: $e');
    }
  }

  Future<void> _refrescarRolDesdeFirestore() async {
    final uid = UserSession().uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        UserSession().iniciarSesion(uid, doc.data()!);
        if (mounted) {
          _detectarRol();
        }
      }
    } catch (e) {
      debugPrint('Error refrescando rol: $e');
    }
  }
