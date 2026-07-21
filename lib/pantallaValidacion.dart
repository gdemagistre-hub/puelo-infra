import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'loginScreen.dart';
import 'user_session.dart';

class PantallaValidacionWidget extends StatefulWidget {
  final String? token;

  const PantallaValidacionWidget({super.key, this.token});

  @override
  State<PantallaValidacionWidget> createState() => _PantallaValidacionWidgetState();
}

class _PantallaValidacionWidgetState extends State<PantallaValidacionWidget> {
  final db = FirebaseFirestore.instance;
  bool _validando = true;
  bool _exito = false;
  String _mensaje = 'Verificando tu identidad...';

  final primaryColor = const Color(0xFF0F52BA);
  final textColor = const Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _procesarValidacion();
  }

  Future<void> _procesarValidacion() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        _validando = false;
        _exito = false;
        _mensaje = 'Enlace de validación inválido o corrupto.';
      });
      return;
    }

    try {
      final query = await db
          .collection('usuarios')
          .where('token_validacion', isEqualTo: widget.token)
          .where('estado', isEqualTo: 'pendiente_validacion')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          _validando = false;
          _exito = false;
          _mensaje = 'El enlace ya fue utilizado, expiró, o el usuario no existe.';
        });
        return;
      }

      final doc = query.docs.first;
      final docId = doc.id;
      final data = doc.data();

      await db.collection('usuarios').doc(docId).update({
        'estado': 'activo',
        'token_validacion': FieldValue.delete(),
        'validado_en': FieldValue.serverTimestamp(),
      });

      // Si este usuario venía de una validación de domicilio pendiente → impactamos
      final String? pendingDomicilio = data['pending_domicilio_token'];
      if (pendingDomicilio != null && pendingDomicilio.isNotEmpty) {
        await _impactarValidacionDomicilio(pendingDomicilio, docId);
      }

      setState(() {
        _validando = false;
        _exito = true;
        _mensaje = '¡Tu identidad ha sido validada con éxito! Ya podés ingresar a la plataforma.';
      });
    } catch (e) {
      setState(() {
        _validando = false;
        _exito = false;
        _mensaje = 'Ocurrió un error al intentar validar la cuenta: $e';
      });
    }
  }

  Future<void> _impactarValidacionDomicilio(String token, String validadorId) async {
    try {
      final pendRef = db.collection('validaciones_pendientes').doc(token);
      final pendSnap = await pendRef.get();
      if (!pendSnap.exists) return;

      final pend = pendSnap.data()!;
      if (pend['estado'] != 'pendiente') return;

      final String targetUserId = pend['targetUserId'] ?? '';
      if (targetUserId.isEmpty) return;

      await pendRef.update({
        'validadorId': validadorId,
        'estado': 'completado',
        'procesado_en': FieldValue.serverTimestamp(),
      });

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

      // Limpiamos el pending del session por si acaso
      UserSession().clearPendingValidacion();
    } catch (e) {
      debugPrint('Error impactando validación de domicilio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_validando) ...[
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 24),
                  Text(_mensaje, style: TextStyle(fontSize: 16, color: textColor)),
                ] else ...[
                  Icon(
                    _exito ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    size: 80,
                    color: _exito ? const Color(0xFF25D366) : Colors.red[400],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _exito ? '¡Cuenta Activada!' : 'Validación fallida',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreenWidget()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Ir al inicio de sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
