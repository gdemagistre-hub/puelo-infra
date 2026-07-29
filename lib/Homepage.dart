import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'registroTrabajador.dart';
import 'tarjetaDigital.dart';
import 'menuPerfilOpciones.dart';
import 'Domicilioflotante.dart';
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

  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;
  bool _modoPrestador = false;
  bool _puedeSerAmbos = false;
  bool _bannerZonaDescartado = false;

  Color get primaryColor =>
      _modoPrestador ? _prestadorPrimary : _clientePrimary;

  @override
  void initState() {
    super.initState();
    final data = UserSession().datosCompletos;
    final esPrestador =
        data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
    _puedeSerAmbos = esPrestador;
    _modoPrestador = esPrestador;
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

  bool get _mostrarBanner =>
      !_modoPrestador && !_bannerZonaDescartado && _faltaZonaCliente();

  Future<void> _abrirDomicilio() async {
    ProxAnalytics.instance.action('banner_zona_cta', screen: '/home');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DomicilioFlotanteWidget()),
    );
    final uid = UserSession().uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      if (doc.exists) {
        UserSession().iniciarSesion(uid, doc.data()!);
        if (mounted) setState(() {});
      }
    }
  }

  void _irABuscador([String? q]) {
    final texto = (q ?? _searchController.text).trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuscadorPrestadoresWidget(
          initialQuery: texto.isEmpty ? null : texto,
        ),
      ),
    );
  }

  Future<void> _irAOfrecer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegistroTrabajadorWidget()),
    );
    final uid = UserSession().uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    UserSession().iniciarSesion(uid, data);
    final es = data['es_trabajador'] == true || data['rol'] == 'trabajador';
    if (mounted) {
      setState(() {
        _puedeSerAmbos = es;
        if (es) _modoPrestador = true;
      });
    }
  }

  void _compartirTarjeta() {
    final uid = UserSession().uid;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TarjetaDigitalWidget(
          usuarioRef:
              FirebaseFirestore.instance.collection('usuarios').doc(uid),
        ),
      ),
    );
  }

  String _initials() {
    final n = UserSession().nombreCompleto.trim();
    if (n.isEmpty) return 'U';
    final p = n.split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = UserSession().nombreCompleto.isNotEmpty
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
              'Hola $nombre',
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
                onTap: () => setState(() => _modoPrestador = !_modoPrestador),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _modoPrestador ? 'Ofrezco trabajo' : 'Busco trabajo',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
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
                _initials(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _currentIndex == 2
          ? MenuPerfilOpcionesWidget(
              modoPrestador: _modoPrestador,
              onClose: () => setState(() => _currentIndex = 0),
              onRolPuedeHaberCambiado: () async {
                await _irAOfrecer();
              },
            )
          : (_modoPrestador ? _bodyPrestador() : _bodyCliente()),
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
        onTap: (i) {
          if (i == 0) setState(() => _currentIndex = 0);
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()),
            );
          }
          if (i == 2) setState(() => _currentIndex = 2);
        },
      ),
    );
  }

  Widget _bodyCliente() {
    return ListView(
      children: [
        if (_mostrarBanner) _bannerZona(),
        if (!_puedeSerAmbos)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Material(
              color: _prestadorPrimary,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _irAOfrecer,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.handyman_outlined, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '¿Ofrecés un oficio? Empezá en 3 pasos',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white),
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
            onSubmitted: _irABuscador,
            decoration: InputDecoration(
              hintText: '¿Qué servicio buscas?',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            AppCopy.seccionServiciosBuscados,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in [
                'Electricista',
                'Plomería',
                'Gasista',
                'Carpintería',
                'Pintura',
                'Limpieza',
                'Jardinería',
                'Construcción',
              ])
                ActionChip(
                  label: Text(s),
                  onPressed: () => _irABuscador(s),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: () => _irABuscador(),
            icon: const Icon(Icons.search),
            label: const Text('Buscar prestadores'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _clientePrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _bannerZona() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _clientePrimary.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, color: _clientePrimary),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Dónde necesitás el servicio?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  ProxAnalytics.instance
                      .action('banner_zona_dismiss', screen: '/home');
                  setState(() => _bannerZonaDescartado = true);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ProxAnalytics.instance
                        .action('banner_zona_dismiss', screen: '/home');
                    setState(() => _bannerZonaDescartado = true);
                  },
                  child: const Text('Ahora no'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _abrirDomicilio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _clientePrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Indicar mi zona'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bodyPrestador() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Material(
          color: _prestadorPrimary,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _compartirTarjeta,
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.qr_code_2, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu tarjeta para que te contacten',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.handyman_outlined),
          title: const Text('Oficios y zona'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _irAOfrecer,
        ),
        ListTile(
          leading: const Icon(Icons.star_outline),
          title: const Text('Evaluaciones'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()),
            );
          },
        ),
      ],
    );
  }
}
