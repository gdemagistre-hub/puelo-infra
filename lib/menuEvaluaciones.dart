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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
            const SizedBox(height: 6),
          ],
          Text(
            AppCopy.ctaCalificar,
            style: TextStyle(
              fontSize: embedded ? 17 : 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            esPrestador
                ? 'Como prestador también podés mostrar trabajos hechos.'
                : 'Contá cómo te fue para ayudar a otros a confiar.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // —— Cliente: acción primaria con más peso visual ——
          const _SectionLabel(
            label: 'Si contrataste un servicio',
            color: AppColors.cliente,
          ),
          const SizedBox(height: 12),
          _PrimaryActionCard(
            titulo: 'Calificar al profesional',
            subtitulo:
                '¿Cómo te fue con el trabajo? Tu opinión ayuda a otros a elegir con más confianza.',
            icono: Icons.star_rounded,
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
            const SizedBox(height: 12),
            _ActionCard(
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
            const SizedBox(height: 12),
            _ActionCard(
              titulo: 'Evaluar a un cliente',
              subtitulo: AppCopy.ctaProximamente,
              icono: Icons.how_to_reg_rounded,
              accent: AppColors.prestador,
              muted: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProximamenteWidget(),
                ),
              ),
            ),
          ],

          // Tip inferior para no dejar la pantalla “vacía”
          if (!esPrestador) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cliente.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.cliente.withOpacity(0.12),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: AppColors.cliente,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Las estrellas se publican cuando el prestador responde o a los 7 días. Así ambos lados quedan protegidos.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
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
}

/// Card primaria (más peso): borde izquierdo + icono grande + sombra suave.
class _PrimaryActionCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color accent;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2.5,
      shadowColor: accent.withOpacity(0.18),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border(
              left: BorderSide(color: accent, width: 4),
              top: BorderSide(color: AppColors.border.withOpacity(0.6)),
              right: BorderSide(color: AppColors.border.withOpacity(0.6)),
              bottom: BorderSide(color: AppColors.border.withOpacity(0.6)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 14, 18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: accent.withOpacity(0.7),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card estándar (secundaria).
class _ActionCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color accent;
  final VoidCallback onTap;
  final bool muted;

  const _ActionCard({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.accent,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = muted ? AppColors.textMuted : accent;
    final bgIcon = muted
        ? AppColors.border.withOpacity(0.5)
        : accent.withOpacity(0.12);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black12,
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
                  color: bgIcon,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: muted ? AppColors.textMuted : AppColors.text,
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
