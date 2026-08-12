import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'user_session.dart';
import 'email_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';

/// Alta mínima de cuenta.
/// Solo: nombre, apellido + canal de validación (WhatsApp o email).
/// Documento y rol prestador se completan después (datos personales / oficios).
class RegistroCuentaWidget extends StatefulWidget {
  const RegistroCuentaWidget({super.key});

  @override
  State<RegistroCuentaWidget> createState() => _RegistroCuentaWidgetState();
}

class _RegistroCuentaWidgetState extends State<RegistroCuentaWidget> {
  static const Color primaryColor = AppColors.cliente;
  static const Color textColor = AppColors.text;

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();

  String _metodoValidacion = 'whatsapp'; // whatsapp | email
  bool _isLoading = false;
  String? _tokenValidacion;
  String? _linkValidacion;
  String? _invitacionLink;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_metodoValidacion == 'whatsapp' &&
        _whatsappController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un número de WhatsApp')),
      );
      return;
    }
    if (_metodoValidacion == 'email' && _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un email')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;
    const uuid = Uuid();

    try {
      _tokenValidacion = uuid.v4().toUpperCase();

      final Map<String, dynamic> dataUsuario = {
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'telefono': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'tiene_whatsapp': _metodoValidacion == 'whatsapp',
        'es_trabajador': false,
        'estado': 'pendiente_validacion',
        'token_validacion': _tokenValidacion,
        'metodo_validacion': _metodoValidacion,
        'creado_en': FieldValue.serverTimestamp(),
      };

      if (UserSession().pendingValidacionToken != null) {
        dataUsuario['pending_domicilio_token'] =
            UserSession().pendingValidacionToken;
      }

      await db.collection('usuarios').add(dataUsuario);

      _linkValidacion =
          'https://lifewalletpuelo.web.app/#/validar?token=$_tokenValidacion';

      if (_metodoValidacion == 'whatsapp') {
        final String numero =
            _whatsappController.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
        final String mensaje = Uri.encodeComponent(
          'Hola ${_nombreController.text.trim()}!\n\n'
          'Este es tu enlace para activar tu cuenta en Puelo:\n\n'
          '$_linkValidacion',
        );
        _invitacionLink = 'https://wa.me/$numero?text=$mensaje';

        if (mounted) _mostrarPopupWhatsApp();
      } else {
        await EmailService.enviarValidacionCuenta(
          toEmail: _emailController.text.trim(),
          toName: _nombreController.text.trim(),
          validationLink: _linkValidacion!,
        );

        if (mounted) _mostrarPopupEmailEnviado();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppCopy.errorGenerico} ($e)')),
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
        title: const Text(
          'Cuenta creada',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enviate el enlace de activación por WhatsApp para confirmar y activar la cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_invitacionLink != null) {
                    final uri = Uri.parse(_invitacionLink!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                icon: const Icon(Icons.chat),
                label: const Text('Abrir WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarPopupEmailEnviado() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Revisá tu email',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Te enviamos un enlace para activar tu cuenta. Si no lo ves, mirá en spam.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _chipMetodo({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? primaryColor : textColor,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crear cuenta',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Text(
                'Tus datos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Con nombre y un contacto ya podés empezar. Documento y más datos los cargás después si querés.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apellidoController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Apellido *',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 28),
              const Text(
                'Cómo te validamos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _chipMetodo(
                    label: 'WhatsApp',
                    selected: _metodoValidacion == 'whatsapp',
                    onTap: () => setState(() => _metodoValidacion = 'whatsapp'),
                  ),
                  const SizedBox(width: 10),
                  _chipMetodo(
                    label: 'Email',
                    selected: _metodoValidacion == 'email',
                    onTap: () => setState(() => _metodoValidacion = 'email'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_metodoValidacion == 'whatsapp')
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                  decoration: InputDecoration(
                    labelText: 'WhatsApp *',
                    hintText: '54911...',
                    prefixIcon: const Icon(Icons.chat_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  validator: (v) {
                    if (_metodoValidacion != 'whatsapp') return null;
                    if (v == null || v.trim().isEmpty) return 'Obligatorio';
                    return null;
                  },
                )
              else
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  validator: (v) {
                    if (_metodoValidacion != 'email') return null;
                    if (v == null || v.trim().isEmpty) return 'Obligatorio';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Registrarme y validar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
