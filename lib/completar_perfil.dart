import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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

  // --- VARIABLES DE USUARIO TEMPORAL ---
  String? _selectedUsuarioId;
  List<Map<String, dynamic>> _usuariosDisponibles = [];

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
  
  File? _fotoPerfil;
  String? _urlFotoPerfilActual;
  
  File? _fotoDocumento;
  String? _urlFotoDocumentoActual;

  // --- VARIABLES GEOGRÁFICAS (CASCADA) ---
  String? _paisDirId;
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
    _cargarUsuariosTemporales();
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

  Future<void> _cargarUsuariosTemporales() async {
    final query = await db.collection('usuarios').get();
    setState(() {
      _usuariosDisponibles = query.docs.map((doc) {
        var data = doc.data();
        data['doc_id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> _seleccionarUsuario(String? userId) async {
    if (userId == null) return;
    setState(() {
      _isLoading = true;
      _selectedUsuarioId = userId;
    });

    final doc = await db.collection('usuarios').doc(userId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        // Llenamos los campos si ya existen
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
        
        // No reseteamos la cascada geográfica completa todavía, 
        // requeriría un proceso más complejo de carga inversa, 
        // por ahora forzamos a que vuelva a elegir su zona si edita.
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
      _paises = query.docs.map((d) => d.data()).toList();
    });
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

    // Buscamos el documento del país para extraer sus provincias
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

    final query = await db.collection('cat_departamentos')
        .where('provincia_id', isEqualTo: provId).get();
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

    final query = await db.collection('cat_localidades')
        .where('partido_id', isEqualTo: partId).get();
    setState(() {
      _localidades = query.docs.map((d) => d.data()).toList();
    });
  }

  // ==========================================
  // LÓGICA DE FOTOS
  // ==========================================

  Future<void> _tomarFoto(bool esPerfil, ImageSource source) async {
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() {
        if (esPerfil) {
          _fotoPerfil = File(image.path);
        } else {
          _fotoDocumento = File(image.path);
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
        const SnackBar(content: Text('Por favor seleccioná un usuario primero.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? urlPerfil = _urlFotoPerfilActual;
      String? urlDoc = _urlFotoDocumentoActual;

      // 1. Subir fotos a Storage si hay nuevas
      if (_fotoPerfil != null) {
        final ref = storage.ref().child('usuarios_fotos/perfil_$_selectedUsuarioId.jpg');
        await ref.putFile(_fotoPerfil!);
        urlPerfil = await ref.getDownloadURL();
      }

      if (_fotoDocumento != null) {
        final ref = storage.ref().child('usuarios_fotos/doc_$_selectedUsuarioId.jpg');
        await ref.putFile(_fotoDocumento!);
        urlDoc = await ref.getDownloadURL();
      }

      // 2. Armar el mapa de actualización
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
        'perfil_completo': true, // Flag de scoring
      };

      if (_fechaNacimiento != null) {
        actualizacion['fecha_nacimiento'] = Timestamp.fromDate(_fechaNacimiento!);
      }

      // Solo actualizamos la geografía si el usuario la modificó
      if (_localidadDirId != null) {
        actualizacion['direccion_geo'] = {
          'pais_id': _paisDirId,
          'provincia_id': _provinciaDirId,
          'partido_id': _partidoDirId,
          'localidad_id': _localidadDirId,
        };
      }

      // 3. Impactar en Firestore
      await db.collection('usuarios').doc(_selectedUsuarioId).update(actualizacion);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Perfil actualizado con éxito!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Volver al Home
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
                        // --- 1. MOCK SELECCIÓN DE USUARIO ---
                        _buildSectionHeader('Simulador de Login (Temporal)'),
                        DropdownButtonFormField<String>(
                          value: _selectedUsuarioId,
                          decoration: _inputDeco('Seleccionar Usuario Actual'),
                          items: _usuariosDisponibles.map((u) {
                            return DropdownMenuItem<String>(
                              value: u['doc_id'],
                              child: Text('${u['nombre']} ${u['apellido']} - ${u['rol']}'),
                            );
                          }).toList(),
                          onChanged: _seleccionarUsuario,
                        ),
                        const SizedBox(height: 24),

                        if (_selectedUsuarioId != null) ...[
                          
                          // --- 2. FOTO DE PERFIL ---
                          Center(
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _fotoPerfil != null
                                      ? FileImage(_fotoPerfil!)
                                      : (_urlFotoPerfilActual != null ? NetworkImage(_urlFotoPerfilActual!) : null) as ImageProvider?,
                                  child: (_fotoPerfil == null && _urlFotoPerfilActual == null)
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
                                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                      onPressed: () => _tomarFoto(true, ImageSource.gallery), // Opciones: gallery / camera
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // --- 3. DIRECCIÓN ---
                          _buildSectionHeader('Dirección de Residencia'),
                          _buildTextField(controller: _calleController, hintText: 'Calle'),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(controller: _numeroController, hintText: 'Número')),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTextField(controller: _pisoDeptoController, hintText: 'Piso / Depto')),
                            ],
                          ),
                          _buildTextField(controller: _barrioController, hintText: 'Barrio'),
                          
                          // Cascada Geográfica
                          DropdownButtonFormField<String>(
                            value: _paisDirId,
                            decoration: _inputDeco('País'),
                            items: _paises.map((p) => DropdownMenuItem<String>(value: p['id'], child: Text(p['nombre']))).toList(),
                            onChanged: _onPaisSelected,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _provinciaDirId,
                            decoration: _inputDeco('Provincia'),
                            items: _provincias.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text(p['nombre']))).toList(),
                            onChanged: _onProvinciaSelected,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _partidoDirId,
                            decoration: _inputDeco('Partido / Departamento'),
                            items: _partidos.map((p) => DropdownMenuItem<String>(value: p['departamento_id'], child: Text(p['departamento_nombre']))).toList(),
                            onChanged: _onPartidoSelected,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _localidadDirId,
                            decoration: _inputDeco('Localidad'),
                            items: _localidades.map((l) => DropdownMenuItem<String>(value: l['localidad_id'], child: Text(l['localidad_nombre']))).toList(),
                            onChanged: (val) => setState(() => _localidadDirId = val),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(controller: _cpController, hintText: 'Código Postal', keyboardType: TextInputType.number),

                          // --- 4. IDENTIDAD ---
                          _buildSectionHeader('Datos de Identidad'),
                          InkWell(
                            onTap: _seleccionarFechaNacimiento,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_fechaNacimiento == null ? 'Fecha de Nacimiento' : DateFormat('dd/MM/yyyy').format(_fechaNacimiento!),
                                      style: TextStyle(color: _fechaNacimiento == null ? Colors.grey : textColor, fontSize: 16)),
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
                                  items: ['DNI', 'Pasaporte', 'Cédula'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (val) => setState(() => _tipoDocSeleccionado = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _paisDocSeleccionado,
                                  decoration: _inputDeco('País Emisor'),
                                  items: ['Argentina', 'Uruguay', 'Chile', 'Otro'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                  onChanged: (val) => setState(() => _paisDocSeleccionado = val),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(controller: _docNumeroController, hintText: 'Número de Documento', keyboardType: TextInputType.number),

                          // Foto del DNI
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
                              child: _fotoDocumento != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_fotoDocumento!, fit: BoxFit.cover))
                                  : _urlFotoDocumentoActual != null
                                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_urlFotoDocumentoActual!, fit: BoxFit.cover))
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.camera_front, color: primaryColor, size: 40),
                                            const SizedBox(height: 8),
                                            const Text('Tomar foto del documento frontal', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                            ),
                          ),

                          // --- 5. SOCIAL ---
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Guardar y Aumentar Scoring', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 40),
                        ],
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
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, IconData? icon, TextInputType keyboardType = TextInputType.text}) {
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      labelText: hint,
      filled: true,
      fillColor: inputBgColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
