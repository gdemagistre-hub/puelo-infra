import 'package:flutter/material.dart';

/// Limita el ancho de contenido en desktop/web ancho (Sprint 2).
class ResponsiveShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveShell({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth + 48) {
          return child;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
