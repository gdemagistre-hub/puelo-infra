import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';

class ValidarDomicilioWidget extends StatefulWidget {
  final String? usuarioId;

  const ValidarDomicilioWidget({super.key, this.usuarioId});

  @override
  State<ValidarDomicilioWidget> createState() => _ValidarDomicilioWidgetState();
}

class _ValidarDomicilioWidgetState extends State<ValidarDomicilioWidget> {
  final db = FirebaseFirestore.instance;
  final uuid = const Uuid();

  static const Color primaryColor = AppColors.cliente;
  static const Color accentColor = Color(0xFFF0EBFB);
  static const Color textColor = AppColors.text;

  bool _loading = true;
  String? _error;
  String _nombreTarget = '';

  int _paso = 0;
  bool? _conoce;
  List<String> _opcionesDomicilio = [];
  String? _domicilioReal;
  String? _domicilioSeleccionado;
  String? _tiempoViviendo;

  final List<String> _opcionesTiempo = [
    'Menos de 1 año',
    'Entre 1 y 5 años',
    'Más de 5 años',
    'No sabe',
  ];

  @override
  void initState() {
    super.initState();
    _cargarTarget();
  }

  Future<void> _cargarTarget() async {
    if (widget.usuarioId == null || widget.usuarioId!.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Enlace inválido.';
      });
      return;
    }

    try {
      final doc = await db.collection('usuarios').doc(widget.usuarioId).get();
      if (!doc.exists) {
        setState(() {
          _loading = false;
          _error = 'La persona no existe o el enlace ya no es válido.';
        });
        return;
      }

      final data = doc.data()!;
      final calle = (data['calle'] ?? '').toString().trim();
      final numero = (data['numero'] ?? '').toString().trim();
      final geo = data['direccion_geo'] as Map<String, dynamic>?;

      if (calle.isEmpty ||
          numero.isEmpty ||
          geo == null ||
          geo['localidad_id'] == null) {
        setState(() {
          _loading = false;
          _error =
              'Esta persona todavía no tiene un domicilio completo cargado.';
        });
        return;
      }

      final localidadNombre =
          await _resolverLocalidadNombre(geo['localidad_id']?.toString());
      _domicilioReal = '$calle $numero, $localidadNombre';

      _nombreTarget =
          '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
      if (_nombreTarget.isEmpty) _nombreTarget = 'esta persona';

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '${AppCopy.errorGenerico} ($e)';
      });
    }
  }

  Future<String> _resolverLocalidadNombre(String? id) async {
    if (id == null || id.isEmpty) return 'Localidad desconocida';
    try {
      final q = await db
          .collection('cat_localidades')
          .where('localidad_id', isEqualTo: id)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        return q.docs.first.data()['localidad_nombre']?.toString() ??
            'Localidad desconocida';
      }
    } catch (_) {}
    return 'Localidad desconocida';
  }

  Future<void> _cargarOpcionesDomicilio() async {
    setState(() => _loading = true);

    try {
      final List<String> opciones = [_domicilioReal!];

      final query = await db
          .collection('usuarios')
          .where('perfil_completo', isEqualTo: true)
          .limit(30)
          .get();

      final List<String> candidatas = [];
      for (var d in query.docs) {
        if (d.id == widget.usuarioId) continue;
        final data = d.data();
        final calle = (data['calle'] ?? '').toString().trim();
        final numero = (data['numero'] ?? '').toString().trim();
        final geo = data['direccion_geo'] as Map<String, dynamic>?;
        if (calle.isEmpty ||
            numero.isEmpty ||
            geo == null ||
            geo['localidad_id'] == null) {
          continue;
        }

        final locNombre =
            await _resolverLocalidadNombre(geo['localidad_id']?.toString());
        final dir = '$calle $numero, $locNombre';
        if (dir != _domicilioReal && !candidatas.contains(dir)) {
          candidatas.add(dir);
        }
        if (candidatas.length >= 8) break;
      }

      candidatas.shuffle();
      opciones.addAll(candidatas.take(2));

      while (opciones.length < 3) {
        opciones.add(_domicilioReal!);
      }

      opciones.shuffle();
      _opcionesDomicilio = opciones;
    } catch (e) {
      _opcionesDomicilio = [_domicilioReal!, _domicilioReal!, _domicilioReal!];
    }

    setState(() => _loading = false);
  }

  Future<void> _avanzar() async {
    if (_paso == 0) {
      if (_conoce == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Respondé si conocés a la persona.'),
          ),
        );
        return;
      }
      await _cargarOpcionesDomicilio();
      setState(() => _paso = 1);
      return;
    }

    if (_paso == 1) {
      if (_domicilioSeleccionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Elegí el domicilio que corresponde.'),
          ),
        );
        return;
      }
      setState(() => _paso = 2);
      return;
    }

    if (_tiempoViviendo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí una opción de tiempo.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final token = uuid.v4();
      final esCorrecto = _domicilioSeleccionado == _domicilioReal;

      // Admin path: Cloud Function (ignora rules del cliente)
      final uri = Uri.parse(
        'https://southamerica-east1-lifewalletpuelo.cloudfunctions.net/submitValidacionPendiente',
      );
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'targetUserId': widget.usuarioId,
              'targetNombre': _nombreTarget,
              'conoce': _conoce,
              'domicilioSeleccionado': _domicilioSeleccionado,
              'domicilioReal': _domicilioReal,
              'esCorrecto': esCorrecto,
              'tiempoViviendo': _tiempoViviendo,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError(
          'No se pudo guardar la validación (${resp.statusCode}): ${resp.body}',
        );
      }

      UserSession().setPendingValidacion(token);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreenWidget()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppCopy.errorGenerico} ($e)')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _paso == 0) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: textColor),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Ayudar a validar'),
        backgroundColor: Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Tu ayuda genera confianza en el barrio.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(3, (i) {
                            return Expanded(
                              child: Container(
                                height: 4,
                                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                decoration: BoxDecoration(
                                  color: i <= _paso
                                      ? primaryColor
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 28),
                        if (_paso == 0) _buildPasoConoce(),
                        if (_paso == 1) _buildPasoDomicilio(),
                        if (_paso == 2) _buildPasoTiempo(),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _avanzar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _paso < 2 ? 'Continuar' : 'Enviar respuesta',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPasoConoce() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Conocés a $_nombreTarget?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'No pedimos datos bancarios. Solo confirmás si la conocés de verdad.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: _buildOpcionBoton(
                texto: 'Sí, lo/a conozco',
                seleccionado: _conoce == true,
                onTap: () => setState(() => _conoce = true),
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOpcionBoton(
                texto: 'No lo/a conozco',
                seleccionado: _conoce == false,
                onTap: () => setState(() => _conoce = false),
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasoDomicilio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Cuál es el domicilio de $_nombreTarget?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Elegí la opción que coincide con la dirección real.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        ..._opcionesDomicilio.map((dir) {
          final seleccionado = _domicilioSeleccionado == dir;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _domicilioSeleccionado = dir),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: seleccionado ? accentColor : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        seleccionado ? primaryColor : Colors.grey.shade300,
                    width: seleccionado ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      seleccionado
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: seleccionado ? primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dir,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: seleccionado
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPasoTiempo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Hace cuánto vive $_nombreTarget ahí?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Si no estás seguro, elegí “No sabe”.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        ..._opcionesTiempo.map((op) {
          final seleccionado = _tiempoViviendo == op;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _tiempoViviendo = op),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: seleccionado ? accentColor : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        seleccionado ? primaryColor : Colors.grey.shade300,
                    width: seleccionado ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      seleccionado
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: seleccionado ? primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      op,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: seleccionado
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOpcionBoton({
    required String texto,
    required bool seleccionado,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: seleccionado ? color : textColor,
          ),
        ),
      ),
    );
  }
}
