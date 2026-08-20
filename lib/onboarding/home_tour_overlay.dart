import 'package:flutter/material.dart';

/// Paso del tour contextual sobre el Home.
class HomeTourStep {
  final String title;
  final String body;
  /// Zona aproximada del acento visual (0–1 relativo a pantalla útil).
  final Alignment highlightAlign;
  final double highlightWidthFactor;
  final double highlightHeightFactor;

  const HomeTourStep({
    required this.title,
    required this.body,
    this.highlightAlign = Alignment.center,
    this.highlightWidthFactor = 0.55,
    this.highlightHeightFactor = 0.12,
  });
}

List<HomeTourStep> tourStepsFor({required bool modoPrestador}) {
  if (modoPrestador) {
    return const [
      HomeTourStep(
        title: 'Tu menú',
        body:
            'Acá configurás tu perfil, datos y preferencias. Todo lo importante de tu cuenta vive en este menú.',
        highlightAlign: Alignment(-0.92, -0.78),
        highlightWidthFactor: 0.22,
        highlightHeightFactor: 0.08,
      ),
      HomeTourStep(
        title: 'Ofrezco / Busco',
        body:
            'Con este botón cambiás entre tu perfil de prestador y el de cliente, cuando necesitás los dos.',
        highlightAlign: Alignment(0.55, -0.78),
        highlightWidthFactor: 0.32,
        highlightHeightFactor: 0.08,
      ),
      HomeTourStep(
        title: 'Tu tarjeta digital',
        body:
            'Es tu presentación para enviar a clientes. Es la misma que ellos ven cuando te encuentran buscando un servicio.',
        highlightAlign: Alignment(0, -0.12),
        highlightWidthFactor: 0.9,
        highlightHeightFactor: 0.12,
      ),
      HomeTourStep(
        title: 'Home',
        body:
            'Desde cualquier sección, tocá Home para volver a esta pantalla.',
        highlightAlign: Alignment(-0.72, 0.92),
        highlightWidthFactor: 0.18,
        highlightHeightFactor: 0.09,
      ),
      HomeTourStep(
        title: 'Mis números',
        body:
            'Gestioná cobros, gastos y tu bolsillo desde acá, de forma privada.',
        highlightAlign: Alignment(0, 0.9),
        highlightWidthFactor: 0.22,
        highlightHeightFactor: 0.12,
      ),
      HomeTourStep(
        title: 'Academia',
        body:
            'Tips cortos de microfinanzas y oficio. Siempre hay algo para aprender.',
        highlightAlign: Alignment(0.78, 0.92),
        highlightWidthFactor: 0.18,
        highlightHeightFactor: 0.09,
      ),
    ];
  }

  return const [
    HomeTourStep(
      title: 'Tu menú',
      body:
          'Configurá tu perfil y domicilio. Tu zona ayuda a mostrar prestadores de donde vivís.',
      highlightAlign: Alignment(-0.92, -0.78),
      highlightWidthFactor: 0.22,
      highlightHeightFactor: 0.08,
    ),
    HomeTourStep(
      title: 'Pantalla de cliente',
      body:
          'Esta es tu vista para buscar servicios. Elegí un oficio o escribí lo que necesitás.',
      highlightAlign: Alignment(0, -0.55),
      highlightWidthFactor: 0.9,
      highlightHeightFactor: 0.14,
    ),
    HomeTourStep(
      title: 'Más confianza',
      body:
          'Desde acá buscás prestadores mejor evaluados en tu zona, ordenados por reputación.',
      highlightAlign: Alignment(0, 0.35),
      highlightWidthFactor: 0.9,
      highlightHeightFactor: 0.14,
    ),
    HomeTourStep(
      title: 'Barra de abajo',
      body:
          'Home te trae de vuelta. Evaluar, Mis números, Mensajes y Academia están siempre a un toque.',
      highlightAlign: Alignment(0, 0.92),
      highlightWidthFactor: 0.95,
      highlightHeightFactor: 0.1,
    ),
  ];
}

/// Overlay de coach-marks (primera vez). No bloquea el layout del Home.
class HomeTourOverlay extends StatefulWidget {
  final bool modoPrestador;
  final Color accent;
  final VoidCallback onFinished;

  const HomeTourOverlay({
    super.key,
    required this.modoPrestador,
    required this.accent,
    required this.onFinished,
  });

  @override
  State<HomeTourOverlay> createState() => _HomeTourOverlayState();
}

class _HomeTourOverlayState extends State<HomeTourOverlay> {
  int _i = 0;

  List<HomeTourStep> get _steps =>
      tourStepsFor(modoPrestador: widget.modoPrestador);

  void _next() {
    if (_i >= _steps.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() => _i++);
  }

  void _skip() => widget.onFinished();

  @override
  Widget build(BuildContext context) {
    final step = _steps[_i];
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);

    // Área útil (sin status bar) para alinear highlights.
    final usable = Size(size.width, size.height - pad.top);
    final hx = (step.highlightAlign.x + 1) / 2 * usable.width -
        (usable.width * step.highlightWidthFactor) / 2;
    final hy = pad.top +
        (step.highlightAlign.y + 1) / 2 * usable.height -
        (usable.height * step.highlightHeightFactor) / 2;
    final hw = usable.width * step.highlightWidthFactor;
    final hh = usable.height * step.highlightHeightFactor;

    final cardBelow = step.highlightAlign.y < 0.2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Scrim + “agujero” suave (borde redondeado iluminado).
          CustomPaint(
            painter: _SpotlightPainter(
              hole: Rect.fromLTWH(
                hx.clamp(8.0, size.width - 16),
                hy.clamp(pad.top + 4, size.height - 40),
                hw.clamp(48.0, size.width - 16),
                hh.clamp(40.0, 120.0),
              ),
              accent: widget.accent,
            ),
            size: size,
          ),

          // Card del paso
          Positioned(
            left: 20,
            right: 20,
            top: cardBelow
                ? (hy + hh + 16).clamp(pad.top + 80, size.height - 220)
                : null,
            bottom: cardBelow ? null : (size.height - hy + 12).clamp(90.0, size.height * 0.45),
            child: _TourCard(
              accent: widget.accent,
              stepIndex: _i,
              total: _steps.length,
              title: step.title,
              body: step.body,
              onNext: _next,
              onSkip: _skip,
              isLast: _i == _steps.length - 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  final Color accent;
  final int stepIndex;
  final int total;
  final String title;
  final String body;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  const _TourCard({
    required this.accent,
    required this.stepIndex,
    required this.total,
    required this.title,
    required this.body,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${stepIndex + 1} / $total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Saltar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isLast ? 'Listo, empecemos' : 'Siguiente',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect hole;
  final Color accent;

  _SpotlightPainter({required this.hole, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(14)));
    final path = Path.combine(PathOperation.difference, scrim, cut);

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withOpacity(0.58),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(hole.inflate(2), const Radius.circular(16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = accent.withOpacity(0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.accent != accent;
}
