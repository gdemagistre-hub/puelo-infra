import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dni_ocr_parser.dart';
import 'dni_ocr_scan.dart';
import 'user_session.dart';

class DatosPersonalesFlotanteWidget extends StatefulWidget {
  const DatosPersonalesFlotanteWidget({super.key});

  @override
  State<DatosPersonalesFlotanteWidget> createState() =>
      _DatosPersonalesFlotanteWidgetState();
}

class _DatosPersonalesFlotanteWidgetState
    extends State<DatosPersonalesFlotanteWidget> {
  final primaryColor = const Color(0xFF0F52BA);
  final _formKey = GlobalKey<FormState>();
  final _scanner = DniOcrScanner();

  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _docNumeroController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailConfirmController = TextEditingController();
  final _instagramController = TextEditingController();

  String? _tipoDoc;
  String? _paisDoc;
  DateTime? _fechaNacimiento;
  String? _urlFotoDocumento;

  bool _tieneWhatsapp = false;
  bool _loading = true;
  bool _saving = false;
  bool _procesandoOcr = false;

  bool _docValidado = false;
  String? _docHashDatos;

  final List<String> _tiposDoc = ['DNI', 'Pasaporte', 'CI', 'CUIT', 'Otro'];
  final List<String> _paises = [
    'Argentina',
    'Uruguay',
    'Chile',
    'Paraguay',
    'Brasil',
    'Bolivia',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _scanner.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _docNumeroController.dispose();
    _emailController.dispose();
    _emailConfirmController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nombreController.text = (data['nombre'] ?? '').toString();
        _apellidoController.text = (data['apellido'] ?? '').toString();
        _telefonoController.text = (data['telefono'] ?? '').toString();
        _tieneWhatsapp = data['tiene_whatsapp'] == true;
        _docNumeroController.text =
            (data['doc_numero'] ?? data['numero_documento'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        _emailController.text = email;
        _emailConfirmController.text = email;
        _instagramController.text =
            (data['instagram'] ?? data['usuario_instagram'] ?? '').toString();
        _tipoDoc = data['tipo_doc'] ?? data['tipo_documento'];
        _paisDoc = data['pais_doc'] ?? data['pais_emision'];
        _urlFotoDocumento = data['url_foto_documento']?.toString();
        _docValidado = data['doc_validado'] == true;
        _docHashDatos = data['doc_hash_datos']?.toString();

        if (data['fecha_nacimiento'] != null) {
          if (data['fecha_nacimiento'] is Timestamp) {
            _fechaNacimiento =
                (data['fecha_nacimiento'] as Timestamp).toDate();
          } else if (data['fecha_nacimiento'] is String) {
            _fechaNacimiento = DateTime.tryParse(data['fecha_nacimiento']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos personales: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  String? _validarTelefono(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'El celular es obligatorio';
    // +549-XXXXX-XXXX (sin el 15). Área 2 a 4 dígitos, número 4 a 8.
    final re = RegExp(r'^\+549-\d{2,4}-\d{4,8}$');
    if (!re.hasMatch(t)) {
      return 'Formato: +549-11444-5555 (sin el 15)';
    }
    return null;
  }

  Future<void> _seleccionarFecha() async {
    final DateTime initial = _fechaNacimiento ?? DateTime(1990, 1, 1);
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1920),
        lastDate: DateTime.now(),
        helpText: 'Fecha de nacimiento',
        cancelText: 'Cancelar',
        confirmText: 'Aceptar',
        fieldLabelText: 'Fecha',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: primaryColor,
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null && mounted) {
        setState(() => _fechaNacimiento = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el calendario: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // OCR + popup + validación + hash + imagen comprimida
  // ---------------------------------------------------------------------------

  Future<void> _iniciarEscaneoDocumento({required bool camara}) async {
    if (kIsWeb || !_scanner.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El escaneo de documento solo está disponible en el celular.',
          ),
        ),
      );
      return;
    }

    if (_nombreController.text.trim().isEmpty ||
        _apellidoController.text.trim().isEmpty ||
        _docNumeroController.text.trim().isEmpty ||
        _paisDoc == null ||
        _fechaNacimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completá nombre, apellido, documento, país y fecha antes de escanear.',
          ),
        ),
      );
      return;
    }

    setState(() => _procesandoOcr = true);

    try {
      final scan = await _scanner.capturarYEscanear(camara: camara);
      if (scan == null) {
        if (mounted) setState(() => _procesandoOcr = false);
        return;
      }

      if (scan.texto.trim().isEmpty) {
        if (mounted) {
          setState(() => _procesandoOcr = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo leer texto del documento. Probá con mejor luz.',
              ),
            ),
          );
        }
        return;
      }

      final ocr = DniOcrParser.parsear(scan.texto);
      if (!mounted) return;
      setState(() => _procesandoOcr = false);

      final confirmado = await _mostrarPopupDatosOcr(ocr);
      if (confirmado != true) return;

      final resultado = DniOcrParser.validarContraPerfil(
        ocr: ocr,
        nombreUsuario: _nombreController.text.trim(),
        apellidoUsuario: _apellidoController.text.trim(),
        numeroUsuario: _docNumeroController.text.trim(),
        paisUsuario: _paisDoc,
        fechaUsuario: _fechaNacimiento,
      );

      if (!resultado.ok) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('No coinciden los datos'),
              content: Text(
                'Revisá estas comparaciones:\n\n'
                '• Nombre: ${resultado.nombreOk ? "OK" : "No coincide"}\n'
                '• Apellido: ${resultado.apellidoOk ? "OK" : "No coincide"}\n'
                '• Documento: ${resultado.documentoOk ? "OK" : "No coincide"}\n'
                '• País: ${resultado.paisOk ? "OK" : "No coincide"}\n'
                '• Fecha nac.: ${resultado.fechaOk ? "OK" : "No coincide"}\n\n'
                'Corregí el perfil o volvé a escanear el documento.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Entendido', style: TextStyle(color: primaryColor)),
                ),
              ],
            ),
          );
        }
        return;
      }

      setState(() => _procesandoOcr = true);

      final uid = UserSession().uid!;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('usuarios')
          .child(uid)
          .child('documento_identidad.jpg');

      final upload = await storageRef.putData(
        Uint8List.fromList(scan.imageBytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await upload.ref.getDownloadURL();

      final hashAncla = DniOcrParser.hashDatosAncla(
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        numero: _docNumeroController.text.trim(),
        pais: _paisDoc,
        fecha: _fechaNacimiento,
      );

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'url_foto_documento': url,
        'doc_validado': true,
        'doc_validado_hash': resultado.hash,
        'doc_validado_en': Timestamp.fromDate(resultado.timestamp!),
        'doc_hash_datos': hashAncla,
        'ocr_texto': ocr.textoCrudo,
        'ocr_nombres': ocr.nombres,
        'ocr_apellidos': ocr.apellidos,
        'ocr_doc_numero': ocr.numeroDocumento,
        'ocr_pais': ocr.paisEmision,
        'ocr_fecha_nacimiento': ocr.fechaNacimiento != null
            ? Timestamp.fromDate(ocr.fechaNacimiento!)
            : null,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _urlFotoDocumento = url;
          _docValidado = true;
          _docHashDatos = hashAncla;
          _procesandoOcr = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento validado: los datos coinciden.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error OCR/validación: $e');
      if (mounted) {
        setState(() => _procesandoOcr = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar documento: $e')),
        );
      }
    }
  }

  Future<bool?> _mostrarPopupDatosOcr(DatosOcrDni ocr) {
    final fechaStr = ocr.fechaNacimiento != null
        ? DateFormat('dd/MM/yyyy').format(ocr.fechaNacimiento!)
        : '—';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Datos detectados del documento',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¿Estos datos son correctos?',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                _ocrRow(
                  'Nombre(s)',
                  ocr.nombres.isEmpty ? '—' : ocr.nombres.join(' '),
                ),
                _ocrRow(
                  'Apellido(s)',
                  ocr.apellidos.isEmpty ? '—' : ocr.apellidos.join(' '),
                ),
                _ocrRow('N° documento', ocr.numeroDocumento ?? '—'),
                _ocrRow('País de emisión', ocr.paisEmision ?? '—'),
                _ocrRow('Fecha de nacimiento', fechaStr),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Widget _ocrRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Guardar datos
  // ---------------------------------------------------------------------------

  Future<void> _actualizarDatos() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = UserSession().uid;
    if (uid == null) return;

    final email1 = _emailController.text.trim();
    final email2 = _emailConfirmController.text.trim();
    if (email1 != email2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los emails no coinciden')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final hashActual = DniOcrParser.hashDatosAncla(
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        numero: _docNumeroController.text.trim(),
        pais: _paisDoc,
        fecha: _fechaNacimiento,
      );

      final sigueValidado =
          _docValidado && _docHashDatos != null && _docHashDatos == hashActual;

      final payload = <String, dynamic>{
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'tiene_whatsapp': _tieneWhatsapp,
        'tipo_doc': _tipoDoc,
        'pais_doc': _paisDoc,
        'doc_numero': _docNumeroController.text.trim(),
        'fecha_nacimiento': _fechaNacimiento != null
            ? Timestamp.fromDate(_fechaNacimiento!)
            : null,
        'email': email1,
        'instagram': _instagramController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
        'doc_validado': sigueValidado,
      };

      if (!sigueValidado && _docValidado) {
        payload['doc_validado_hash'] = FieldValue.delete();
        payload['doc_validado_en'] = FieldValue.delete();
        payload['doc_hash_datos'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set(payload, SetOptions(merge: true));

      // Refrescar sesión en memoria
      final session = UserSession();
      session.nombre = _nombreController.text.trim();
      session.apellido = _apellidoController.text.trim();
      if (session.datosCompletos != null) {
        session.datosCompletos = {
          ...session.datosCompletos!,
          ...payload,
        };
      }

      if (mounted) {
        setState(() {
          _docValidado = sigueValidado;
          if (!sigueValidado) _docHashDatos = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sigueValidado
                  ? 'Datos actualizados (validación de documento intacta)'
                  : 'Datos actualizados correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Datos personales',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Stack(
              children: [
                Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildField('Nombre *', _nombreController, required: true),
                      _buildField(
                        'Apellido *',
                        _apellidoController,
                        required: true,
                      ),

                      // Celular + WhatsApp
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _telefonoController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Celular *',
                                  hintText: '+549-11444-5555',
                                  helperText:
                                      'Código AR +549, sin el 15. Ej: +549-11-44445555',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                validator: _validarTelefono,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              children: [
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'WhatsApp',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      Checkbox(
                                        value: _tieneWhatsapp,
                                        activeColor: primaryColor,
                                        onChanged: (v) => setState(
                                          () => _tieneWhatsapp = v ?? false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      _buildDropdown(
                        'Tipo de documento',
                        _tipoDoc,
                        _tiposDoc,
                        (v) => setState(() => _tipoDoc = v),
                      ),
                      _buildDropdown(
                        'País de emisión',
                        _paisDoc,
                        _paises,
                        (v) => setState(() => _paisDoc = v),
                      ),
                      _buildField(
                        'Número de documento',
                        _docNumeroController,
                      ),
                      _buildFechaNacimiento(),
                      _buildFotoDocumento(),
                      _buildField(
                        'Email',
                        _emailController,
                        keyboard: TextInputType.emailAddress,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: _emailConfirmController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Confirmar email',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          validator: (v) {
                            final e1 = _emailController.text.trim();
                            final e2 = (v ?? '').trim();
                            if (e1 != e2) return 'Los emails no coinciden';
                            return null;
                          },
                        ),
                      ),
                      _buildField(
                        'Usuario de Instagram',
                        _instagramController,
                        hint: '@usuario',
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              _saving || _procesandoOcr ? null : _actualizarDatos,
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _saving ? 'Guardando...' : 'Actualizar los datos',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                if (_procesandoOcr)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: primaryColor),
                              const SizedBox(height: 16),
                              const Text(
                                'Procesando documento...',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboard,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
            : null,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value != null && items.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items:
            items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildFechaNacimiento() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _seleccionarFecha,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Fecha de nacimiento',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(
            _fechaNacimiento != null
                ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)
                : 'Seleccionar fecha',
            style: TextStyle(
              color: _fechaNacimiento != null ? Colors.black87 : Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFotoDocumento() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Foto del documento',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const Spacer(),
              if (_docValidado)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: const Text(
                    'Documento validado',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              image: _urlFotoDocumento != null && _urlFotoDocumento!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_urlFotoDocumento!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _urlFotoDocumento == null || _urlFotoDocumento!.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 36,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sin foto cargada',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          if (kIsWeb || !_scanner.isSupported)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'El escaneo del documento con OCR solo está disponible desde el celular (Android/iOS).',
                style: TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _procesandoOcr
                        ? null
                        : () => _iniciarEscaneoDocumento(camara: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Escanear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _procesandoOcr
                        ? null
                        : () => _iniciarEscaneoDocumento(camara: false),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galería'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
