import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'menuPerfilOpciones.dart';
import 'tarjetaDigital.dart';
import 'catalogo_oficios.dart';
import 'mis_numeros/mis_numeros_shell.dart';
import 'academia/ui/academia_screen.dart';
import 'mensajes/mensajes_list.dart';
import 'services/fcm_service.dart';

/// Home shell temporal con badge de mensajes.
/// Home rico (oficios/confianza) se repone en el próximo commit.
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
  static const Color _prestadorPrimary = Color(0xFF28B5CD);
  static const Color _misNumerosPrimary = Color(0xFF28B5CD);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  bool _modoPrestador = false;
  bool _puedeSerAmbos = false;

  Color get primaryColor => _modoPrestador ? _prestadorPrimary : _clientePrimary;

  @override
  void initState() {
    super.initState();
    final data = UserSession().datosCompletos;
    final esPrestador = data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
    _puedeSerAmbos = esPrestador;
    _modoPrestador = widget.initialModoPrestador ?? esPrestador;
    FcmService.instance.ensureStarted();
  }

  String get _appBarTitle {
    switch (_currentIndex) {
      case 1: return 'Evaluar';
      case 2: return 'Mis números';
      case 3: return 'Mensajes';
      case 4: return 'Academia';
      default: return '';
    }
  }

  Widget get _tabBody {
    switch (_currentIndex) {
      case 1: return const MenuEvaluacionesWidget(embedded: true);
      case 2: return MisNumerosShell(onBackToHome: () => setState(() => _currentIndex = 0));
      case 3: return const MensajesListScreen(embedded: true);
      case 4: return const AcademiaScreen(embedded: true);
      default:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hola, ${UserSession().nombreCompleto.split(' ').first}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: primaryColor),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Estamos restaurando el Home completo.\nMientras, usá las pestañas de abajo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => setState(() => _currentIndex = 3),
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
                  child: const Text('Ir a Mensajes'),
                ),
              ],
            ),
          ),
        );
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
            onRolPuedeHaberCambiado: () {
              final data = UserSession().datosCompletos;
              final es = data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
              setState(() {
                _puedeSerAmbos = es;
                if (!es) _modoPrestador = false;
              });
            },
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
              title: Text(_appBarTitle, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800)),
            ),
      body: _tabBody,
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
                      ? [_misNumerosPrimary, const Color(0xFF1F9BB0)]
                      : [_misNumerosPrimary, _misNumerosPrimary.withOpacity(0.88)],
                ),
                boxShadow: [BoxShadow(color: _misNumerosPrimary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 2),
            Text('Mis números', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: selected ? _misNumerosPrimary : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

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
              if (d['pending_recibo_event_id'] == null) continue;
              final actor = (d['pending_recibo_actor_uid'] ?? '').toString();
              if (actor.isEmpty || actor != uid) pending++;
            }
          }
          return _navItemContent(3, Icons.chat_bubble_outline_rounded, 'Mensajes', badgeCount: pending);
        },
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, {int badgeCount = 0}) {
    return Expanded(child: _navItemContent(index, icon, label, badgeCount: badgeCount));
  }

  Widget _navItemContent(int index, IconData icon, String label, {int badgeCount = 0}) {
    final selected = _currentIndex == index;
    final showBadge = badgeCount > 0;
    final badgeText = badgeCount > 9 ? '9+' : '$badgeCount';
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
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
                Icon(icon, size: selected ? 24 : 22, color: selected ? primaryColor : const Color(0xFF94A3B8)),
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
                      child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, height: 1.1)),
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
}
