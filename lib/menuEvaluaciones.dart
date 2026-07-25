import 'package:flutter/material.dart';
import 'cargaTrabajoCliente.dart';
import 'cargaTrabajoTrabajador.dart';
import 'proximamente.dart';
import 'user_session.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';

class MenuEvaluacionesWidget extends StatelessWidget {
  const MenuEvaluacionesWidget({super.key});

  bool get _esPrestador {
    final data = UserSession().datosCompletos;
    return data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
  }

  @override
  Widget build(BuildContext context) {
    final esPrestador = _esPrestador;
    // Menú mixto: primary cliente (calificar es acción de quien contrata)
    // Si solo hay acciones de prestador, usamos prestador.
    final primary = esPrestador ? AppColors.prestador : AppColors.cliente;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(AppCopy.navEvaluar),
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
              Text(
                AppCopy.ctaCalificar,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                esPrestador
                    ? 'Como prestador también podés mostrar trabajos hechos.'
                    : 'Contá cómo te fue para ayudar a otros a confiar.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),

              // —— Cliente (y también prestador si contrató a alguien) ——
              _SectionLabel(
                label: 'Si contrataste un servicio',
                color: AppColors.cliente,
              ),
              const SizedBox(height: 10),
              _buildActionCard(
                context,
                titulo: 'Calificar al profesional',
                subtitulo: '¿Cómo te fue con el trabajo?',
                icono: Icons.star_outline_rounded,
                accent: AppColors.cliente,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CargaTrabajoClienteWidget(),
                  ),
                ),
              ),

              if (esPrestador) ...[
                const SizedBox(height: 28),
                _SectionLabel(
                  label: 'Si ofrecés servicios',
                  color: AppColors.prestador,
                ),
                const SizedBox(height: 10),
                _buildActionCard(
                  context,
                  titulo: 'Mostrar trabajo realizado',
                  subtitulo: 'Subí fotos de un servicio que brindaste (portfolio).',
                  icono: Icons.photo_camera_back_rounded,
                  accent: AppColors.prestador,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CargaTrabajoTrabajadorWidget(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  context,
                  titulo: 'Evaluar a un cliente',
                  subtitulo: AppCopy.ctaProximamente,
                  icono: Icons.how_to_reg_rounded,
                  accent: AppColors.prestador,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProximamenteWidget(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color accent,
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: accent, size: 28),
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
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
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
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: color,
      ),
    );
  }
}
