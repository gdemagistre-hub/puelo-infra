import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Homepage.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';

class CalificarTrabajoWidget extends StatefulWidget {
  const CalificarTrabajoWidget({
    super.key,
    required this.trabajoId,
    required this.trabajadorId,
    required this.clienteId,
  });

  final String trabajoId;
  final String trabajadorId;
  final String clienteId;

  static const String routeName = 'CalificarTrabajo';
  static const String routePath = '/calificar';

  @override
  State<CalificarTrabajoWidget> createState() => _CalificarTrabajoWidgetState();
}

class _CalificarTrabajoWidgetState extends State<CalificarTrabajoWidget> {
  final _comentarioController = TextEditingController();
  int _estrellasSeleccionadas = 0;
  bool _enviando = false;

  static const Color primaryColor = AppColors.cliente;
  static const Color textColor = AppColors.text;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  void _volverAPrincipal() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePageWidget()),
      (route) => false,
    );
  }

  Future<void> _guardarCalificacion() async {
    if (_estrellasSeleccionadas == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elegí al menos 1 estrella.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    final trabajoRef =
        FirebaseFirestore.instance.collection('trabajos').doc(widget.trabajoId);
    final trabajadorRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.trabajadorId);

    try {
      // 1) Marca el trabajo (sin publicar estrellas al perfil todavía)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(trabajoRef, {
          'comentarioCliente': _comentarioController.text.trim(),
          'estrellas': _estrellasSeleccionadas,
          'clienteUid': widget.clienteId,
          'calificado': true,
          'tipo': 'evaluacion',
          'calificacion_estado': 'pendiente_respuesta_prestador',
        });
      });

      // 2) Calificación en cuarentena: visible en score/perfil solo cuando
      //    - el prestador acepta / responde, o
      //    - pasan 7 días (batch scoring F1)
      await FirebaseFirestore.instance.collection('calificaciones').add({
        'prestador_id': widget.trabajadorId,
        'trabajador_id': widget.trabajadorId,
        'cliente_id': widget.clienteId,
        'trabajo_id': widget.trabajoId,
        'estrellas': _estrellasSeleccionadas,
        'rating': _estrellasSeleccionadas,
        'comentario': _comentarioController.text.trim(),
        'estado': 'pendiente_respuesta_prestador',
        'tipo': 'trabajo',
        'con_foto': false,
        'par_completo': false,
        'aceptado_por_prestador': false,
        'created_at': FieldValue.serverTimestamp(),
        'fecha': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gracias. Tu evaluación queda registrada y se publica '
              'cuando el prestador responda o a los 7 días.',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 5),
          ),
        );
        _volverAPrincipal();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppCopy.errorGenerico} ($e)')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Calificar servicio',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: textColor,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _volverAPrincipal,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                AppCopy.ctaCalificar,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu opinión ayuda a otros a elegir con más confianza.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final valorEstrella = index + 1;
                  return IconButton(
                    iconSize: 40,
                    icon: Icon(
                      _estrellasSeleccionadas >= valorEstrella
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFFFB000),
                    ),
                    onPressed: () {
                      setState(() {
                        _estrellasSeleccionadas = valorEstrella;
                      });
                    },
                  );
                }),
              ),
              if (_estrellasSeleccionadas > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$_estrellasSeleccionadas de 5',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              const Text(
                'Comentario (opcional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comentarioController,
                maxLength: 200,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '¿Cómo te fue? ¿Llegó a tiempo? ¿Quedó bien?',
                  helperText:
                      'El comentario lo ve el profesional. Las estrellas sí son públicas.',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _guardarCalificacion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enviar calificación',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
