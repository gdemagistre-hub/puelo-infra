import 'package:flutter/material.dart';

import 'datosPersonalesflotante.dart';
import 'Domicilioflotante.dart';
import 'especialidadesLaboralesflotante.dart';
import 'ZonaDeTrabajoflotante.dart';
import 'capacitacionesflotante.dart';
import 'registroTrabajador.dart';
import 'consola_prox.dart';
import 'admin/readiness_admin_screen.dart';
import 'user_session.dart';
import 'auth_service.dart';
import 'loginScreen.dart';
import 'onboarding/home_tour_service.dart';
import 'theme/app_colors.dart';
import 'legales/documento_legal_screen.dart';
import 'legales/textos_legales.dart';

class MenuPerfilOpcionesWidget extends StatefulWidget {
  final VoidCallback? onClose;
  final bool modoPrestador;
  final VoidCallback? onRolPuedeHaberCambiado;
  final VoidCallback? onRequestHomeTour;

  const MenuPerfilOpcionesWidget({
    super.key,
    this.onClose,
    this.modoPrestador = false,
    this.onRolPuedeHaberCambiado,
    this.onRequestHomeTour,
  });

  @override
  State<MenuPerfilOpcionesWidget> createState() =>
      _MenuPerfilOpcionesWidgetState();
}

class _MenuPerfilOpcionesWidgetState extends State<MenuPerfilOpcionesWidget> {
  bool _legalesAbierto = false;

  bool get modoPrestador => widget.modoPrestador;

  Color get primaryColor =>
      modoPrestador ? AppColors.prestador : AppColors.cliente;

  void _abrirFlotante(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: Curves.easeOutCubic),
          );
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _abrirLegal(BuildContext context, TipoDocumentoLegal tipo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentoLegalScreen(
          tipo: tipo,
          modoPrestador: modoPrestador,
        ),
      ),
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: Text(
          UserSession().isDevImpersonation
              ? '¿Salir del modo prueba?'
              : '¿Cerrar sesión de tu cuenta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreenWidget()),
      (_) => false,
    );
  }

  Future<void> _abrirGuiaRapida(BuildContext context) async {
    await HomeTourService.instance.reset(modoPrestador: modoPrestador);
    widget.onClose?.call();
    widget.onRequestHomeTour?.call();
  }

  Future<void> _irAOfrecerServicios(BuildContext context) async {
    final s = UserSession();
    s.datosCompletos = {
      ...(s.datosCompletos ?? {}),
      'es_trabajador': true,
      'rol': 'trabajador',
      'camino_elegido': 'ofrezo',
    };
    s.invalidateHomeCache();
    await s.persistHomeModoPrestador(true);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RegistroTrabajadorWidget(),
      ),
    );
    widget.onRolPuedeHaberCambiado?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = UserSession().isAdmin;

    return Container(
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final full = UserSession().nombreCompleto.trim();
                      final first = full.isEmpty
                          ? ''
                          : full.split(RegExp(r'\s+')).first;
                      final rol = modoPrestador ? 'Prestador' : 'Cliente';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (first.isNotEmpty)
                            Text(
                              first,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                          Text(
                            rol,
                            style: TextStyle(
                              fontSize: first.isEmpty ? 18 : 13,
                              fontWeight: first.isEmpty
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: first.isEmpty
                                  ? AppColors.text
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    color: Colors.grey.shade600,
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                _sectionLabel('Cuenta'),
                _sectionCard([
                  _row(
                    icon: Icons.person_outline_rounded,
                    label: 'Mis datos',
                    onTap: () => _abrirFlotante(
                      context,
                      DatosPersonalesFlotanteWidget(
                        modoPrestador: modoPrestador,
                      ),
                    ),
                  ),
                  _row(
                    icon: Icons.home_outlined,
                    label: 'Domicilio',
                    onTap: () => _abrirFlotante(
                      context,
                      DomicilioFlotanteWidget(modoPrestador: modoPrestador),
                    ),
                  ),
                ]),
                if (!modoPrestador) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('Prestador'),
                  _ctaOfrecerServicios(context),
                ],
                if (modoPrestador) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('Mi trabajo'),
                  _sectionCard([
                    _row(
                      icon: Icons.handyman_outlined,
                      label: 'Mis servicios',
                      onTap: () => _abrirFlotante(
                        context,
                        const EspecialidadesLaboralesFlotanteWidget(),
                      ),
                    ),
                    _row(
                      icon: Icons.map_outlined,
                      label: 'Zona de trabajo',
                      onTap: () => _abrirFlotante(
                        context,
                        const ZonaDeTrabajoFlotanteWidget(),
                      ),
                    ),
                    _row(
                      icon: Icons.school_outlined,
                      label: 'Cursos',
                      onTap: () => _abrirFlotante(
                        context,
                        const CapacitacionesFlotanteWidget(),
                      ),
                    ),
                  ]),
                ],
                if (widget.onRequestHomeTour != null) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('Ayuda'),
                  _sectionCard([
                    _row(
                      icon: Icons.help_outline_rounded,
                      label: 'Guía rápida',
                      onTap: () => _abrirGuiaRapida(context),
                    ),
                  ]),
                ],
                const SizedBox(height: 16),
                _sectionLabel('Legal'),
                _legalesBlock(),
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('Admin'),
                  _sectionCard([
                    _row(
                      icon: Icons.account_balance_outlined,
                      label: 'Madurez microcrédito',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReadinessAdminScreen(),
                          ),
                        );
                      },
                    ),
                    _row(
                      icon: Icons.monitor_heart_outlined,
                      label: 'Consola Prox',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ConsolaProxWidget(),
                          ),
                        );
                      },
                    ),
                  ]),
                ],
                const SizedBox(height: 32),
                _sectionCard([
                  _row(
                    icon: Icons.logout_rounded,
                    label: 'Cerrar sesión',
                    danger: true,
                    onTap: () => _cerrarSesion(context),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctaOfrecerServicios(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _irAOfrecerServicios(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.prestador.withOpacity(0.55),
              width: 1.5,
            ),
            color: AppColors.prestador.withOpacity(0.06),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.prestador.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.handyman_outlined,
                  color: AppColors.prestador,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ofrecer servicios',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.prestador,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.prestador.withOpacity(0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) {
        children.add(Divider(
          height: 1,
          indent: 56,
          color: Colors.grey.shade200,
        ));
      }
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destacado = false,
    bool danger = false,
  }) {
    final color = danger
        ? Colors.red.shade700
        : (destacado ? AppColors.prestador : primaryColor);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: danger
                      ? Colors.red.shade700
                      : (destacado ? AppColors.prestador : AppColors.text),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _legalesBlock() {
    final muted = Colors.grey.shade600;
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _legalesAbierto = !_legalesAbierto),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.gavel_outlined,
                        color: muted,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Documentos legales',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ),
                    Icon(
                      _legalesAbierto
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                children: [
                  Divider(height: 1, color: Colors.grey.shade200),
                  _legalRow(
                    'Términos y condiciones',
                    TipoDocumentoLegal.terminos,
                  ),
                  Divider(
                      height: 1, indent: 48, color: Colors.grey.shade200),
                  _legalRow(
                    'Privacidad',
                    TipoDocumentoLegal.privacidad,
                  ),
                  Divider(
                      height: 1, indent: 48, color: Colors.grey.shade200),
                  _legalRow(
                    'Buenas prácticas',
                    TipoDocumentoLegal.buenasPracticas,
                  ),
                ],
              ),
              crossFadeState: _legalesAbierto
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legalRow(String label, TipoDocumentoLegal tipo) {
    return InkWell(
      onTap: () => _abrirLegal(context, tipo),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            const SizedBox(width: 44),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}
