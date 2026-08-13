import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shell de la sección financiera dentro de PROX.
/// Fase 1: navegación + empty-state profesional.
/// El vault cifrado / PIN / stores se integran en una fase posterior.
class MisNumerosShell extends StatelessWidget {
  final VoidCallback? onBackToHome;

  const MisNumerosShell({super.key, this.onBackToHome});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.cliente.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.cliente.withOpacity(0.28),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 42,
                        color: AppColors.cliente,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Mis números',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tu información financiera está cifrada y protegida con PIN. Solo vos podés verla.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.grey.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Módulo financiero en integración',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pronto vas a poder ver movimientos, metas y vencimientos acá, con la misma protección de Puelo Finanzas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onBackToHome != null) ...[
                    const SizedBox(height: 28),
                    Center(
                      child: TextButton.icon(
                        onPressed: onBackToHome,
                        icon: const Icon(Icons.home_outlined, size: 18),
                        label: const Text(
                          'Volver al inicio',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.cliente,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
