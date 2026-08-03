import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
    final validadorId = UserSession().uid;
    if (token == null || validadorId == null) {
      if (mounted) setState(() => _procesando = false);
      return;
    }

    try {
      final uri = Uri.parse(
        'https://southamerica-east1-lifewalletpuelo.cloudfunctions.net/aplicarValidacionPendiente',
      );
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'validadorId': validadorId,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200) {
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final n = data['targetNombre'] as String?;
          if (n != null && n.isNotEmpty) _nombreTarget = n;
        } catch (_) {}
      } else if (resp.statusCode == 403) {
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final reason = data['reason'] as String?;
          if (reason != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(reason),
                duration: const Duration(seconds: 6),
              ),
            );
          }
        } catch (_) {}
      } else {
        debugPrint('aplicarValidacion HTTP ${resp.statusCode}: ${resp.body}');
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
