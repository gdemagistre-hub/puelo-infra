import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'Homepage.dart';

class PantallaGraciasValidacionWidget extends StatefulWidget {
  const PantallaGraciasValidacionWidget({super.key});

  @override
  State<PantallaGraciasValidacionWidget> createState() => _PantallaGraciasValidacionWidgetState();
}

class _PantallaGraciasValidacionWidgetState extends State<PantallaGraciasValidacionWidget> {
  final db = FirebaseFirestore.instance;
  final primaryColor = const Color(0xFF0F52BA);
  final textColor = const Color(0xFF1E293B);

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
      final pendRef = db.collection('validaciones_pendientes').doc(token);
      final pendSnap = await pendRef.get();

      if (pendSnap.exists) {
        final pend = pendSnap.data()!;
        _nombreTarget = pend['targetNombre'] ?? 'la persona';

        if (pend['estado'] == 'pendiente') {
          final String targetUserId = pend['targetUserId'] ?? '';
          final String validadorId = UserSession().uid!;

          await pendRef.update({
            'validadorId': validadorId,
            'estado': 'completado',
            'procesado_en': FieldValue.serverTimestamp(),
          });

          if (targetUserId.isNotEmpty) {
            final Map<String, dynamic> registro = {
              'validadorId': validadorId,
              'conoce': pend['conoce'] ?? false,
              'domicilioSeleccionado': pend['domicilioSeleccionado'] ?? '',
              'esCorrecto': pend['esCorrecto'] ?? false,
              'tiempoViviendo': pend['tiempoViviendo'] ?? '',
              'fecha': FieldValue.serverTimestamp(),
            };

            await db.collection('usuarios').doc(targetUserId).update({
              'validaciones_recibidas': FieldValue.arrayUnion([registro]),
            });
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: _procesando
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 20),
                      Text('Procesando tu colaboración...', style: TextStyle(color: textColor)),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 80, color: Color(0xFF25D366)),
                      const SizedBox(height: 24),
                      Text(
                        'Su información fue recibida',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Gracias por su colaboración con $_nombreTarget.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const HomePageWidget()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Ir al inicio', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
