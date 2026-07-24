import 'package:flutter/material.dart';
import 'datosPersonalesflotante.dart';
import 'Domicilioflotante.dart';
import 'especialidadesLaboralesflotante.dart';
import 'ZonaDeTrabajoflotante.dart';
import 'perfilCompletoflotante.dart';

class MenuPerfilOpcionesWidget extends StatelessWidget {
  final VoidCallback? onClose;

  /// true = muestra opciones de prestador; false = solo cliente
  final bool modoPrestador;

  const MenuPerfilOpcionesWidget({
    super.key,
    this.onClose,
    this.modoPrestador = false,
  });

  // Paleta
  static const Color _clientePrimary = Color(0xFF734BE4);
  static const Color _prestadorPrimary = Color(0xFF28B5CD);
  static const Color _textColor = Color(0xFF1E293B);

  Color get primaryColor => modoPrestador ? _prestadorPrimary : _clientePrimary;

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
    // Cliente: solo datos personales, domicilio y perfil completo
    // Prestador: todo
    final items = <_MenuItem>[
      _MenuItem(
        icon: Icons.person_outline_rounded,
        label: 'Datos personales',
        onTap: () =>
            _abrirFlotante(context, const DatosPersonalesFlotanteWidget()),
      ),
      _MenuItem(
        icon: Icons.home_outlined,
        label: 'Domicilio',
        onTap: () => _abrirFlotante(context, const DomicilioFlotanteWidget()),
      ),
      if (modoPrestador) ...[
        _MenuItem(
          icon: Icons.handyman_outlined,
          label: 'Especialidades laborales',
          onTap: () => _abrirFlotante(
            context,
            const EspecialidadesLaboralesFlotanteWidget(),
          ),
        ),
        _MenuItem(
          icon: Icons.map_outlined,
          label: 'Zona de trabajo preferida',
          onTap: () =>
              _abrirFlotante(context, const ZonaDeTrabajoFlotanteWidget()),
        ),
      ],
      _MenuItem(
        icon: Icons.badge_outlined,
        label: 'Mi perfil completo',
        onTap: () =>
            _abrirFlotante(context, const PerfilCompletoFlotanteWidget()),
      ),
    ];

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle del bottom sheet
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

          // Título + cerrar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
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
                      color: _textColor,
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    color: Colors.grey.shade600,
                    onPressed: onClose,
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lista de opciones
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 16,
                      color: _textColor,
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
