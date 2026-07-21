import 'package:flutter/material.dart';
import 'registroTrabajador.dart';
import 'completar_perfil.dart';

class MenuPerfilWidget extends StatelessWidget {
  const MenuPerfilWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F52BA);
    final textColor = const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Sobre mí'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Configuración de tu cuenta',
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.w800, 
                  color: textColor,
                ),
              ),
              const SizedBox(height: 32),

              _buildActionCard(
                context,
                titulo: 'Crear perfil profesional',
                subtitulo: 'Activá tu tarjeta digital para ofrecer servicios y definir tus zonas de cobertura.',
                icono: Icons.work_outline_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegistroTrabajadorWidget()),
                ),
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                context,
                titulo: 'Mis datos personales',
                subtitulo: 'Actualizá tu dirección, documento y foto para validar tu identidad.',
                icono: Icons.person_outline_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CompletarPerfilWidget()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String titulo, required String subtitulo, required IconData icono, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: const Color(0xFF0F52BA), size: 28),
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
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
