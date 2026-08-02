import 'package:flutter/material.dart';
import 'cargaTrabajoCliente.dart';
import 'cargaTrabajoTrabajador.dart';
import 'proximamente.dart';
import 'user_session.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';

class MenuEvaluacionesWidget extends StatelessWidget {
  /// Si true, se muestra dentro del Home y se mantiene la bottom nav.
  final bool embedded;

  const MenuEvaluacionesWidget({super.key, this.embedded = false});

  bool get _esPrestador {
    final data = UserSession().datosCompletos;
    return data?['es_trabajador'] == true || data?['rol'] == 'trabajador';
  }

  @override
  Widget build(BuildContext context) {
    final esPrestador = _esPrestador;
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (embedded) ...[
            const Text(
              'Evaluar',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            AppCopy.ctaCalificar,
            style: TextStyle(
              fontSize: embedded ? 16 : 22,
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
          const _SectionLabel(
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
            const _SectionLabel(
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
                  builder: (context) => const CargaTrabajoTrabajadorWidget(),
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
          const SizedBox(height: 24),
        ],
      ),
    );

    if (embedded) {
      return ColoredBox(color: AppColors.bg, child: content);
    }

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
      body: SafeArea(child: content),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
