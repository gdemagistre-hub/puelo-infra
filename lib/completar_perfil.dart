import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'user_session.dart'; // Importamos el Singleton de sesión

class CompletarPerfilWidget extends StatefulWidget {
  const CompletarPerfilWidget({super.key});

  @override
  State<CompletarPerfilWidget> createState() => _CompletarPerfilWidgetState();
}

class _CompletarPerfilWidgetState extends State<CompletarPerfilWidget> {
  final db = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;
  final picker = ImagePicker();

  bool _isLoading = false;

  // --- VARIABLE DE USUARIO ACTUAL ---
  String? _selectedUsuarioId;

  // --- CONTROLADORES DE TEXTO ---
  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _pisoDeptoController = TextEditingController();
  final _barrioController = TextEditingController();
  final _cpController = TextEditingController();
  final _docNumeroController = TextEditingController();
  final _instagramController = TextEditingController();

  // --- VARIABLES DE ESTADO ---
  DateTime? _fechaNacimiento;
  String? _tipoDocSeleccionado;
  String? _paisDocSeleccionado;

  // Usamos Uint8List para compatibilidad con Flutter Web
  Uint8List? _fotoPerfilBytes;
  String? _urlFotoPerfilActual;

  Uint8List? _fotoDocBytes;
  String? _urlFotoDocumentoActual;

  // --- VARIABLES GEOGRÁFICAS (CASCADA) ---
  String? _paisDirId = 'AR';
  String? _provinciaDirId;
  String? _partidoDirId;
  String? _localidadDirId;

  List<Map<String, dynamic>> _paises = [];
  List<Map<String, dynamic>> _provincias = [];
  List<Map<String, dynamic>> _partidos = [];
  List<Map<String, dynamic>> _localidades = [];

  // Colores Puelo
  final primaryColor = const Color(0xFF0F52BA);
  final textColor = const Color(0xFF1E293B);
  final inputBgColor = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    // Tomamos el usuario de la sesión activa
    _selectedUsuarioId = UserSession().uid;
    
    if (_selectedUsuarioId != null) {
      _cargarDatosUsuarioActual();
    }
    _cargarPaises();
  }

  @override
  void dispose() {
    _calleController.dispose();
    _numeroController.dispose();
    _pisoDeptoController.dispose();
    _barrioController.dispose();
    _cpController.dispose();
    _docNumeroController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  // ==========================================
  // LÓGICA DE CARGA INICIAL
  // ==========================================
  
  Future<void> _cargarDatosUsuarioActual() async {
    setState(() {
      _isLoading = true;
    });

    final doc = await db.collection('usuarios').doc(_selectedUsuarioId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _calleController.text = data['calle'] ?? '';
        _numeroController.text = data['numero'] ?? '';
        _pisoDeptoController.text = data['piso_depto'] ?? '';
        _barrioController.text = data['barrio'] ?? '';
        _cpController.text = data['codigo_postal'] ?? '';
        _docNumeroController.text = data['documento_numero'] ?? '';
        _instagramController.text = data['instagram'] ?? '';

        _tipoDocSeleccionado = data['documento_tipo'];
        _paisDocSeleccionado = data['documento_pais'];

        if (data['fecha_nacimiento'] != null) {
          _fechaNacimiento = (data['fecha_nacimiento'] as Timestamp).toDate();
        } else {
          _fechaNacimiento = null;
        }

        _urlFotoPerfilActual = data['url_foto_perfil'];
        _urlFotoDocumentoActual = data['url_foto_documento'];
      });
    }

    setState(() => _isLoading = false);
  }

  // ==========================================
  // LÓGICA GEOGRÁFICA (CASCADA SIMPLE)
  // ==========================================
  Future<void> _cargarPaises() async {
    final query = await db.collection('cat_paises').get();
    setState(() {
      _paises = query.docs.map((d) {
        var data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    });

    _onPaisSelected('AR');
  }

  Future<void> _onPaisSelected(String? paisId) async {
    if (paisId == null) return;

    setState(() {
      _paisDirId = paisId;
      _provinciaDirId = null;
      _partidoDirId = null;
      _localidadDirId = null;
      _provincias = [];
      _partidos = [];
      _localidades = [];
    });

    final doc = await db.collection('cat_paises').doc(paisId).get();
    if (doc.exists && doc.data()!.containsKey('provincias')) {
      setState(() {
        _provincias = List<Map<String, dynamic>>.from(doc.data()!['provincias']);
      });
    }
  }

  Future<void> _onProvinciaSelected(String? provId) async {
    if (provId == null) return;

    setState(() {
      _provinciaDirId = provId;
      _partidoDirId = null;
      _localidadDirId = null;
      _partidos = [];
      _localidades = [];
    });

    final query = await db
        .collection('cat_departamentos')
        .where('provincia_id', isEqualTo: provId)
        .get();

    setState(() {
      _partidos = query.docs.map((d) => d.data()).toList();
    });
  }

  Future<void> _onPartidoSelected(String? partId) async {
    if (partId == null) return;

    setState(() {
      _partidoDirId = partId;
      _localidadDirId = null;
      _localidades = [];
    });

    final query = await db
        .collection('cat_localidades')
        .where('partido_id', isEqualTo: partId)
        .get();

    setState(() {
      _localidades = query.docs.map((d) => d.data()).toList();
    });
  }

  // ==========================================
  // LÓGICA DE FOTOS (WEB COMPATIBLE)
  // ==========================================
  Future<void> _tomarFoto(bool esPerfil, ImageSource source) async {
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        if (esPerfil) {
          _fotoPerfilBytes = bytes;
        } else {
          _fotoDocBytes = bytes;
        }
      });
    }
  }

  Future<void> _seleccionarFechaNacimiento() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  // ==========================================
  // GUARDAR DATOS
  // ==========================================
  Future<void> _guardarPerfil() async {
    if (_selectedUsuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró la sesión del usuario.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? urlPerfil = _urlFotoPerfilActual;
      String? urlDoc = _urlFotoDocumentoActual;

      if (_fotoPerfilBytes != null) {
        final ref = storage.ref().child('usuarios_fotos/perfil_$_selectedUsuarioId.jpg');
        await ref.putData(_fotoPerfilBytes!);
        urlPerfil = await ref.getDownloadURL();
      }

      if (_fotoDocBytes != null) {
        final ref = storage.ref().child('usuarios_fotos/doc_$_selectedUsuarioId.jpg');
        await ref.putData(_fotoDocBytes!);
        urlDoc = await ref.getDownloadURL();
      }

      Map<String, dynamic> actualizacion = {
        'calle': _calleController.text.trim(),
        'numero': _numeroController.text.trim(),
        'piso_depto': _pisoDeptoController.text.trim(),
        'barrio': _barrioController.text.trim(),
        'codigo_postal': _cpController.text.trim(),
        'documento_tipo': _tipoDocSeleccionado,
        'documento_pais': _paisDocSeleccionado,
        'documento_numero': _docNumeroController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'url_foto_perfil': urlPerfil,
        'url_foto_documento': urlDoc,
        'perfil_completo': true,
      };

      if (_fechaNacimiento != null) {
        actualizacion['fecha_nacimiento'] = Timestamp.fromDate(_fechaNacimiento!);
      }

      if (_localidadDirId != null) {
        actualizacion['direccion_geo'] = {
          'pais_id': _paisDirId,
          'provincia_id': _provinciaDirId,
          'partido_id': _partidoDirId,
          'localidad_id': _localidadDirId,
        };
      }

      await db.collection('usuarios').doc(_selectedUsuarioId).update(actualizacion);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil actualizado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  // ==========================================
  // INTERFAZ DE USUARIO
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_selectedUsuarioId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error: Iniciá sesión nuevamente para ver tu perfil.'),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Enriquecer Perfil'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- FOTO DE PERFIL ---
                        const SizedBox(height: 12),
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: _fotoPerfilBytes != null
                                    ? MemoryImage(_fotoPerfilBytes!)
                                    : (_urlFotoPerfilActual != null
                                        ? NetworkImage(_urlFotoPerfilActual!)
                                        : null) as ImageProvider?,
                                child: (_fotoPerfilBytes == null &&
                                        _urlFotoPerfilActual == null)
                                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  backgroundColor: primaryColor,
                                  radius: 20,
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 18),
                                    onPressed: () =>
                                        _tomarFoto(true, ImageSource.gallery),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- DIRECCIÓN ---
                        _buildSectionHeader('Dirección de Residencia'),
                        _buildTextField(controller: _calleController, hintText: 'Calle'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _numeroController,
                                hintText: 'Número',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _pisoDeptoController,
                                hintText: 'Piso / Depto',
                              ),
                            ),
                          ],
                        ),
                        _buildTextField(controller: _barrioController, hintText: 'Barrio'),

                        DropdownButtonFormField<String>(
                          value: _paisDirId,
                          decoration: _inputDeco('País'),
                          items: _paises
                              .map((p) => DropdownMenuItem<String>(
                                    value: p['id']?.toString(),
                                    child: Text(p['nombre']?.toString() ?? ''),
                                  ))
                              .toList(),
                          onChanged: _onPaisSelected,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _provinciaDirId,
                          decoration: _inputDeco('Provincia'),
                          items: _provincias
                              .map((p) => DropdownMenuItem<String>(
                                    value: p['id']?.toString(),
                                    child: Text(p['nombre']?.toString() ?? ''),
                                  ))
                              .toList(),
                          onChanged: _onProvinciaSelected,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _partidoDirId,
                          decoration: _inputDeco('Partido / Departamento'),
                          items: _partidos
                              .map((p) => DropdownMenuItem<String>(
                                    value: p['departamento_id']?.toString(),
                                    child: Text(
                                        p['departamento_nombre']?.toString() ?? ''),
                                  ))
                              .toList(),
                          onChanged: _onPartidoSelected,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _localidadDirId,
                          decoration: _inputDeco('Localidad'),
                          items: _localidades
                              .map((l) => DropdownMenuItem<String>(
                                    value: l['localidad_id']?.toString(),
                                    child: Text(
                                        l['localidad_nombre']?.toString() ?? ''),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _localidadDirId = val),
                        ),
                        const SizedBox(height: 12),

                        _buildTextField(
                          controller: _cpController,
                          hintText: 'Código Postal',
                          keyboardType: TextInputType.number,
                        ),

                        // --- IDENTIDAD ---
                        _buildSectionHeader('Datos de Identidad'),
                        InkWell(
                          onTap: _seleccionarFechaNacimiento,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            decoration: BoxDecoration(
                              color: inputBgColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fechaNacimiento == null
                                      ? 'Fecha de Nacimiento'
                                      : DateFormat('dd/MM/yyyy')
                                          .format(_fechaNacimiento!),
                                  style: TextStyle(
                                    color: _fechaNacimiento == null
                                        ? Colors.grey
                                        : textColor,
                                    fontSize: 16,
                                  ),
                                ),
                                const Icon(Icons.calendar_today, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _tipoDocSeleccionado,
                                decoration: _inputDeco('Tipo'),
                                items: ['DNI', 'Pasaporte', 'Cédula']
                                    .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t),
                                        ))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _tipoDocSeleccionado = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _paisDocSeleccionado,
                                decoration: _inputDeco('País Emisor'),
                                items: ['Argentina', 'Uruguay', 'Chile', 'Otro']
                                    .map((p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(p),
                                        ))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _paisDocSeleccionado = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _buildTextField(
                          controller: _docNumeroController,
                          hintText: 'Número de Documento',
                          keyboardType: TextInputType.number,
                        ),

                        // --- FOTO DEL DNI ---
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _tomarFoto(false, ImageSource.camera),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: inputBgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _fotoDocBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _fotoDocBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _urlFotoDocumentoActual != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _urlFotoDocumentoActual!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.camera_front,
                                              color: primaryColor, size: 40),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Tomar foto del documento frontal',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                          ),
                        ),

                        // --- SOCIAL ---
                        _buildSectionHeader('Redes Sociales'),
                        _buildTextField(
                          controller: _instagramController,
                          hintText: 'Usuario de Instagram (ej: @puelo)',
                          icon: Icons.camera_alt_outlined,
                        ),
                        const SizedBox(height: 32),

                        ElevatedButton(
                          onPressed: _guardarPerfil,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Actualizar tu perfil',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          hintText: hintText,
          filled: true,
          fillColor: inputBgColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      labelText: hint,
      filled: true,
      fillColor: inputBgColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
