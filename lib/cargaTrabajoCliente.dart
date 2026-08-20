import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calificarTrabajo.dart';
import 'Homepage.dart';
import 'user_session.dart';
import 'theme/app_colors.dart';

/// Cliente elige prestador y pasa a calificar (estrellas + comentario).
/// Las fotos de trabajos solo las carga el prestador (portfolio).
class CargaTrabajoClienteWidget extends StatefulWidget {
  const CargaTrabajoClienteWidget({super.key});

  @override
  State<CargaTrabajoClienteWidget> createState() =>
      _CargaTrabajoClienteWidgetState();
}

class _CargaTrabajoClienteWidgetState extends State<CargaTrabajoClienteWidget> {
  DocumentReference? _selectedTrabajador;
  bool _isSaving = false;

  late final Future<QuerySnapshot<Map<String, dynamic>>> _trabajadoresFuture =
      FirebaseFirestore.instance
          .collection('usuarios')
          .where('es_trabajador', isEqualTo: true)
          .limit(80)
          .get();

  Future<void> _continuarACalificar() async {
    if (_selectedTrabajador == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccion\u00e1 el prestador del servicio.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sessionUid = UserSession().uid;
    if (sessionUid == null || sessionUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi\u00f3n no encontrada. Volv\u00e9 a iniciar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final clienteActualRef =
          FirebaseFirestore.instance.collection('usuarios').doc(sessionUid);

      final nuevoTrabajoRef =
          await FirebaseFirestore.instance.collection('trabajos').add({
        'trabajadorRef': _selectedTrabajador,
        'clienteRef': clienteActualRef,
        'usuario_id': _selectedTrabajador!.id,
        'fechaCarga': FieldValue.serverTimestamp(),
        'cargadoPor': 'Cliente',
        'tipo': 'evaluacion',
        'calificado': false,
        'comentarioCliente': '',
        'estrellas': 0,
        // Sin imagenes: el portfolio es solo del prestador.
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CalificarTrabajoWidget(
            trabajoId: nuevoTrabajoRef.id,
            trabajadorId: _selectedTrabajador!.id,
            clienteId: sessionUid,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo continuar: $e'),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomePageWidget()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '\u00bfA qui\u00e9n calific\u00e1s?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Eleg\u00ed el prestador del trabajo. Despu\u00e9s vas a poner estrellas y un comentario. '
              'Las fotos de trabajos solo las publica el prestador en su portfolio.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Prestador',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: _trabajadoresFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Error al cargar prestadores: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final items = snapshot.data!.docs;
                return DropdownButtonFormField<DocumentReference>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  hint: const Text('Elegir prestador'),
                  value: _selectedTrabajador,
                  items: items.map((doc) {
                    final data = doc.data();
                    final displayName = (data['nombre_comercial'] ??
                            '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}')
                        .toString();
                    return DropdownMenuItem<DocumentReference>(
                      value: doc.reference,
                      child: Text(
                        displayName.trim().isNotEmpty
                            ? displayName
                            : 'Sin nombre',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTrabajador = val),
                );
              },
            ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cliente,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _continuarACalificar,
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Continuar a calificar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
