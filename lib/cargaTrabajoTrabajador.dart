import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'user_session.dart';

class CargaTrabajoTrabajadorWidget extends StatefulWidget {
  const CargaTrabajoTrabajadorWidget({super.key});

  @override
  State<CargaTrabajoTrabajadorWidget> createState() =>
      _CargaTrabajoTrabajadorWidgetState();
}

class _CargaTrabajoTrabajadorWidgetState
    extends State<CargaTrabajoTrabajadorWidget> {
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  List<String> _profesiones = [];
  String? _profesionSeleccionada;
  bool _loadingPerfil = true;

  @override
  void initState() {
    super.initState();
    _cargarProfesionesDelUsuario();
  }

  Future<void> _cargarProfesionesDelUsuario() async {
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() => _loadingPerfil = false);
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _profesiones = List<String>.from(data['profesiones'] ?? []);
      }
    } catch (e) {
      debugPrint('Error cargando profesiones: $e');
    }
    if (mounted) setState(() => _loadingPerfil = false);
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (images.isNotEmpty) {
      setState(() => _selectedImages.addAll(images));
    }
  }

  Future<void> _uploadAndSave() async {
    final uid = UserSession().uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenés que estar logueado.')),
      );
      return;
    }
    if (_profesionSeleccionada == null || _profesionSeleccionada!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elegí el servicio al que corresponde la foto.'),
        ),
      );
      return;
    }
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenés que seleccionar al menos una foto.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final List<String> imageUrls = [];
      final trabajadorRef =
          FirebaseFirestore.instance.collection('usuarios').doc(uid);

      for (final image in _selectedImages) {
        final fileName =
            '${uid}_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final storageRef =
            FirebaseStorage.instance.ref().child('portfolio/$uid/$fileName');
        final fileBytes = await image.readAsBytes();

        final snapshot = await storageRef.putData(
          fileBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrls.add(await snapshot.ref.getDownloadURL());
      }

      // Portfolio / trabajos mostrados — NO cuenta como experiencia realizada
      await FirebaseFirestore.instance.collection('trabajos').add({
        'trabajadorRef': trabajadorRef,
        'usuario_id': uid,
        'profesion': _profesionSeleccionada,
        'imagenes': imageUrls,
        'fechaCarga': FieldValue.serverTimestamp(),
        'cargadoPor': 'Trabajador',
        'tipo': 'portfolio',
        'cuenta_como_experiencia': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotos de trabajos cargadas con éxito')),
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
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = UserSession().nombreCompleto;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mostrar trabajo realizado'),
        backgroundColor: const Color(0xFF0F52BA),
        foregroundColor: Colors.white,
      ),
      body: _loadingPerfil
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vas a cargar fotos para: ${nombre.isNotEmpty ? nombre : 'tu cuenta'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Estas fotos se asocian a tu perfil y a un servicio. No suman como experiencias realizadas.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  if (_profesiones.isEmpty)
                    const Text(
                      'Primero cargá tus especialidades laborales en el perfil.',
                      style: TextStyle(color: Colors.orange),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _profesionSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Servicio / oficio de estas fotos',
                        border: OutlineInputBorder(),
                      ),
                      items: _profesiones
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _profesionSeleccionada = v),
                    ),
                  const SizedBox(height: 24),
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
                    Text(
                      'Imágenes seleccionadas: ${_selectedImages.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<Uint8List>(
                                future: _selectedImages[index].readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return const SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
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
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancelar'),
                            onPressed: () => Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F52BA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('Subir fotos'),
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
