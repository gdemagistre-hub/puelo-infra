import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'platform_capabilities.dart';
import 'usuario_list_sync.dart';
import 'identidad_pii.dart';
import 'package:intl/intl.dart';
import 'user_session.dart';
import 'geo/doc_catalog.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';

class CompletarPerfilWidget extends StatefulWidget {
  const CompletarPerfilWidget({super.key});

  @override
  State<CompletarPerfilWidget> createState() => _CompletarPerfilWidgetState();
}

class _CompletarPerfilWidgetState extends State<CompletarPerfilWidget> {
  final db = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;
  final picker = ImagePicker();

  bool _isLoading = true;

  String? _selectedUsuarioId;

  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _pisoDeptoController = TextEditingController();
  final _barrioController = TextEditingController();
  final _cpController = TextEditingController();
  final _docNumeroController = TextEditingController();
  final _instagramController = TextEditingController();

  DateTime? _fechaNacimiento;
  String? _tipoDocSeleccionado;
  String? _paisDocSeleccionado;

  Uint8List? _fotoPerfilBytes;
  String? _urlFotoPerfilActual;

  Uint8List? _fotoDocBytes;
  String? _urlFotoDocumentoActual;

  String? _paisDirId = 'AR';
  String? _provinciaDirId;
  String? _partidoDirId;
  String? _localidadDirId;

  List<Map<String, dynamic>> _paises = [];
  List<Map<String, dynamic>> _provincias = [];
  List<Map<String, dynamic>> _partidos = [];
  List<Map<String, dynamic>> _localidades = [];

  static const Color primaryColor = AppColors.cliente;
  static const Color textColor = AppColors.text;
  static const Color inputBgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _selectedUsuarioId = UserSession().uid;
    _inicializarDatos();
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

  Future<void> _inicializarDatos() async {
    if (mounted) setState(() => _isLoading = true);

    await _cargarPaises();

    if (_selectedUsuarioId != null) {
      await _cargarDatosUsuarioActual();
    } else {
      await _cargarProvinciasDePais('AR');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarPaises() async {
    final query = await db.collection('cat_paises').get();
    _paises = query.docs.map((d) {
      var data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }

  Future<void> _cargarProvinciasDePais(String paisId) async {
    final doc = await db.collection('cat_paises').doc(paisId).get();
    if (doc.exists && doc.data()!.containsKey('provincias')) {
      _provincias =
          List<Map<String, dynamic>>.from(doc.data()!['provincias']);
    }
  }

  Future<void> _cargarPartidosDeProvincia(String provId) async {
    final query = await db
        .collection('cat_departamentos')
        .where('provincia_id', isEqualTo: provId)
        .get();
    _partidos = query.docs.map((d) => d.data()).toList();
  }

  Future<void> _cargarLocalidadesDePartido(String partId) async {
    final query = await db
        .collection('cat_localidades')
        .where('partido_id', isEqualTo: partId)
        .get();
    _localidades = query.docs.map((d) => d.data()).toList();
  }

  Future<void> _cargarDatosUsuarioActual() async {
    final doc = await db.collection('usuarios').doc(_selectedUsuarioId).get();

    if (doc.exists) {
      final data = await IdentidadPii.mezclar(_selectedUsuarioId!, doc.data()!);
      _calleController.text = data['calle'] ?? '';
      _numeroController.text = data['numero'] ?? '';
      _pisoDeptoController.text = data['piso_depto'] ?? '';
      _barrioController.text = data['barrio'] ?? '';
      _cpController.text = data['codigo_postal'] ?? '';
      _docNumeroController.text =
          (data['documento'] ?? data['doc_numero'] ?? '').toString();
      _instagramController.text = data['instagram'] ?? '';
      _tipoDocSeleccionado =
          data['documento_tipo'] ?? data['tipo_doc'];
      _paisDocSeleccionado =
          data['documento_pais'] ?? data['pais_doc'];

      if (data['fecha_nacimiento'] != null) {
        _fechaNacimiento =
            (data['fecha_nacimiento'] as Timestamp).toDate();
      }

      _urlFotoPerfilActual =
          data['url_foto_perfil'] ?? data['foto_perfil'];
      _urlFotoDocumentoActual =
          data['url_foto_documento'] ?? data['foto_documento'];

      if (data.containsKey('direccion_geo')) {
        final geo = data['direccion_geo'];

        _paisDirId = geo['pais_id'] ?? 'AR';
        await _cargarProvinciasDePais(_paisDirId!);

        _provinciaDirId = geo['provincia_id'];
        if (_provinciaDirId != null) {
          await _cargarPartidosDeProvincia(_provinciaDirId!);

          _partidoDirId = geo['partido_id'];
          if (_partidoDirId != null) {
            await _cargarLocalidadesDePartido(_partidoDirId!);
            _localidadDirId = geo['localidad_id'];
          }
        }
      } else {
        await _cargarProvinciasDePais('AR');
      }
    }
  }

  Future<void> _onPaisSelected(String? paisId) async {
    if (paisId == null) return;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _paisDirId = paisId;
      _provinciaDirId = null;
      _partidoDirId = null;
      _localidadDirId = null;
      _provincias = [];
      _partidos = [];
      _localidades = [];
    });
    await _cargarProvinciasDePais(paisId);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _onProvinciaSelected(String? provId) async {
    if (provId == null) return;
    setState(() {
      _isLoading = true;
      _provinciaDirId = provId;
      _partidoDirId = null;
      _localidadDirId = null;
      _partidos = [];
      _localidades = [];
    });
    await _cargarPartidosDeProvincia(provId);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _onPartidoSelected(String? partId) async {
    if (partId == null) return;
    setState(() {
      _isLoading = true;
      _partidoDirId = partId;
      _localidadDirId = null;
      _localidades = [];
    });
    await _cargarLocalidadesDePartido(partId);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _tomarFoto(bool esPerfil, ImageSource source) async {
    if (source == ImageSource.camera && !PlatformCapabilities.supportsCamera) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PlatformCapabilities.cameraUnsupportedMessage)),
      );
      return;
    }
    try {
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (esPerfil) {
          _fotoPerfilBytes = bytes;
        } else {
          _fotoDocBytes = bytes;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la imagen: $e')),
      );
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
            colorScheme: const ColorScheme.light(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  Future<void> _guardarPerfil() async {
    // Solo domicilio es obligatorio en esta pantalla.
    // Identidad (fecha, tipo, país, número, foto doc) es opcional.
    if (_calleController.text.trim().isEmpty ||
        _numeroController.text.trim().isEmpty ||
        _barrioController.text.trim().isEmpty ||
        _provinciaDirId == null ||
        _partidoDirId == null ||
        _localidadDirId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completá la dirección (calle, número, barrio, provincia, partido y localidad).',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? urlPerfil = _urlFotoPerfilActual;
      String? urlDoc = _urlFotoDocumentoActual;

      if (_fotoPerfilBytes != null) {
        final ref = storage
            .ref()
            .child('usuarios/$_selectedUsuarioId/perfil.jpg');
        await ref.putData(
          _fotoPerfilBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        urlPerfil = await ref.getDownloadURL();
      }

      if (_fotoDocBytes != null) {
        final ref =
            storage.ref().child('usuarios/$_selectedUsuarioId/doc.jpg');
        await ref.putData(
          _fotoDocBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        urlDoc = await ref.getDownloadURL();
      }

      final Map<String, dynamic> actualizacion = {
        'calle': _calleController.text.trim(),
        'numero': _numeroController.text.trim(),
        'piso_depto': _pisoDeptoController.text.trim(),
        'barrio': _barrioController.text.trim(),
        'codigo_postal': _cpController.text.trim(),
        'documento_tipo': _tipoDocSeleccionado,
        'documento_pais': _paisDocSeleccionado,
        'documento': _docNumeroController.text.trim(),
        'doc_numero': _docNumeroController.text.trim(),
        'tipo_doc': _tipoDocSeleccionado,
        'pais_doc': _paisDocSeleccionado,
        'instagram': _instagramController.text.trim(),
        'url_foto_perfil': urlPerfil,
        'foto_perfil': urlPerfil,
        'url_foto_documento': urlDoc,
        'foto_documento': urlDoc,
        'perfil_completo': true,
        'direccion_geo': {
          'pais_id': _paisDirId,
          'provincia_id': _provinciaDirId,
          'partido_id': _partidoDirId,
          'localidad_id': _localidadDirId,
        },
      };

      if (_fechaNacimiento != null) {
        actualizacion['fecha_nacimiento'] =
            Timestamp.fromDate(_fechaNacimiento!);
      }

      await UsuarioListSync.mergeUserDoc(_selectedUsuarioId!, actualizacion);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppCopy.errorGenerico} ($e)')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedUsuarioId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Iniciá sesión nuevamente para ver tu perfil.'),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Completar perfil'),
          backgroundColor: Colors.white,
          foregroundColor: textColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'La dirección es lo principal en esta pantalla. '
                                  'Fecha de nacimiento, documento y foto son opcionales '
                                  '(suman confianza si los cargás). '
                                  'Nombre y apellido se editan en Datos personales.',
                                  style: TextStyle(
                                    color: primaryColor.withOpacity(0.95),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: _fotoPerfilBytes != null
                                    ? MemoryImage(_fotoPerfilBytes!)
                                    : (_urlFotoPerfilActual != null
                                            ? NetworkImage(
                                                _urlFotoPerfilActual!,
                                              )
                                            : null)
                                        as ImageProvider?,
                                child: (_fotoPerfilBytes == null &&
                                        _urlFotoPerfilActual == null)
                                    ? const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  backgroundColor: primaryColor,
                                  radius: 20,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    onPressed: () => _tomarFoto(
                                      true,
                                      ImageSource.gallery,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: _buildLabel(
                            'Foto de perfil',
                            obligatorio: false,
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionHeader('Dirección'),
                        _buildTextField(
                          controller: _calleController,
                          labelText: 'Calle',
                          obligatorio: true,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _numeroController,
                                labelText: 'Número',
                                obligatorio: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _pisoDeptoController,
                                labelText: 'Piso / Depto',
                                obligatorio: false,
                              ),
                            ),
                          ],
                        ),
                        _buildTextField(
                          controller: _barrioController,
                          labelText: 'Barrio',
                          obligatorio: true,
                        ),

                        DropdownButtonFormField<String>(
                          value: _paisDirId,
                          decoration: _inputDeco('País', obligatorio: true),
                          items: _paises
                              .map(
                                (p) => DropdownMenuItem<String>(
                                  value: p['id']?.toString(),
                                  child: Text(p['nombre']?.toString() ?? ''),
                                ),
                              )
                              .toList(),
                          onChanged: _onPaisSelected,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _provinciaDirId,
                          decoration:
                              _inputDeco('Provincia', obligatorio: true),
                          items: _provincias
                              .map(
                                (p) => DropdownMenuItem<String>(
                                  value: p['id']?.toString(),
                                  child: Text(p['nombre']?.toString() ?? ''),
                                ),
                              )
                              .toList(),
                          onChanged: _onProvinciaSelected,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _partidoDirId,
                          decoration: _inputDeco(
                            'Partido / Departamento',
                            obligatorio: true,
                          ),
                          items: _partidos
                              .map(
                                (p) => DropdownMenuItem<String>(
                                  value: p['departamento_id']?.toString(),
                                  child: Text(
                                    p['departamento_nombre']?.toString() ??
                                        '',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _onPartidoSelected,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _localidadDirId,
                          decoration:
                              _inputDeco('Localidad', obligatorio: true),
                          items: _localidades
                              .map(
                                (l) => DropdownMenuItem<String>(
                                  value: l['localidad_id']?.toString(),
                                  child: Text(
                                    l['localidad_nombre']?.toString() ?? '',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _localidadDirId = val),
                        ),
                        const SizedBox(height: 12),

                        _buildTextField(
                          controller: _cpController,
                          labelText: 'Código postal',
                          keyboardType: TextInputType.number,
                          obligatorio: false,
                        ),

                        _buildSectionHeader('Identidad (opcional)'),
                        InkWell(
                          onTap: _seleccionarFechaNacimiento,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: inputBgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                _fechaNacimiento == null
                                    ? _buildLabel(
                                        'Fecha de nacimiento',
                                        obligatorio: false,
                                      )
                                    : Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(_fechaNacimiento!),
                                        style: const TextStyle(
                                          color: textColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey,
                                ),
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
                                decoration:
                                    _inputDeco('Tipo', obligatorio: false),
                                items: DocCatalog.tipos(current: _tipoDocSeleccionado)
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => setState(
                                  () => _tipoDocSeleccionado = val,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _paisDocSeleccionado,
                                decoration: _inputDeco(
                                  'País emisor',
                                  obligatorio: false,
                                ),
                                items: DocCatalog.paisesEmisor(
                                        current: _paisDocSeleccionado)
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => setState(
                                  () => _paisDocSeleccionado = val,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _buildTextField(
                          controller: _docNumeroController,
                          labelText: 'Número de documento',
                          keyboardType: TextInputType.number,
                          obligatorio: false,
                        ),

                        const SizedBox(height: 16),
                        _buildLabel(
                          'Foto de documento (frente)',
                          obligatorio: false,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () =>
                              _tomarFoto(false, ImageSource.camera),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: inputBgColor,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.grey.shade300),
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
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Image.network(
                                          _urlFotoDocumentoActual!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_front,
                                            color: primaryColor,
                                            size: 40,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Tocar para adjuntar foto',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),

                        _buildSectionHeader('Redes (opcional)'),
                        _buildTextField(
                          controller: _instagramController,
                          labelText: 'Instagram (ej: @tuusuario)',
                          icon: Icons.camera_alt_outlined,
                          obligatorio: false,
                        ),
                        const SizedBox(height: 32),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _guardarPerfil,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Guardar perfil',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {required bool obligatorio}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.grey[700], fontSize: 14),
        children: obligatorio
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            : [],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    required bool obligatorio,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon:
              icon != null ? Icon(icon, color: Colors.grey) : null,
          label: _buildLabel(labelText, obligatorio: obligatorio),
          filled: true,
          fillColor: inputBgColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: primaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(
    String labelText, {
    required bool obligatorio,
  }) {
    return InputDecoration(
      label: _buildLabel(labelText, obligatorio: obligatorio),
      filled: true,
      fillColor: inputBgColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    );
  }
}
