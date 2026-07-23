import 'package:flutter/material.dart';
import 'datosPersonalesflotante.dart';
import 'Domicilioflotante.dart';
import 'especialidadesLaboralesflotante.dart';
import 'ZonaDeTrabajoflotante.dart';
import 'perfilCompletoflotante.dart';

class MenuPerfilOpcionesWidget extends StatelessWidget {
  final VoidCallback? onClose;

  const MenuPerfilOpcionesWidget({
    super.key,
    this.onClose,
  });

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

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F52BA);
    final textColor = const Color(0xFF1E293B);

    final items = [
      _MenuItem(
        icon: Icons.person_outline_rounded,
        label: 'Datos personales',
        onTap: () => _abrirFlotante(context, const DatosPersonalesFlotanteWidget()),
      ),
      _MenuItem(
        icon: Icons.home_work_outlined,
        label: 'Domicilio',
        onTap: () => _abrirFlotante(context, const DomicilioFlotanteWidget()),
      ),
      _MenuItem(
        icon: Icons.work_outline_rounded,
        label: 'Especialidades laborales',
        onTap: () => _abrirFlotante(context, const EspecialidadesLaboralesFlotanteWidget()),
      ),
      _MenuItem(
        icon: Icons.map_outlined,
        label: 'Zona de trabajo preferida',
        onTap: () => _abrirFlotante(context, const ZonaDeTrabajoFlotanteWidget()),
      ),
      _MenuItem(
        icon: Icons.badge_outlined,
        label: 'Mi perfil completo',
        onTap: () => _abrirFlotante(context, const PerfilCompletoFlotanteWidget()),
      ),
    ];

    return Container(
      color: Colors.white,
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Mi perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 56,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Icon(item.icon, color: textColor, size: 26),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: primaryColor.withOpacity(0.7),
                    size: 26,
                  ),
                  onTap: item.onTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
