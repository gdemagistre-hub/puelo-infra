import 'package:flutter/material.dart';
import 'completar_perfil.dart';
import 'registroTrabajador.dart';
import 'menuPerfil.dart';

class MenuPerfilOpcionesWidget extends StatelessWidget {
  final VoidCallback? onClose;

  const MenuPerfilOpcionesWidget({
    super.key,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F52BA);
    final textColor = const Color(0xFF1E293B);

    final items = [
      _MenuItem(
        icon: Icons.person_outline_rounded,
        label: 'Datos personales',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CompletarPerfilWidget()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.home_work_outlined,
        label: 'Domicilio',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CompletarPerfilWidget()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.work_outline_rounded,
        label: 'Especialidades laborales',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegistroTrabajadorWidget()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.map_outlined,
        label: 'Zona de trabajo preferida',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegistroTrabajadorWidget()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.badge_outlined,
        label: 'Mi perfil completo',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MenuPerfilWidget()),
          );
        },
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
