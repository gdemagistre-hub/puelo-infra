import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'dni_ocr_parser.dart';
import 'dni_ocr_scan.dart';
import 'telefono_ar.dart';
import 'geo/doc_catalog.dart';
import 'user_session.dart';
import 'usuario_list_sync.dart';
import 'identidad_pii.dart';
import 'theme/app_colors.dart';

class DatosPersonalesFlotanteWidget extends StatefulWidget {
  final bool? modoPrestador;

  const DatosPersonalesFlotanteWidget({super.key, this.modoPrestador});

  @override
  State<DatosPersonalesFlotanteWidget> createState() =>
      _DatosPersonalesFlotanteWidgetState();
}

class _DatosPersonalesFlotanteWidgetState
    extends State<DatosPersonalesFlotanteWidget> {
  static const Color _bg = AppColors.bg;
  static const Color _textColor = AppColors.text;

  bool get _esPrestador {
    if (widget.modoPrestador != null) return widget.modoPrestador!;
    final d = UserSession().datosCompletos;
    return d?['es_trabajador'] == true || d?['rol'] == 'trabajador';
  }

  Color get primaryColor =>
      AppColors.primaryFor(modoPrestador: _esPrestador);

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
  String? _generoDocumento;

  bool _tieneWhatsapp = false;
  bool _loading = true;
  bool _saving = false;
  bool _procesandoOcr = false;

  bool _docValidado = false;
  String? _docHashDatos;


  @override
  void initState() {
    super.initState();
    _docNumeroController.addListener(() {
      if (mounted) setState(() {});
    });
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
        final data = await IdentidadPii.mezclar(uid, doc.data()!);
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
        final g = (data['genero_documento'] ?? data['sexo_documento'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (g == 'mujer' || g == 'hombre' || g == 'no_binario') {
          _generoDocumento = g;
        } else if (g == 'f' || g == 'femenino' || g == 'female') {
          _generoDocumento = 'mujer';
        } else if (g == 'm' || g == 'masculino' || g == 'male') {
          _generoDocumento = 'hombre';
        } else if (g == 'x' || g == 'nb' || g == 'no binario' || g == 'nobinario') {
          _generoDocumento = 'no_binario';
        }
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

  String? _validarTelefono(String? v) => TelefonoAr.validar(v);

  InputDecoration _dec(String label, {String? hint, String? helper}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primaryColor, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
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
      if (picked != null && mounted) setState(() => _fechaNacimiento = picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el calendario: $e')),
        );
      }
    }
  }

  Future<void> _actualizarDatos() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = UserSession().uid;
    if (uid == null) return;
    final docNum = _docNumeroController.text.trim();
    if (docNum.isNotEmpty && (_generoDocumento == null || _generoDocumento!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Si cargas numero de documento, indica Mujer, Hombre o No binario.'),
        ),
      );
      return;
    }
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
      final payload = <String, dynamic>{
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'tiene_whatsapp': _tieneWhatsapp,
        'tipo_doc': _tipoDoc,
        'pais_doc': _paisDoc,
        'doc_numero': _docNumeroController.text.trim(),
        'genero_documento': _generoDocumento,
        'fecha_nacimiento': _fechaNacimiento != null
            ? Timestamp.fromDate(_fechaNacimiento!)
            : null,
        'email': email1,
        'instagram': _instagramController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
        'doc_validado': _docValidado,
      };
      await UsuarioListSync.mergeUserDoc(uid, payload);
      final session = UserSession();
      session.nombre = _nombreController.text.trim();
      session.apellido = _apellidoController.text.trim();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos actualizados correctamente'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: _textColor,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Datos personales',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _sectionCard(
                    icon: Icons.badge_outlined,
                    title: 'Quien sos',
                    subtitle: 'Nombre y como te contactan',
                    children: [
                      _buildField('Nombre *', _nombreController, required: true),
                      _buildField('Apellido *', _apellidoController, required: true),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _telefonoController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  TelefonoAr.allowChars,
                                  TelefonoAr.lengthLimit,
                                  TelefonoInputFormatter(),
                                ],
                                decoration: _dec(
                                  'Celular *',
                                  hint: TelefonoAr.hint(),
                                  helper: TelefonoAr.helper(),
                                ),
                                validator: _validarTelefono,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _tieneWhatsapp ? const Color(0xFFDCFCE7) : Colors.white,
                                border: Border.all(
                                  color: _tieneWhatsapp
                                      ? const Color(0xFF86EFAC)
                                      : Colors.grey.shade200,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.chat_rounded,
                                    size: 18,
                                    color: _tieneWhatsapp
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('WhatsApp', style: TextStyle(fontSize: 10)),
                                  SizedBox(
                                    height: 28,
                                    child: Checkbox(
                                      value: _tieneWhatsapp,
                                      activeColor: const Color(0xFF16A34A),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (v) =>
                                          setState(() => _tieneWhatsapp = v ?? false),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    icon: Icons.credit_card_outlined,
                    title: 'Documento',
                    subtitle: 'Base de la confianza de perfil',
                    children: [
                      _buildDropdown(
                        'Tipo de documento',
                        _tipoDoc,
                        DocCatalog.tipos(current: _tipoDoc),
                        (v) => setState(() => _tipoDoc = v),
                      ),
                      _buildDropdown(
                        'Pais de emision',
                        _paisDoc,
                        DocCatalog.paisesEmisor(current: _paisDoc),
                        (v) => setState(() => _paisDoc = v),
                      ),
                      _buildField('Numero de documento', _docNumeroController),
                      _buildGeneroDocumento(),
                      _buildFechaNacimiento(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    icon: Icons.mail_outline_rounded,
                    title: 'Contacto digital',
                    subtitle: 'Email e Instagram',
                    children: [
                      _buildField('Email', _emailController,
                          keyboard: TextInputType.emailAddress),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _emailConfirmController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dec('Confirmar email'),
                          validator: (v) {
                            if (_emailController.text.trim() != (v ?? '').trim()) {
                              return 'Los emails no coinciden';
                            }
                            return null;
                          },
                        ),
                      ),
                      _buildField('Usuario de Instagram', _instagramController,
                          hint: '@usuario'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _actualizarDatos,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _saving ? 'Guardando...' : 'Guardar datos',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: primaryColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: primaryColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _textColor)),
                              Text(subtitle,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool required = false, TextInputType? keyboard, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: _dec(label, hint: hint),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
            : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value != null && items.contains(value) ? value : null,
        decoration: _dec(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildGeneroDocumento() {
    const opciones = [
      {'id': 'mujer', 'label': 'Mujer'},
      {'id': 'hombre', 'label': 'Hombre'},
      {'id': 'no_binario', 'label': 'No binario'},
    ];
    final docTieneNumero = _docNumeroController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            docTieneNumero
                ? 'Como figura en el documento *'
                : 'Como figura en el documento',
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opciones.map((o) {
              final id = o['id']!;
              final selected = _generoDocumento == id;
              return ChoiceChip(
                label: Text(o['label']!),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _generoDocumento = selected ? null : id),
                selectedColor: primaryColor.withOpacity(0.18),
                labelStyle: TextStyle(
                  color: selected ? primaryColor : _textColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                side: BorderSide(
                    color: selected ? primaryColor : Colors.grey.shade300),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
        ],
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
          decoration: _dec('Fecha de nacimiento')
              .copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined)),
          child: Text(
            _fechaNacimiento != null
                ? '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/${_fechaNacimiento!.month.toString().padLeft(2, '0')}/${_fechaNacimiento!.year}'
                : 'Seleccionar fecha',
            style: TextStyle(
              color: _fechaNacimiento != null ? _textColor : Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
