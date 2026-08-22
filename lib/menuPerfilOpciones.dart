import 'package:flutter/material.dart';

import 'datosPersonalesflotante.dart';
import 'Domicilioflotante.dart';
import 'especialidadesLaboralesflotante.dart';
import 'ZonaDeTrabajoflotante.dart';
import 'capacitacionesflotante.dart';
import 'perfilCompletoflotante.dart';
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
  /// Reinicia y muestra el tour de Home (coach marks).
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
              ? 'Vas a salir del modo prueba.'
              : 'Vas a cerrar tu sesión de PROX.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

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

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      if (!modoPrestador)
        _MenuItem(
          icon: Icons.handyman_outlined,
          label: 'Quiero ofrecer mis servicios',
          subtitle:
              'Cargá oficios y zona en 3 pasos y empezá a que te contacten.',
          destacado: true,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RegistroTrabajadorWidget(),
              ),
            );
            widget.onRolPuedeHaberCambiado?.call();
          },
        ),
      _MenuItem(
        icon: Icons.person_outline_rounded,
        label: 'Mis datos personales',
        subtitle:
            'Nombre, apellido y teléfono se pueden mostrar al cliente. '
            'El resto no se comparte: sirve para validarte y generar confianza.',
        onTap: () => _abrirFlotante(
          context,
          DatosPersonalesFlotanteWidget(modoPrestador: modoPrestador),
        ),
      ),
      _MenuItem(
        icon: Icons.home_outlined,
        label: 'Domicilio',
        subtitle:
            'Tu dirección completa no se muestra al cliente; se usa para '
            'validaciones y para priorizar búsquedas cercanas.',
        onTap: () => _abrirFlotante(
          context,
          DomicilioFlotanteWidget(modoPrestador: modoPrestador),
        ),
      ),
      if (modoPrestador) ...[
        _MenuItem(
          icon: Icons.handyman_outlined,
          label: 'Mis servicios y oficios',
          subtitle: 'Qué trabajos ofrecés y cómo te presentás.',
          onTap: () => _abrirFlotante(
            context,
            const EspecialidadesLaboralesFlotanteWidget(),
          ),
        ),
        _MenuItem(
          icon: Icons.map_outlined,
          label: 'Zona de trabajo',
          subtitle: 'Dónde podés atender para que te encuentren cerca.',
          onTap: () =>
              _abrirFlotante(context, const ZonaDeTrabajoFlotanteWidget()),
        ),
        _MenuItem(
          icon: Icons.school_outlined,
          label: 'Preparación y cursos',
          subtitle:
              'Cursos, matrículas o constancias con foto. '
              'Se muestran en tu perfil; no modifican tus distintivos de confianza.',
          onTap: () =>
              _abrirFlotante(context, const CapacitacionesFlotanteWidget()),
        ),
      ],
      _MenuItem(
        icon: Icons.badge_outlined,
        label: 'Mi perfil completo',
        subtitle: 'Resumen de lo que tenés cargado en PROX.',
        onTap: () =>
            _abrirFlotante(context, const PerfilCompletoFlotanteWidget()),
      ),
      if (widget.onRequestHomeTour != null)
        _MenuItem(
          icon: Icons.help_outline_rounded,
          label: 'Guía rápida de la app',
          subtitle:
              'Repetí el recorrido de la primera vez: menú, roles y barra de abajo.',
          onTap: () => _abrirGuiaRapida(context),
        ),
      if (UserSession().isAdmin) ...[
        _MenuItem(
          icon: Icons.account_balance_outlined,
          label: 'Madurez microcrédito',
          subtitle:
              'Tablero de readiness 0–100 y preparación Academia. Solo admin.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReadinessAdminScreen(),
              ),
            );
          },
        ),
        _MenuItem(
          icon: Icons.monitor_heart_outlined,
          label: 'Consola Prox',
          subtitle:
              'Monitoreo de pantallas, demoras y abandono. Solo operadores.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConsolaProxWidget()),
            );
          },
        ),
      ],
      _MenuItem(
        icon: Icons.logout_rounded,
        label: 'Cerrar sesión',
        subtitle: UserSession().isDevImpersonation
            ? 'Salir del modo prueba'
            : 'Cerrar sesión de Google / cuenta',
        onTap: () => _cerrarSesion(context),
      ),
    ];

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
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    modoPrestador
                        ? 'Mi perfil · Prestador'
                        : 'Mi perfil · Cliente',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              modoPrestador
                  ? 'Completá tus datos, servicios y zona. Así los clientes confían más en vos.'
                  : 'Tus datos ayudan a contactarte. Si ofrecés un oficio, tocá “Quiero ofrecer mis servicios”.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                // Legales va justo antes de Cerrar sesión (último item).
                if (index == items.length - 1) {
                  return _buildLegalesCard();
                }
                final itemIndex =
                    index == items.length ? items.length - 1 : index;
                return _buildCard(items[itemIndex]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalesCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _legalesAbierto = !_legalesAbierto),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.gavel_outlined,
                        color: primaryColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Legales',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Términos, privacidad y buenas prácticas.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _legalesAbierto
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.grey.shade400,
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
                    icon: Icons.description_outlined,
                    label: 'Términos y Condiciones',
                    subtitle: 'Uso de la app y gratuidad de esta etapa.',
                    tipo: TipoDocumentoLegal.terminos,
                  ),
                  Divider(height: 1, indent: 62, color: Colors.grey.shade200),
                  _legalRow(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacidad e identidad',
                    subtitle: 'Qué datos usamos y qué nunca se publica.',
                    tipo: TipoDocumentoLegal.privacidad,
                  ),
                  Divider(height: 1, indent: 62, color: Colors.grey.shade200),
                  _legalRow(
                    icon: Icons.handshake_outlined,
                    label: 'Buenas prácticas',
                    subtitle: 'Cómo nos tratamos en la red de confianza.',
                    tipo: TipoDocumentoLegal.buenasPracticas,
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

  Widget _legalRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required TipoDocumentoLegal tipo,
  }) {
    return InkWell(
      onTap: () => _abrirLegal(context, tipo),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_MenuItem item) {
    final color = item.destacado ? AppColors.prestador : primaryColor;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: item.destacado
                ? Border.all(
                    color: AppColors.prestador.withOpacity(0.45),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: item.destacado
                            ? AppColors.prestador
                            : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destacado;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destacado = false,
  });
}
