import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class CargaTrabajoClienteWidget extends StatefulWidget {
  const CargaTrabajoClienteWidget({super.key});

  @override
  State<CargaTrabajoClienteWidget> createState() => _CargaTrabajoClienteWidgetState();
}

class _CargaTrabajoClienteWidgetState extends State<CargaTrabajoClienteWidget> {
  DocumentReference? _selectedCliente;
  DocumentReference? _selectedTrabajador;
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images); 
      });
    }
  }

  Future<void> _uploadAndSave() async {
    if (_selectedCliente == null || _selectedTrabajador == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completá los perfiles en los desplegables.')),
      );
      return;
    }
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenés que seleccionar al menos una foto.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      List<String> imageUrls = [];

      for (var image in _selectedImages) {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        Reference storageRef = FirebaseStorage.instance.ref().child('trabajos/$fileName');
        Uint8List fileBytes = await image.readAsBytes();
        
        UploadTask uploadTask = storageRef.putData(
          fileBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      await FirebaseFirestore.instance.collection('trabajos').add({
        'trabajadorRef': _selectedTrabajador,
        'clienteRef': _selectedCliente,
        'imagenes': imageUrls,
        'fechaCarga': FieldValue.serverTimestamp(),
        'cargadoPor': 'Cliente',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Trabajo cargado e informado con éxito!')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Seleccioná tu perfil de Cliente (Simulación):', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var items = snapshot.data!.docs;
                return DropdownButtonFormField<DocumentReference>(
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(10)),
                  hint: const Text('¿Quién sos? (Cliente)'),
                  value: _selectedCliente,
                  items: items.map((doc) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    String displayName = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
                    return DropdownMenuItem<DocumentReference>(
                      value: doc.reference,
                      child: Text(displayName.isNotEmpty ? displayName : 'Usuario sin nombre'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCliente = val),
                );
              },
            ),

            const SizedBox(height: 20),
            const Text('Seleccioná el Trabajador del servicio:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var items = snapshot.data!.docs;
                return DropdownButtonFormField<DocumentReference>(
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(10)),
                  hint: const Text('Elegir Trabajador'),
                  value: _selectedTrabajador,
                  items: items.map((doc) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    String displayName = data['nombre_comercial'] ?? '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}';
                    return DropdownMenuItem<DocumentReference>(
                      value: doc.reference,
                      child: Text(displayName.trim().isNotEmpty ? displayName : 'Sin Nombre'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTrabajador = val),
                );
              },
            ),

            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.photo_library),
              label: const Text('Elegir fotos desde el dispositivo'),
              onPressed: _isUploading ? null : _pickImages,
            ),

            const SizedBox(height: 15),

            if (_selectedImages.isNotEmpty) ...[
              const Text('Imágenes seleccionadas:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: FutureBuilder<Uint8List>(
                            future: _selectedImages[index].readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                return Image.memory(snapshot.data!, fit: BoxFit.cover);
                              }
                              return const Center(child: CircularProgressIndicator());
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

            if (_isUploading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14)),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancelar'),
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F52BA), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Subir imágenes'),
                      onPressed: _uploadAndSave,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
