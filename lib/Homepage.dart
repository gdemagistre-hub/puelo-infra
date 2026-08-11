import 'package:flutter/material.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'menuPerfilOpciones.dart';
import 'tarjetaDigital.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'catalogo_oficios.dart';

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
    final forzado = widget.initialModoPrestador;
    final modo = forzado ?? esPrestador;
    setState(() {
      _puedeSerAmbos = esPrestador;
      _modoPrestador = modo;
    });
  }

  String _getInitials() {
    final nombreCompleto = UserSession().nombreCompleto.trim();
    if (nombreCompleto.isEmpty) return 'U';
    final partes = nombreCompleto.split(' ');
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    return partes[0][0].toUpperCase();
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

  void _onSearchChanged(String value) {
    final list = CatalogoOficios.sugerencias(value, limit: 8);
    setState(() => _sugerencias = list);
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
    _searchCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchCtrl.text.length),
    );
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

  @override
  Widget build(BuildContext context) {
    final onHome = _currentIndex == 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: onHome ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _currentIndex == 1 ? 'Evaluar' : 'Perfil',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 18),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.star_outline_rounded, 'Evaluar'),
              _navItem(2, Icons.person_rounded, 'Perfil'),
            ],
          ),
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
          decoration: BoxDecoration(
            color: selected ? primaryColor.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryColor, primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.35)),
                        ),
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    alignment: Alignment.center,
                    child: Text(_getInitials(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClienteHome() {
    return CustomScrollView(
      slivers: [
        Sli verToBoxAdapter(
          child: _buildBrandHeader(subtitle: '¿Qué servicio necesitás hoy?'),
        ),
        // Campo de búsqueda tipeable + typeahead de oficios
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: _submitBusqueda,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: '¿Qué servicio necesitás?',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(Icons.search_rounded, color: _clientePrimary, size: 24),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                color: const Color(0xFF94A3B8),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _sugerencias = []);
                                },
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                if (_sugerencias.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white,
                    elevation: 3,
                    shadowColor: Colors.black.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sugerencias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, i) {
                        final e = _sugerencias[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(CatalogoOficios.iconFor(e.id), color: _clientePrimary, size: 22),
                          title: Text(
                            e.label,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                          subtitle: e.sinonimos.isEmpty
                              ? null
                              : Text(
                                  e.sinonimos.take(3).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                          trailing: const Icon(Icons.north_west_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onTap: () => _elegirSugerencia(e),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Oficios', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ),
        ),
        Sli verToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categorias.length,
              gridDelegate: const Sli verGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final Color accent = (cat['color'] as Color?) ?? _clientePrimary;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
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
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(cat['icon'] as IconData, color: accent, size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['label'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), height: 1.15),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Material(
              borderRadius: BorderRadius.circular(20),
              elevation: 4,
              shadowColor: _clientePrimary.withOpacity(0.30),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _abrirBuscador(),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: [_clientePrimary, _clienteDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prestadores con más confianza', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.25)),
                            const SizedBox(height: 6),
                            Text('Ordenados por zona y calificación', style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Text('Ver ranking →', style: TextStyle(color: _clientePrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 34),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Sli verToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildPrestadorHome() {
    return CustomScrollView(
      slivers: [
        Sli verToBoxAdapter(child: _buildBrandHeader(subtitle: 'Tu perfil profesional en Puelo')),
        Sli verToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                borderRadius: BorderRadius.circular(22),
                elevation: 8,
                shadowColor: _prestadorPrimary.withOpacity(0.40),
                child: InkWell(
                  onTap: _compartirTarjeta,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(colors: [_prestadorPrimary, _prestadorDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 34),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tu tarjeta digital', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.2)),
                              SizedBox(height: 4),
                              Text('Compartila y que te contacten', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                        const Icon(Icons.ios_share_rounded, color: Colors.white, size: 26),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Sli verToBoxAdapter(child: SizedBox(height: 28)),
        Sli verToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              elevation: 1.5,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: _prestadorPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.how_to_reg_outlined, color: _prestadorPrimary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pedí que validen quién sos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                            SizedBox(height: 2),
                            Text('Un conocido confirma tu perfil · suma confianza', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Sli verToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}
