import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'user_session.dart';

class DatosPersonalesFlotanteWidget extends StatefulWidget {
  const DatosPersonalesFlotanteWidget({super.key});

  @override
  State<DatosPersonalesFlotanteWidget> createState() => _DatosPersonalesFlotanteWidgetState();
}

class _DatosPersonalesFlotanteWidgetState extends State<DatosPersonalesFlotanteWidget> {
  final primaryColor = const Color(0xFF0F52BA);
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _docNumeroController = TextEditingController();
  final _emailController = TextEditingController();
  final _instagramController = TextEditingController();

  String? _tipoDoc;
  String? _paisDoc;
  DateTime? _fechaNacimiento;
  String? _urlFotoDocumento;
  bool _loading = true;
  bool _saving = false;

  final List<String> _tiposDoc = ['DNI', 'Pasaporte', 'CI', 'CUIT', 'Otro'];
  final List<String> _paises = ['Argentina', 'Uruguay', 'Chile', 'Paraguay', 'Brasil', 'Bolivia', 'Otro'];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _docNumeroController.dispose();
    _emailController.dispose();
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
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nombreController.text = (data['nombre'] ?? '').toString();
        _apellidoController.text = (data['apellido'] ?? '').toString();
        _docNumeroController.text = (data['doc_numero'] ?? data['numero_documento'] ?? '').toString();
        _emailController.text = (data['email'] ?? '').toString();
        _instagramController.text = (data['instagram'] ?? data['usuario_instagram'] ?? '').toString();
        _tipoDoc = data['tipo_doc'] ?? data['tipo_documento'];
        _paisDoc = data['pais_doc'] ?? data['pais_emision'];
        _urlFotoDocumento = data['url_foto_documento']?.toString();

        if (data['fecha_nacimiento'] != null) {
          if (data['fecha_nacimiento'] is Timestamp) {
            _fechaNacimiento = (data['fecha_nacimiento'] as Timestamp).toDate();
          } else if (data['fecha_nacimiento'] is String) {
            _fechaNacimiento = DateTime.tryParse(data['fecha_nacimiento']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos personales: $e');
    }

    setState(() => _loading = false);
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
      debugPrint('Error showDatePicker: $e');
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

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'tipo_doc': _tipoDoc,
        'pais_doc': _paisDoc,
        'doc_numero': _docNumeroController.text.trim(),
        'fecha_nacimiento': _fechaNacimiento != null ? Timestamp.fromDate(_fechaNacimiento!) : null,
        'email': _emailController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

    setState(() => _saving = false);
  }

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
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildField('Nombre', _nombreController, required: true),
                  _buildField('Apellido', _apellidoController, required: true),
                  _buildDropdown('Tipo de documento', _tipoDoc, _tiposDoc, (v) => setState(() => _tipoDoc = v)),
                  _buildDropdown('País de emisión', _paisDoc, _paises, (v) => setState(() => _paisDoc = v)),
                  _buildField('Número de documento', _docNumeroController),
                  _buildFechaNacimiento(),
                  _buildFotoDocumento(),
                  _buildField('Email', _emailController, keyboard: TextInputType.emailAddress),
                  _buildField('Usuario de Instagram', _instagramController, hint: '@usuario'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _actualizarDatos,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Guardando...' : 'Actualizar los datos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          const Text('Foto del documento', style: TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 8),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              image: _urlFotoDocumento != null && _urlFotoDocumento!.isNotEmpty
                  ? DecorationImage(image: NetworkImage(_urlFotoDocumento!), fit: BoxFit.cover)
                  : null,
            ),
            child: _urlFotoDocumento == null || _urlFotoDocumento!.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_outlined, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text('Sin foto cargada', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
