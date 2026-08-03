import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'Homepage.dart';
import 'theme/app_colors.dart';
import 'scoring_service.dart';

class PantallaGraciasValidacionWidget extends StatefulWidget {
  const PantallaGraciasValidacionWidget({super.key});

  @override
  State<PantallaGraciasValidacionWidget> createState() =>
      _PantallaGraciasValidacionWidgetState();
}

class _PantallaGraciasValidacionWidgetState
    extends State<PantallaGraciasValidacionWidget> {
  final db = FirebaseFirestore.instance;

  static const Color primaryColor = AppColors.cliente;
  static const Color textColor = AppColors.text;

  bool _procesando = true;
  String _nombreTarget = 'la persona';

  @override
  void initState() {
    super.initState();
    _procesarYMostrar();
  }

  Future<void> _procesarYMostrar() async {
    final token = UserSession().pendingValidacionToken;
    if (token == null || UserSession().uid == null) {
      setState(() => _procesando = false);
      return;
    }

    try {
      final pendRef = db.collection('validaciones').doc(token);
      final pendSnap = await pendRef.get();

      if (pendSnap.exists) {
        final pend = pendSnap.data()!;
        _nombreTarget = pend['targetNombre'] ?? 'la persona';

        if (pend['estado'] == 'pendiente') {
          final String targetUserId = pend['targetUserId'] ?? '';
          final String validadorId = UserSession().uid!;

          // Anti-granja: límites de emisión de validaciones
          final valSnap = await db.collection('usuarios').doc(validadorId).get();
          final valData = valSnap.data() ?? {};
          final gate = ScoringService.canEmitirValidacion(valData);
          if (!gate.allowed) {
            await pendRef.update({
              'estado': 'rechazado_limite',
              'motivo_rechazo': gate.reason,
              'procesado_en': FieldValue.serverTimestamp(),
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(gate.reason), duration: const Duration(seconds: 6)),
              );
            }
          } else {
            await pendRef.update({
              'validadorId': validadorId,
              'estado': 'completado',
              'procesado_en': FieldValue.serverTimestamp(),
            });

            if (targetUserId.isNotEmpty) {
              final Map<String, dynamic> registro = {
                'validadorId': validadorId,
                'validador_id': validadorId,
                'conoce': pend['conoce'] ?? false,
                'domicilioSeleccionado': pend['domicilioSeleccionado'] ?? '',
                'esCorrecto': pend['esCorrecto'] ?? false,
                'tiempoViviendo': pend['tiempoViviendo'] ?? '',
                'fecha': FieldValue.serverTimestamp(),
                'tipo': 'identidad',
              };

              await db.collection('usuarios').doc(targetUserId).update({
                'validaciones_recibidas': FieldValue.arrayUnion([registro]),
              });

              await db.collection('usuarios').doc(validadorId).update({
                'validaciones_emitidas_count': FieldValue.increment(1),
                'validaciones_emitidas': FieldValue.arrayUnion([
                  {
                    'target_id': targetUserId,
                    'token': token,
                    'fecha': DateTime.now().toIso8601String(),
                  }
                ]),
                'ultima_validacion_emitida_en': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error procesando validación: $e');
    }

    UserSession().clearPendingValidacion();
    if (mounted) setState(() => _procesando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: _procesando
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      SizedBox(height: 20),
                      Text(
                        'Guardando tu ayuda…',
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 80,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '¡Gracias!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tu respuesta ayuda a que otros confíen en $_nombreTarget.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomePageWidget(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Ir al inicio',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
