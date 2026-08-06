import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'user_session.dart';
import 'platform_capabilities.dart';
import 'especialidadesLaboralesflotante.dart';
import 'theme/app_colors.dart';

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

  static const Color _primary = AppColors.prestador;

  static const Map<String, String> _labelOficio = {
    'electricidad': 'Electricista',
    'plomeria': 'Plomería',
    'gasista': 'Gasista',
    'carpinteria': 'Carpintería',
    'pintura': 'Pintura',
    'albanileria': 'Construcción',
    'jardineria': 'Jardinería',
    'limpieza': 'Limpieza',
  };

  String _labelDe(String clave) {
    final k = clave.toLowerCase().trim();
    return _labelOficio[k] ?? clave;
  }

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
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1080,
        imageQuality: 75,
      );
      if (images.isNotEmpty && mounted) {
        setState(() => _selectedImages.addAll(images));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron seleccionar imágenes: $e')),
      );
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
          content: Text('Elegí el oficio al que corresponde la foto.'),
        ),
      );
      return;
    }
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná al menos una foto.')),
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
            FirebaseStorage.instance.ref().child('usuarios/$uid/portfolio/$fileName');
        final fileBytes = await image.readAsBytes();

        final snapshot = await storageRef.putData(
          fileBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrls.add(await snapshot.ref.getDownloadURL());
      }

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
          const SnackBar(
            content: Text('Listo. Las fotos quedaron en tu portfolio.'),
            backgroundColor: AppColors.success,
          ),
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Mostrar trabajo realizado'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loadingPerfil
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primary.withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: _primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Estas fotos son tu portfolio: se ven en tu tarjeta '
                            'y se asocian a un oficio tuyo.\n'
                            'No suman como experiencias realizadas.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.text.withOpacity(0.9),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cuenta: ${nombre.isNotEmpty ? nombre : 'tu sesión'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_profesiones.isEmpty) ...[
                    const Text(
                      'Todavía no tenés oficios cargados. Primero definí tus especialidades.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const EspecialidadesLaboralesFlotanteWidget(),
                          ),
                        ).then((_) => _cargarProfesionesDelUsuario());
                      },
                      child: const Text('Cargar especialidades'),
                    ),
                  ] else
                    DropdownButtonFormField<String>(
                      value: _profesionSeleccionada,
                      decoration: InputDecoration(
                        labelText: 'Oficio de estas fotos',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _primary, width: 1.5),
                        ),
                      ),
                      items: _profesiones
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(_labelDe(p)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _profesionSeleccionada = v),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.text,
                      elevation: 0,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Elegir fotos'),
                    onPressed: _isUploading || _profesiones.isEmpty
                        ? null
                        : _pickImages,
                  ),
                  const SizedBox(height: 15),
                  if (_selectedImages.isNotEmpty) ...[
                    Text(
                      '${_selectedImages.length} foto(s)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
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
                                      child: CircularProgressIndicator(
                                        color: _primary,
                                      ),
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
                    const Center(
                      child: CircularProgressIndicator(color: _primary),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _profesiones.isEmpty
                                ? null
                                : _uploadAndSave,
                            child: const Text('Subir al portfolio'),
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
