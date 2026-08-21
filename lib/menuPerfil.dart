import 'package:flutter/material.dart';
import 'registroTrabajador.dart';
import 'datosPersonalesflotante.dart';
import 'solicitar_validacion.dart';
import 'theme/app_colors.dart';

class MenuPerfilWidget extends StatelessWidget {
  const MenuPerfilWidget({super.key});

  static const Color _primary = AppColors.prestador;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Sobre mí'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tu perfil en PROX',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Definí qué servicios ofrecés, cargá tus datos y pedí que te validen. '
                'Así los clientes confían más en vos.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              _buildActionCard(
                titulo: 'Mis servicios y zona',
                subtitulo:
                    'Qué oficios hacés, dónde trabajás y tu tarjeta para compartir con clientes.',
                icono: Icons.handyman_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegistroTrabajadorWidget(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                titulo: 'Mis datos personales',
                subtitulo:
                    'Nombre, apellido y teléfono se pueden mostrar al cliente. '
                    'El resto (documento, domicilio completo, etc.) no se comparte: '
                    'sirve para validarte y para que otros vean que tu perfil es confiable.',
                icono: Icons.person_outline_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DatosPersonalesFlotanteWidget(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                titulo: 'Pedir validación del perfil',
                subtitulo:
                    'Pedile a alguien del barrio o de confianza que confirme que te conoce. '
                    'Eso suma mucho a la hora de que te elijan.',
                icono: Icons.verified_user_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SolicitarValidacionWidget(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                color: _primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: _primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
