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

  /// Banner domicilio (solo vista cliente). Dismiss solo en esta sesión.
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

  /// Falta zona útil para ranking de búsquedas (provincia/partido/localidad).
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
    // Con localidad alcanza; si no, al menos provincia + partido.
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
      if (!doc.exists) return;

      final data = doc.data()!;
      UserSession().iniciarSesion(uid, data);

      final esPrestador =
          data['es_trabajador'] == true || data['rol'] == 'trabajador';

      if (!mounted) return;
      setState(() {
        _puedeSerAmbos = esPrestador;
        if (esPrestador) {
          _modoPrestador = true;
          _currentIndex = 0;
        }
      });

      if (esPrestador) {
        await _cargarEstadoVisibilidadYConsejos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Listo: ya podés ofrecer servicios. Completá zona si te falta.',
              ),
              backgroundColor: Color(0xFF28B5CD),
            ),
          );
        }
      }
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

  /// Solo lee stats/top_servicios. No barre prestadores en horario de uso.
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
      items.add(_ServicioItem(
        clave: clave,
        label: meta.label,
        icon: meta.icon,
      ));
      if (items.length >= 8) break;
    }

    for (final clave in _fallbackOrden) {
      if (items.length >= 8) break;
      if (vistos.contains(clave)) continue;
      final meta = _metaServicios[clave];
      if (meta == null) continue;
      vistos.add(clave);
      items.add(
        _ServicioItem(clave: clave, label: meta.label, icon: meta.icon),
      );
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
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
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

      if (localidades.isEmpty) {
        consejos.add(_ConsejoItem(
          title: 'Definí tu zona de trabajo',
          body: 'Sin zona los clientes de tu barrio no te encuentran.',
          icon: Icons.map_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ZonaDeTrabajoFlotanteWidget(),
              ),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
          },
        ));
      }

      if (profesiones.isEmpty) {
        consejos.add(_ConsejoItem(
          title: 'Indicá qué oficios hacés',
          body: 'Sin oficios no aparecés cuando alguien busca un servicio.',
          icon: Icons.handyman_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RegistroTrabajadorWidget(),
              ),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
          },
        ));
      }

      if (telefono.isEmpty) {
        consejos.add(_ConsejoItem(
          title: 'Cargá tu celular',
          body: 'Es como te van a contactar por WhatsApp o llamada.',
          icon: Icons.phone_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DatosPersonalesFlotanteWidget(),
              ),
            ).then((_) => _cargarEstadoVisibilidadYConsejos());
          },
        ));
      }

      final vals = data['validaciones_recibidas'] as List<dynamic>? ?? [];
      if (vals.isEmpty && consejos.length < 2) {
        consejos.add(_ConsejoItem(
          title: 'Pedí validaciones de terceros',
          body: 'Que alguien del barrio confirme que te conoce suma confianza.',
          icon: Icons.verified_user_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SolicitarValidacionWidget(),
              ),
            );
          },
        ));
      }

      if (consejos.isEmpty) {
        consejos.add(_ConsejoItem(
          title: 'Estás listo para que te contacten',
          body: 'Pasale tu tarjeta por WhatsApp o pedí evaluaciones.',
          icon: Icons.emoji_events_outlined,
          onTap: _compartirTarjeta,
        ));
      }

      if (mounted) {
        setState(() {
          _estaVisible = visible;
          _resumenOficios =
              labelsOficios.isEmpty ? 'Sin oficios cargados' : labelsOficios;
          _resumenZona = localidades.isEmpty
              ? 'Sin zona de trabajo'
              : '${localidades.length} zona${localidades.length == 1 ? '' : 's'} activa${localidades.length == 1 ? '' : 's'}';
          _pasosCompletos = pasos;
          _consejos = consejos.take(2).toList();
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

  Future<void> _ejecutarBatchScoring() async {
    if (_corriendoBatch) return;
    setState(() => _corriendoBatch = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final r = await ScoringService.ejecutarBatchDiario(
        onProgress: (hechos, _) {
          debugPrint('Scoring batch: $hechos usuarios');
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Badges actualizados: ${r.actualizados} de ${r.procesados} usuarios',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al recalcular: $e')),
      );
    } finally {
      if (mounted) setState(() => _corriendoBatch = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _compartirTarjeta() async {
    final String? userId = UserSession().uid;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró la sesión activa.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get();
      if (context.mounted) Navigator.pop(context);

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final profesiones = data['profesiones'] as List<dynamic>? ?? [];
        final zonasCobertura =
            data['zonas_cobertura'] as Map<String, dynamic>? ?? {};
        final localidades =
            zonasCobertura['localidades'] as List<dynamic>? ?? [];
        final esTrabajador = data['es_trabajador'] == true;

        if (profesiones.isEmpty || localidades.isEmpty || !esTrabajador) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Para que te contacten, primero cargá tus oficios y zona de trabajo.',
                ),
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RegistroTrabajadorWidget(),
              ),
            ).then((_) => _refrescarRolDesdeFirestore());
          }
        } else {
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TarjetaDigitalWidget(
                  usuarioRef: FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(userId),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _irABuscador([String? query]) {
    final texto = (query ?? _searchController.text).trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuscadorPrestadoresWidget(
          initialQuery: texto.isEmpty ? null : texto,
        ),
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

  void _onBottomNavTap(int index) {
    if (index == 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    if (index == 1) {
      setState(() => _currentIndex = 0);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()),
      );
      return;
    }

    if (index == 2) {
      setState(() => _currentIndex = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nombreMostrar = UserSession().nombreCompleto.isNotEmpty
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
            Text(
              'Hola $nombreMostrar',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _modoPrestador
                  ? AppCopy.homePrestadorHint
                  : AppCopy.homeClienteHint,
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
                  setState(() {
                    _modoPrestador = !_modoPrestador;
                  });
                  if (_modoPrestador) {
                    _cargarEstadoVisibilidadYConsejos();
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _modoPrestador
                            ? Icons.handyman_outlined
                            : Icons.search_rounded,
                        size: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _modoPrestador ? 'Ofrezco trabajo' : 'Busco trabajo',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: primaryColor,
              child: Text(
                _getInitials(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return SlideTransition(position: offsetAnimation, child: child);
        },
        child: _currentIndex == 2
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
        currentIndex: _currentIndex == 2 ? 2 : 0,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Evaluar',
          ),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _clientePrimary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: _clientePrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¿Dónde necesitás el servicio?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Si indicás tu zona, te mostramos prestadores cerca y te resulta más fácil contratar.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
                    onPressed: _descartarBannerZona,
                    tooltip: 'Ahora no',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _descartarBannerZona,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
    final coloresIcono = [
      _clientePrimary,
      _accentCoral,
      _accentLightBlue,
      _prestadorPrimary,
      _dark,
      _clientePrimary,
      _accentCoral,
      _prestadorPrimary,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.handyman_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¿Ofrecés un oficio?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Empezá a recibir clientes en 3 pasos',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                        ),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (value) => _irABuscador(value),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppCopy.seccionServiciosBuscados,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Según ranking diario de demanda',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
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
                gridDelegate: const NSliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final s = _topServicios[index];
                  final color = coloresIcono[index % coloresIcono.length];
                  return _buildCategoryIcon(s.icon, s.label, color, () {
                    _irABuscador(s.label);
                  });
                },
              ),
            ),
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Acciones rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.search,
                    label: 'Buscar\nprestadores',
                    onTap: () => _irABuscador(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.check_circle_outline,
                    label: 'Evaluar\ntrabajos',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MenuEvaluacionesWidget(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (!_puedeSerAmbos) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildQuickAction(
                icon: Icons.handyman_outlined,
                label: 'Quiero ofrecer mis servicios',
                onTap: _irAOfrecerServicios,
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppCopy.seccionActividad,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.grey.shade400),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    AppCopy.actividadVacia,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPrestadorBody({Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVisibilidadCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Material(
              color: _prestadorPrimary,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _compartirTarjeta,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
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
                              'Tu tarjeta para que te contacten',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pasale tu ficha al cliente por WhatsApp',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tu trabajo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildPrestadorCard(
                    icon: Icons.handyman_outlined,
                    title: 'Oficios y zona',
                    subtitle: 'Cómo te encuentran',
                    color: _clientePrimary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegistroTrabajadorWidget(),
                        ),
                      ).then((_) => _refrescarRolDesdeFirestore());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPrestadorCard(
                    icon: Icons.star_outline,
                    title: 'Evaluaciones',
                    subtitle: 'Lo que dicen de vos',
                    color: _accentCoral,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MenuEvaluacionesWidget(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppCopy.seccionConsejos,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Priorizamos lo que te hace aparecer en búsquedas',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          if (_cargandoConsejos)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_consejos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay pendientes por ahora.'),
            )
          else
            ..._consejos.map((c) => _buildTipCard(c)),
          if (AppEnv.showDevTools) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _corriendoBatch ? null : _ejecutarBatchScoring,
                icon: _corriendoBatch
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _corriendoBatch
                      ? 'Recalculando…'
                      : 'Recalcular badges (solo dev)',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _dark,
                  side: BorderSide(color: _dark.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 24),
              child: Text(
                'Solo visible en debug/staging. No aparece en producción.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ] else
            const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVisibilidadCard() {
    if (_visibilidadCargando) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Center(
          child: SizedBox(
            height: 36,
            width: 36,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final Color bg =
        _estaVisible ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED);
    final Color border =
        _estaVisible ? const Color(0xFF6EE7B7) : const Color(0xFFFDBA74);
    final Color iconColor =
        _estaVisible ? const Color(0xFF059669) : const Color(0xFFEA580C);
    final String titulo = _estaVisible
        ? 'Estás visible para clientes'
        : 'Todavía no aparecés en búsquedas';
    final String cuerpo = _estaVisible
        ? '$_resumenOficios · $_resumenZona'
        : 'Completá oficios, zona y teléfono para que te encuentren.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _estaVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: iconColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cuerpo,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _pasosTotales == 0
                        ? 0
                        : _pasosCompletos / _pasosTotales,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.8),
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_pasosCompletos de $_pasosTotales pasos para que te contacten',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(
    IconData icon,
    String label,
    Color accent,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 30, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrestadorCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(_ConsejoItem c) {
    return InkWell(
      onTap: c.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(c.icon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.body,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
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
  _ServicioItem({
    required this.clave,
    required this.label,
    required this.icon,
  });
}

class _ConsejoItem {
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
  _ConsejoItem({
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
  });
}
