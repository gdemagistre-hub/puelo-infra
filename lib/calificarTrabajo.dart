import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  State<CalificarTrabajoWidget> createState() => _CalificarTrabajoWidgetState();
}

class _CalificarTrabajoWidgetState extends State<CalificarTrabajoWidget> {
  final _comentarioController = TextEditingController();
  int _estrellasSeleccionadas = 0;
  bool _enviando = false;

  final primaryColor = const Color(0xFF0F52BA);
  final textColor = const Color(0xFF1E293B);

  Future<void> _guardarCalificacion() async {
    if (_estrellasSeleccionadas == 0) {
      _mostrarAlerta('Por favor, seleccioná al menos 1 estrella.');
      return;
    }

    setState(() => _enviando = true);

    final trabajoRef = FirebaseFirestore.instance.collection('trabajos').doc(widget.trabajoId);
    final trabajadorRef = FirebaseFirestore.instance.collection('usuarios').doc(widget.trabajadorId);

    try {
      // Usamos una transacción para asegurar que el cálculo del promedio sea exacto y libre de fraude
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final trabajadorSnapshot = await transaction.get(trabajadorRef);
        
        if (!trabajadorSnapshot.exists) return;

        Map<String, dynamic> trabajadorData = trabajadorSnapshot.data() as Map<String, dynamic>;
        
        // Estructura anti-fraude: Validamos si este cliente ya evaluó antes a este trabajador
        Map<String, dynamic> historialVotos = trabajadorData['historialVotos'] != null 
            ? Map<String, dynamic>.from(trabajadorData['historialVotos']) 
            : {};

        int votosAnteriores = trabajadorData['cantidadEvaluadores'] ?? 0;
        int sumaAnterior = trabajadorData['sumaEstrellas'] ?? 0;

        int nuevaSuma = sumaAnterior;
        int nuevosVotos = votosAnteriores;

        if (historialVotos.containsKey(widget.clienteId)) {
          // Si ya había votado antes, restamos su voto viejo y sumamos el nuevo (mantiene 1 voto por cliente)
          int votoViejo = historialVotos[widget.clienteId];
          nuevaSuma = (sumaAnterior - votoViejo) + _estrellasSeleccionadas;
        } else {
          // Si es un evaluador nuevo, sumamos un nuevo cliente al conteo
          nuevosVotos = votosAnteriores + 1;
          nuevaSuma = sumaAnterior + _estrellasSeleccionadas;
        }

        // Actualizamos el registro interno anti-fraude
        historialVotos[widget.clienteId] = _estrellasSeleccionadas;

        double nuevoPromedio = nuevosVotos > 0 ? (nuevaSuma / nuevosVotos) : 0.0;

        // 1. Guardamos la calificación en el trabajo
        transaction.update(trabajoRef, {
          'comentarioCliente': _comentarioController.text.trim(),
          'estrellas': _estrellasSeleccionadas,
          'clienteUid': widget.clienteId,
          'calificado': true,
        });

        // 2. Impactamos los promedios calculados en el perfil del trabajador
        transaction.update(trabajadorRef, {
          'sumaEstrellas': nuevaSuma,
          'cantidadEvaluadores': nuevosVotos,
          'promedioEstrellas': nuevoPromedio,
          'historialVotos': historialVotos,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Muchas gracias por tu calificación!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _mostrarAlerta('Error al guardar la calificación: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarAlerta(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calificar Servicio', style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: textColor,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Qué te pareció el trabajo?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu opinión sobre las fotos y el desempeño ayuda a mantener segura la comunidad.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 28),

              // Selector interactivo de 5 estrellas
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  int valorEstrella = index + 1;
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
              const SizedBox(height: 28),

              // Campo de texto para comentarios opcionales (máx 200 caracteres)
              Text(
                'Comentario para el trabajador (Opcional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comentarioController,
                maxLength: 200,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Dejá tu opinión sobre las fotos subidas o el trabajo realizado...',
                  helperText: 'Este comentario será privado, solo visible por el prestador.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Botón de Envío
              ElevatedButton(
                onPressed: _enviando ? null : _guardarCalificacion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _enviando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enviar Calificación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
