import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'menuPerfil.dart';
import 'registroTrabajador.dart';
import 'tarjetaDigital.dart';
import 'menuPerfilOpciones.dart';
import 'datosPersonalesflotante.dart';
import 'ZonaDeTrabajoflotante.dart';
import 'solicitar_validacion.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  // Paleta
  static const Color _clientePrimary = Color(0xFF734BE4);
  static const Color _prestadorPrimary = Color(0xFF28B5CD);
  static const Color _accentCoral = Color(0xFFF75A6D);
  static const Color _accentLightBlue = Color(0xFF7AAFFF);
  static const Color _dark = Color(0xFF3D4756);

  final TextEditingController _searchController = TextEditingController();

  // 0 = Home, 3 = Perfil flotante
  int _currentIndex = 0;

  bool _modoPrestador = false;
  bool _puedeSerAmbos = false;

  // Top servicios (hasta 8)
  List<_ServicioItem> _topServicios = [];
  bool _cargandoServicios = true;

  // Consejos personalizados prestador
  List<_ConsejoItem> _consejos = [];
  bool _cargandoConsejos = true;

  Color get primaryColor => _modoPrestador ? _prestadorPrimary : _clientePrimary;

  /// Mapeo clave de profesión (DB) → label + icono
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

  /// Fallback fijo (orden de popularidad aproximado)
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

  void _detectarRol() {
    final data = UserSession().datosCompletos;
    final esPrestador =
        data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
    setState(() {
      _puedeSerAmbos = esPrestador;
      _modoPrestador = esPrestador;
    });
    if (esPrestador) {
      _cargarConsejosPersonalizados();
    } else {
      setState(() {
        _cargandoConsejos = false;
        _consejos = [];
      });
    }
  }

  // ---------------------------------------------------------------------------
  // TOP 8 SERVICIOS (ranking diario con auto-actualización)
  // ---------------------------------------------------------------------------
  Future<void> _cargarTopServicios() async {
    setState(() => _cargandoServicios = true);
    try {
      final statsRef =
          FirebaseFirestore.instance.collection('stats').doc('top_servicios');
      final statsDoc = await statsRef.get();

      bool usarStats = false;
      List<String> ranking = [];

      if (statsDoc.exists) {
        final data = statsDoc.data()!;
        final actualizado = data['actualizado_en'];
        DateTime? ts;
        if (actualizado is Timestamp) ts = actualizado.toDate();

        if (ts != null && DateTime.now().difference(ts).inHours < 24) {
          ranking = (data['ranking'] as List<dynamic>? ?? [])
              .map((e) => e.toString().toLowerCase().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (ranking.isNotEmpty) usarStats = true;
        }
      }

      // Si no hay ranking fresco → recalcular desde la DB y guardar
      if (!usarStats) {
        ranking = await _recalcularYGuardarRanking(statsRef);
      }

      _aplicarRanking(ranking.isNotEmpty ? ranking : _fallbackOrden);
    } catch (e) {
      debugPrint('Error cargando top servicios: $e');
      _aplicarRanking(_fallbackOrden);
    }
  }

  /// Cuenta profesiones de prestadores y actualiza stats/top_servicios
  Future<List<String>> _recalcularYGuardarRanking(
    DocumentReference statsRef,
  ) async {
    final counts = <String, int>{};

    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('es_trabajador', isEqualTo: true)
        .limit(500)
        .get();

    for (final doc in snap.docs) {
      final profs = doc.data()['profesiones'] as List<dynamic>? ?? [];
      for (final p in profs) {
        final key = p.toString().toLowerCase().trim();
        if (key.isEmpty) continue;
        if (!_metaServicios.containsKey(key)) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final ranking = sorted.map((e) => e.key).take(8).toList();

    for (final k in _fallbackOrden) {
      if (ranking.length >= 8) break;
      if (!ranking.contains(k)) ranking.add(k);
    }

    try {
      await statsRef.set({
        'ranking': ranking,
        'actualizado_en': FieldValue.serverTimestamp(),
        'fuente': 'app_auto',
        'total_prestadores_muestra': snap.docs.length,
      });
    } catch (e) {
      debugPrint('No se pudo guardar stats/top_servicios: $e');
    }

    return ranking;
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
      items.add(_ServicioItem(clave: clave, label: meta.label, icon: meta.icon));
    }

    if (mounted) {
      setState(() {
        _topServicios = items;
        _cargandoServicios = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // CONSEJOS PERSONALIZADOS (prestador)
  // ---------------------------------------------------------------------------
  Future<void> _cargarConsejosPersonalizados() async {
    setState(() => _cargandoConsejos = true);
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() {
        _consejos = [];
        _cargandoConsejos = false;
      });
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final data = doc.data() ?? {};

      final consejos = <_ConsejoItem>[];

      // 1) Zona de trabajo
      final zonas = data['zonas_cobertura'] as Map<String, dynamic>?;
      final localidades = zonas?['localidades'] as List<dynamic>? ?? [];
      if (localidades.isEmpty) {
        consejos.add(_ConsejoItem(
          title: 'Definí tu zona de trabajo',
          body: 'Sin localidades de cobertura los clientes no te encuentran.',
          icon: Icons.map_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ZonaDeTrabajoFlotanteWidget(),
              ),
            );
          },
        ));
      }

      // 2) Número de documento
      final docNumero =
          (data['doc_numero'] ?? data['numero_documento'] ?? data['documento'] ?? '')
              .toString()
              .trim();
      if (docNumero.isEmpty) {
        consejos.add(_ConsejoItem(
          title: 'Cargá tu número de documento',
          body: 'Es un dato clave de confianza para quienes te contratan.',
          icon: Icons.badge_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DatosPersonalesFlotanteWidget(),
              ),
            );
          },
        ));
      }

      // 3) Fecha de nacimiento
      if (data['fecha_nacimiento'] == null) {
        consejos.add(_ConsejoItem(
          title: 'Completá tu fecha de nacimiento',
          body: 'Ayuda a validar tu identidad y a personalizar tu perfil.',
          icon: Icons.cake_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DatosPersonalesFlotanteWidget(),
              ),
            );
          },
        ));
      }

      // 4) Validaciones de terceros
      final vals = data['validaciones_recibidas'] as List<dynamic>? ?? [];
      if (vals.isEmpty) {
        consejos.add(_ConsejoItem(
          title: 'Pedí validaciones de terceros',
          body: 'Las referencias de vecinos o conocidos aumentan mucho la confianza.',
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

      // 5) Foto de documento validada
      final docValidado = data['doc_validado'] == true;
      final urlFoto = (data['url_foto_documento'] ?? '').toString();
      if (!docValidado || urlFoto.isEmpty) {
        consejos.add(_ConsejoItem(
          title: 'Validá tu documento con foto',
          body: 'Escaneá el DNI: es el diferencial más fuerte frente al resto.',
          icon: Icons.document_scanner_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DatosPersonalesFlotanteWidget(),
              ),
            );
          },
        ));
      }

      if (consejos.isEmpty) {
        consejos.add(_ConsejoItem(
          title: '¡Perfil muy completo!',
          body: 'Seguí compartiendo tu tarjeta y pidiendo evaluaciones.',
          icon: Icons.emoji_events_outlined,
          onTap: _compartirTarjeta,
        ));
      }

      if (mounted) {
        setState(() {
          _consejos = consejos;
          _cargandoConsejos = false;
        });
      }
    } catch (e) {
      debugPrint('Error consejos: $e');
      if (mounted) {
        setState(() {
          _consejos = [];
          _cargandoConsejos = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _cerrarSesion() {
    UserSession().cerrarSesion();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreenWidget()),
    );
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
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(userId).get();
      if (context.mounted) Navigator.pop(context);

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final profesiones = data['profesiones'] as List<dynamic>? ?? [];
        final zonasCobertura =
            data['zonas_cobertura'] as Map<String, dynamic>? ?? {};
        final localidades = zonasCobertura['localidades'] as List<dynamic>? ?? [];
        final esTrabajador = data['es_trabajador'] == true;

        if (profesiones.isEmpty || localidades.isEmpty || !esTrabajador) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Para compartir tu tarjeta, primero configurá tus especialidades y zonas.',
                ),
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegistroTrabajadorWidget()),
            );
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

  void _irAGuiaInstagram() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abriendo guía: Cómo promocionar tus trabajos en Instagram...'),
      ),
    );
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
    if (_currentIndex == 3 && index != 3) {
      setState(() => _currentIndex = 0);
    }

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
      setState(() => _currentIndex = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensajes próximamente')),
      );
      return;
    }

    if (index == 3) {
      setState(() => _currentIndex = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nombreMostrar = UserSession().nombreCompleto.isNotEmpty
        ? UserSession().nombreCompleto.split(' ').first
        : 'Usuario';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
              _modoPrestador ? '¿Qué vas a ofrecer hoy?' : '¿Qué servicio necesitás?',
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
                  if (_modoPrestador && _consejos.isEmpty && !_cargandoConsejos) {
                    _cargarConsejosPersonalizados();
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
                        _modoPrestador ? Icons.engineering : Icons.person_search,
                        size: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _modoPrestador ? 'Prestador' : 'Cliente',
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
        child: _currentIndex == 3
            ? MenuPerfilOpcionesWidget(
                key: ValueKey('perfil_$_modoPrestador'),
                modoPrestador: _modoPrestador,
                onClose: () => setState(() => _currentIndex = 0),
              )
            : (_modoPrestador
                ? _buildPrestadorBody(key: const ValueKey('prestador'))
                : _buildClienteBody(key: const ValueKey('cliente'))),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex == 3 ? 3 : 0,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Evaluar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Mensajes',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: _onBottomNavTap,
      ),
    );
  }

  // ===================== VISTA CLIENTE =====================
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
              'Servicios más buscados',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Actualizados según demanda de las últimas 24 hs',
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

          const SizedBox(height: 28),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Últimos mensajes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          _buildProviderCard(
            'Electricista',
            'Nuestro electricista completó el trabajo en tiempo récord.',
            'Hace 2h',
            _clientePrimary,
          ),
          _buildProviderCard(
            'Plomería',
            'Se reparó la pérdida de agua en la cocina.',
            'Ayer',
            _prestadorPrimary,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===================== VISTA PRESTADOR =====================
  Widget _buildPrestadorBody({Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _irAGuiaInstagram,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    _prestadorPrimary.withOpacity(0.9),
                    _clientePrimary.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Sabés cómo comunicar tus trabajos en Instagram?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tocá aquí para ver el mini-manual',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tu negocio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _buildPrestadorCard(
                  icon: Icons.badge_outlined,
                  title: 'Compartir tarjeta',
                  subtitle: 'Tu perfil profesional',
                  color: _prestadorPrimary,
                  onTap: _compartirTarjeta,
                ),
                _buildPrestadorCard(
                  icon: Icons.handyman_outlined,
                  title: 'Especialidades',
                  subtitle: 'Oficios y zonas',
                  color: _clientePrimary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegistroTrabajadorWidget(),
                      ),
                    );
                  },
                ),
                _buildPrestadorCard(
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
                _buildPrestadorCard(
                  icon: Icons.person_outline,
                  title: 'Mi perfil',
                  subtitle: 'Datos y validaciones',
                  color: _dark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MenuPerfilWidget(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Consejos para crecer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Basados en lo que todavía te falta completar',
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

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===================== WIDGETS AUXILIARES =====================

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

  Widget _buildProviderCard(
    String title,
    String description,
    String time,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              title[0],
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modelos internos
// ---------------------------------------------------------------------------

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
