import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'calificarTrabajo.dart';
import 'Homepage.dart';
import 'user_session.dart';

class CargaTrabajoClienteWidget extends StatefulWidget {
  const CargaTrabajoClienteWidget({super.key});

  @override
  State<CargaTrabajoClienteWidget> createState() =>
      _CargaTrabajoClienteWidgetState();
}

class _CargaTrabajoClienteWidgetState extends State<CargaTrabajoClienteWidget> {
  DocumentReference? _selectedTrabajador;
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  /// One-shot acotado a prestadores (Sprint 0: sin snapshots de toda la colección).
  late final Future<QuerySnapshot<Map<String, dynamic>>> _trabajadoresFuture =
      FirebaseFirestore.instance
          .collection('usuarios')
          .where('es_trabajador', isEqualTo: true)
          .limit(80)
          .get();

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 80,
    );

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _uploadAndSave() async {
    if (_selectedTrabajador == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, seleccioná un trabajador.')),
      );
      return;
    }
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenés que seleccionar al menos una foto.')),
      );
      return;
    }

    final sessionUid = UserSession().uid;
    if (sessionUid == null || sessionUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión no encontrada. Volvé a iniciar.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      List<String> imageUrls = [];

      for (var image in _selectedImages) {
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        // Sprint 0 storage rules: usuarios/{auth.uid}/...
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('usuarios/$sessionUid/trabajos/$fileName');
        Uint8List fileBytes = await image.readAsBytes();

        UploadTask uploadTask = storageRef.putData(
          fileBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      final clienteActualRef =
          FirebaseFirestore.instance.collection('usuarios').doc(sessionUid);

      final nuevoTrabajoRef =
          await FirebaseFirestore.instance.collection('trabajos').add({
        'trabajadorRef': _selectedTrabajador,
        'clienteRef': clienteActualRef,
        'imagenes': imageUrls,
        'fechaCarga': FieldValue.serverTimestamp(),
        'cargadoPor': 'Cliente',
        'calificado': false,
        'comentarioCliente': '',
        'estrellas': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Trabajo cargado con éxito! Ahora podés calificar.'),
          ),
        );

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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingreso Cliente'),
        backgroundColor: const Color(0xFF0F52BA),
        foregroundColor: Colors.white,
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
              'Seleccioná el Trabajador del servicio:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: _trabajadoresFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error al cargar prestadores: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!.docs;
                return DropdownButtonFormField<DocumentReference>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                  hint: const Text('Elegir Trabajador'),
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
                            : 'Sin Nombre',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTrabajador = val),
                );
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.photo_library),
              label: const Text('Elegir fotos desde el dispositivo'),
              onPressed: _isUploading ? null : _pickImages,
            ),
            const SizedBox(height: 15),
            if (_selectedImages.isNotEmpty) ...[
              const Text(
                'Imágenes seleccionadas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: FutureBuilder<Uint8List>(
                            future: _selectedImages[index].readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.done &&
                                  snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              }
                              return const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F52BA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isUploading ? null : _uploadAndSave,
              child: _isUploading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Subir y calificar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
