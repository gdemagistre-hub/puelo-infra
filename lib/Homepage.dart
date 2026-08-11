import 'package:flutter/material.dart';
import 'user_session.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'menuPerfilOpciones.dart';
import 'tarjetaDigital.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Color get primaryColor => _modoPrestador ? _prestadorPrimary : _clientePrimary;
  Color get primaryDark => _modoPrestador ? _prestadorDark : _clienteDark;

  @override
  void initState() {
    super.initState();
    final data = UserSession().datosCompletos;
    final esPrestador = data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
    final forzado = widget.initialModoPrestador;
    setState(() {
      _puedeSerAmbos = esPrestador;
      _modoPrestador = forzado ?? esPrestador;
    });
  }

  String get _nombreMostrar {
    final n = UserSession().nombreCompleto.trim();
    if (n.isEmpty) return 'Usuario';
    return n.split(' ').first;
  }

  void _abrirBuscador({String? oficio}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuscadorPrestadoresWidget(initialQuery: oficio)),
    );
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
              title: Text(
                _currentIndex == 1 ? 'Evaluar' : 'Perfil',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800),
              ),
            ),
      body: _currentIndex == 1
          ? const MenuEvaluacionesWidget(embedded: true)
          : _currentIndex == 2
              ? MenuPerfilOpcionesWidget(
                  modoPrestador: _modoPrestador,
                  onClose: () => setState(() => _currentIndex = 0),
                )
              : (_modoPrestador ? _buildPrestadorHome() : _buildClienteHome()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _nav(0, Icons.home_rounded, 'Home'),
            _nav(1, Icons.star_outline_rounded, 'Evaluar'),
            _nav(2, Icons.person_rounded, 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _nav(int i, IconData icon, String label) {
    final sel = _currentIndex == i;
    return InkWell(
      onTap: () => setState(() => _currentIndex = i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: sel ? primaryColor : const Color(0xFF94A3B8)),
          Text(label, style: TextStyle(fontSize: 11, color: sel ? primaryColor : const Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _header(String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryColor, primaryDark]),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, $_nombreMostrar', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                ],
              ),
            ),
            if (_puedeSerAmbos)
              GestureDetector(
                onTap: () => setState(() => _modoPrestador = !_modoPrestador),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text(_modoPrestador ? 'Ofrezco' : 'Busco', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteHome() {
    return ListView(
      children: [
        _header('¿Qué servicio necesitás hoy?'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _abrirBuscador(),
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: Color(0xFF734BE4)),
                    SizedBox(width: 12),
                    Text('¿Qué servicio necesitás?', style: TextStyle(color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            borderRadius: BorderRadius.circular(20),
            color: _clientePrimary,
            child: InkWell(
              onTap: () => _abrirBuscador(),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Prestadores con más confianza', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrestadorHome() {
    return ListView(
      children: [
        _header('Tu perfil profesional en Puelo'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            borderRadius: BorderRadius.circular(22),
            color: _prestadorPrimary,
            elevation: 6,
            child: InkWell(
              onTap: _compartirTarjeta,
              borderRadius: BorderRadius.circular(22),
              child: const Padding(
                padding: EdgeInsets.all(22),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 34),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tu tarjeta digital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                          SizedBox(height: 4),
                          Text('Compartila y que te contacten', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
