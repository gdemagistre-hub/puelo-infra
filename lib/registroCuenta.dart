import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'user_session.dart';
import 'email_service.dart';

class RegistroCuentaWidget extends StatefulWidget {
  const RegistroCuentaWidget({super.key});

  @override
  State<RegistroCuentaWidget> createState() => _RegistroCuentaWidgetState();
}

class _RegistroCuentaWidgetState extends State<RegistroCuentaWidget> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _docNumeroController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();

  String? _tipoDocSeleccionado;
  String? _paisSeleccionado;
  String _metodoValidacion = 'whatsapp'; // whatsapp | email

  bool _isLoading = false;
  String? _invitacionLink;
  String? _tokenValidacion;
  String? _linkValidacion;

  final db = FirebaseFirestore.instance;
  final uuid = const Uuid();

  final primaryColor = const Color(0xFF0F52BA);
  final inputBgColor = const Color(0xFFF8FAFC);

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _docNumeroController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _generarRegistro() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoDocSeleccionado == null || _paisSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completá el tipo y país de documento.')),
      );
      return;
    }

    if (_metodoValidacion == 'whatsapp' && _whatsappController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un número de WhatsApp válido.')),
      );
      return;
    }
    if (_metodoValidacion == 'email' && _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un email válido.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      _tokenValidacion = uuid.v4().substring(0, 8).toUpperCase();

      final Map<String, dynamic> dataUsuario = {
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'documento_tipo': _tipoDocSeleccionado,
        'documento_pais': _paisSeleccionado,
        'documento': _docNumeroController.text.trim(),
        'telefono': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'estado': 'pendiente_validacion',
        'token_validacion': _tokenValidacion,
        'metodo_validacion': _metodoValidacion,
        'creado_en': FieldValue.serverTimestamp(),
      };

      if (UserSession().pendingValidacionToken != null) {
        dataUsuario['pending_domicilio_token'] = UserSession().pendingValidacionToken;
      }

      await db.collection('usuarios').add(dataUsuario);

      _linkValidacion =
          'https://lifewalletpuelo.web.app/#/validar?token=$_tokenValidacion';

      if (_metodoValidacion == 'whatsapp') {
        final String numero =
            _whatsappController.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
        final String mensaje = Uri.encodeComponent(
          '¡Hola ${_nombreController.text.trim()}! 🚀\n\n'
          'Este es tu enlace para validar y activar tu cuenta en la plataforma Puelo.\n\n'
          'Por favor haz click aquí para confirmar tu identidad:\n\n'
          '$_linkValidacion',
        );
        _invitacionLink = 'https://wa.me/$numero?text=$mensaje';

        if (mounted) _mostrarPopupWhatsApp();
      } else {
        // Email: se envía solo vía EmailJS
        final ok = await EmailService.enviarValidacionCuenta(
          toEmail: _emailController.text.trim(),
          toName: _nombreController.text.trim(),
          validationLink: _linkValidacion!,
        );

        if (!ok) {
          throw Exception('EmailJS no aceptó el envío. Revisá la configuración.');
        }

        if (mounted) _mostrarPopupEmailEnviado();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar el registro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarPopupWhatsApp() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¡Cuenta creada!',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enviate el enlace de activación por WhatsApp para validar tu dispositivo y activar la cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _linkValidacion ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_linkValidacion != null) {
                await Clipboard.setData(ClipboardData(text: _linkValidacion!));
              }
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Copiar link y cerrar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final Uri url = Uri.parse(_invitacionLink!);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Validar por WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarPopupEmailEnviado() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¡Email enviado!',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 48, color: Color(0xFF0F52BA)),
            const SizedBox(height: 16),
            Text(
              'Enviamos un correo a\n${_emailController.text.trim()}\n\n'
              'Abrí el email y hacé click en el enlace para activar tu cuenta.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Si no lo ves, revisá la carpeta de spam.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Crear nueva cuenta'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Datos Personales',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Completá tus datos reales para validar tu identidad en la comunidad.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _nombreController,
                  labelText: 'Nombre',
                  icon: Icons.person_outline_rounded,
                  obligatorio: true,
                ),
                _buildTextField(
                  controller: _apellidoController,
                  labelText: 'Apellido',
                  icon: Icons.person_outline_rounded,
                  obligatorio: true,
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _tipoDocSeleccionado,
                        decoration: _inputDeco('Tipo Doc.', true),
                        items: ['DNI', 'Pasaporte', 'Cédula']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) => setState(() => _tipoDocSeleccionado = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _paisSeleccionado,
                        decoration: _inputDeco('País Emisor', true),
                        items: ['Argentina', 'Uruguay', 'Chile', 'Otro']
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (val) => setState(() => _paisSeleccionado = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _docNumeroController,
                  labelText: 'Número de Documento',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  obligatorio: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Método de validación',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('WhatsApp'),
                        selected: _metodoValidacion == 'whatsapp',
                        selectedColor: primaryColor.withOpacity(0.2),
                        onSelected: (_) => setState(() => _metodoValidacion = 'whatsapp'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Email'),
                        selected: _metodoValidacion == 'email',
                        selectedColor: primaryColor.withOpacity(0.2),
                        onSelected: (_) => setState(() => _metodoValidacion = 'email'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_metodoValidacion == 'whatsapp')
                  _buildTextField(
                    controller: _whatsappController,
                    labelText: 'Número de WhatsApp (ej: +54911...)',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    obligatorio: true,
                  )
                else
                  _buildTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    obligatorio: true,
                  ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _generarRegistro,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Registrarme y Validar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required bool obligatorio,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey),
          label: RichText(
            text: TextSpan(
              text: labelText,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
              children: obligatorio
                  ? const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ]
                  : [],
            ),
          ),
          filled: true,
          fillColor: inputBgColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: obligatorio
            ? (value) =>
                value == null || value.trim().isEmpty ? 'Este campo es obligatorio' : null
            : null,
      ),
    );
  }

  InputDecoration _inputDeco(String labelText, bool obligatorio) {
    return InputDecoration(
      label: RichText(
        text: TextSpan(
          text: labelText,
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
          children: obligatorio
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ]
              : [],
        ),
      ),
      filled: true,
      fillColor: inputBgColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
