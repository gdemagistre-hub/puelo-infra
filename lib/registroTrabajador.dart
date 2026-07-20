import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Homepage.dart';

class RegistroTrabajadorWidget extends StatefulWidget {
  const RegistroTrabajadorWidget({super.key});

  static const String routeName = 'registroTrabajador';
  static const String routePath = '/registroTrabajador';

  @override
  State<RegistroTrabajadorWidget> createState() => _RegistroTrabajadorWidgetState();
}

class _RegistroTrabajadorWidgetState extends State<RegistroTrabajadorWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _documentoController;
  late TextEditingController _nombreComercialController;
  late TextEditingController _telefonoController;

  final FocusNode _nombreFocusNode = FocusNode();
  final FocusNode _apellidoFocusNode = FocusNode();
  final FocusNode _documentoFocusNode = FocusNode();
  final FocusNode _nombreComercialFocusNode = FocusNode();
  final FocusNode _telefonoFocusNode = FocusNode();

  List<String> _profesionesSeleccionadas = [];
  List<String> _opcionesProfesiones = [];
  bool _cargandoCatalogos = true;

  // NUEVO ESTADO GEOGRÁFICO CASCADA
  String? _paisSeleccionadoId = 'AR'; // Por defecto Argentina
  String? _paisSeleccionadoNombre = 'Argentina';
  String? _provinciaSeleccionadaId;
  String? _provinciaSeleccionadaNombre;
  
  List<Map<String, String>> _partidosSeleccionados = []; // [{id, nombre}]
  List<Map<String, String>> _localidadesSeleccionadas = []; // [{id, nombre}]

  final primaryColor = const Color(0xFF0F52BA); 
  final accentColor = const Color(0xFFE8F0FE);  
  final textColor = const Color(0xFF1E293B);    
  final inputBgColor = const Color(0xFFF8FAFC); 

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _apellidoController = TextEditingController();
    _documentoController = TextEditingController();
    _nombreComercialController = TextEditingController();
    _telefonoController = TextEditingController();
    _cargarCatalogos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _documentoController.dispose();
    _nombreComercialController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final oficiosSnapshot = await FirebaseFirestore.instance.collection('cat_oficios').limit(1).get();
      if (oficiosSnapshot.docs.isNotEmpty) {
        final data = oficiosSnapshot.docs.first.data();
        final List<dynamic>? maestro = data['maestro'] as List<dynamic>?;
        if (maestro != null) {
          _opcionesProfesiones = maestro.map((e) => e.toString()).toList();
        }
      }
      setState(() => _cargandoCatalogos = false);
    } catch (e) {
      setState(() => _cargandoCatalogos = false);
    }
  }

  // DIÁLOGO SELECCIÓN ÚNICA (País / Provincia)
  void _mostrarSeleccionUnica({
    required String titulo,
    required List<Map<String, String>> opciones,
    required Function(Map<String, String>) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: opciones.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(opciones[index]['nombre']!, style: TextStyle(color: textColor)),
                  onTap: () {
                    onConfirm(opciones[index]);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // DIÁLOGO SELECCIÓN MÚLTIPLE (Partidos / Localidades)
  void _mostrarSeleccionMultiple({
    required String titulo,
    required List<Map<String, String>> opciones,
    required List<Map<String, String>> seleccionadas,
    required Function(List<Map<String, String>>) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        List<Map<String, String>> tempSeleccionadas = List.from(seleccionadas);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              content: SizedBox(
                width: double.maxFinite,
                child: opciones.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('Primero debés seleccionar el filtro anterior.', textAlign: TextAlign.center),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: opciones.length,
                        itemBuilder: (context, index) {
                          final item = opciones[index];
                          final isChecked = tempSeleccionadas.any((e) => e['id'] == item['id']);
                          return CheckboxListTile(
                            title: Text(item['nombre']!, style: TextStyle(color: textColor)),
                            value: isChecked,
                            activeColor: primaryColor,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  tempSeleccionadas.add(item);
                                } else {
                                  tempSeleccionadas.removeWhere((e) => e['id'] == item['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSeleccionadas);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _crearTarjetaProfesional() async {
    if (_nombreController.text.trim().isEmpty || _apellidoController.text.trim().isEmpty || _provinciaSeleccionadaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa los datos obligatorios y la zona.')),
      );
      return;
    }

    try {
      final nuevoUsuarioRef = FirebaseFirestore.instance.collection('usuarios').doc();
      
      await nuevoUsuarioRef.set({
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'documento': _documentoController.text.trim(),
        'nombre_comercial': _nombreComercialController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'profesiones': _profesionesSeleccionadas,
        'creado_en': FieldValue.serverTimestamp(),
        'rol': 'trabajador',
        // NUEVA ESTRUCTURA GEOGRÁFICA MAPA EN FIRESTORE
        'zonas_cobertura': {
          'pais_id': _paisSeleccionadoId,
          'pais_nombre': _paisSeleccionadoNombre,
          'provincia_id': _provinciaSeleccionadaId,
          'provincia_nombre': _provinciaSeleccionadaNombre,
          'partidos': _partidosSeleccionados,
          'localidades': _localidadesSeleccionadas,
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil profesional creado correctamente')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePageWidget()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Completar Perfil Profesional'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader('Datos Personales'),
                    _buildTextField(controller: _nombreController, hintText: 'Nombre', icon: Icons.person_outline_rounded),
                    _buildTextField(controller: _apellidoController, hintText: 'Apellido', icon: Icons.person_outline_rounded),
                    _buildTextField(controller: _documentoController, hintText: 'Documento', icon: Icons.badge_outlined, keyboardType: TextInputType.number),
                    _buildTextField(controller: _nombreComercialController, hintText: 'Nombre Comercial', icon: Icons.storefront_rounded),
                    _buildTextField(controller: _telefonoController, hintText: 'Teléfono', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),

                    _buildSectionHeader('Zonas de Cobertura (Filtro Geográfico)'),
                    
                    // Selector País
                    _buildSelectorWidget(
                      label: 'País',
                      valor: _paisSeleccionadoNombre ?? 'Seleccionar',
                      onTap: () {
                        _mostrarSeleccionUnica(
                          titulo: 'Seleccionar País',
                          opciones: [{'id': 'AR', 'nombre': 'Argentina'}],
                          onConfirm: (res) {
                            setState(() {
                              _paisSeleccionadoId = res['id'];
                              _paisSeleccionadoNombre = res['nombre'];
                              // Reset cascada
                              _provinciaSeleccionadaId = null;
                              _provinciaSeleccionadaNombre = null;
                              _partidosSeleccionados.clear();
                              _localidadesSeleccionadas.clear();
                            });
                          }
                        );
                      }
                    ),

                    // Selector Provincia
                    _buildSelectorWidget(
                      label: 'Provincia',
                      valor: _provinciaSeleccionadaNombre ?? 'Seleccionar Provincia',
                      onTap: () {
                        _mostrarSeleccionUnica(
                          titulo: 'Seleccionar Provincia',
                          opciones: [
                            {'id': '06', 'nombre': 'Buenos Aires'},
                            {'id': '14', 'nombre': 'Córdoba'},
                            {'id': '30', 'nombre': 'Entre Ríos'},
                            {'id': '70', 'nombre': 'San Juan'},
                          ],
                          onConfirm: (res) {
                            setState(() {
                              _provinciaSeleccionadaId = res['id'];
                              _provinciaSeleccionadaNombre = res['nombre'];
                              _partidosSeleccionados.clear();
                              _localidadesSeleccionadas.clear();
                            });
                          }
                        );
                      }
                    ),

                    // Selector Partido (Múltiple)
                    _buildSelectorWidget(
                      label: 'Partidos / Departamentos',
                      valor: _partidosSeleccionados.isEmpty 
                          ? 'Seleccionar (Múltiple)' 
                          : _partidosSeleccionados.map((e) => e['nombre']).join(', '),
                      onTap: _provinciaSeleccionadaId == null ? null : () {
                        // Mock de partidos según provincia
                        List<Map<String, String>> mockPartidos = _provinciaSeleccionadaId == '06' ? [
                          {'id': '06638', 'nombre': 'Pilar'},
                          {'id': '06134', 'nombre': 'Cañuelas'},
                          {'id': '06042', 'nombre': 'Ayacucho'}
                        ] : [
                          {'id': '14042', 'nombre': 'General San Martín'},
                          {'id': '14021', 'nombre': 'Colón'}
                        ];

                        _mostrarSeleccionMultiple(
                          titulo: 'Seleccionar Partidos',
                          opciones: mockPartidos,
                          seleccionadas: _partidosSeleccionados,
                          onConfirm: (res) {
                            setState(() {
                              _partidosSeleccionados = res;
                              _localidadesSeleccionadas.clear();
                            });
                          }
                        );
                      }
                    ),

                    // Selector Localidad (Múltiple)
                    _buildSelectorWidget(
                      label: 'Localidades',
                      valor: _localidadesSeleccionadas.isEmpty 
                          ? 'Seleccionar Localidades (Múltiple)' 
                          : _localidadesSeleccionadas.map((e) => e['nombre']).join(', '),
                      onTap: _partidosSeleccionados.isEmpty ? null : () {
                        // Mock de localidades filtradas por partidos seleccionados
                        List<Map<String, String>> mockLocs = [];
                        if (_partidosSeleccionados.any((e) => e['id'] == '06638')) {
                          mockLocs.add({'id': '06638040', 'nombre': 'Pilar'});
                        }
                        if (_partidosSeleccionados.any((e) => e['id'] == '06042')) {
                          mockLocs.addAll([
                            {'id': '06042010', 'nombre': 'Ayacucho'},
                            {'id': '06042020', 'nombre': 'La Constancia'}
                          ]);
                        }
                        if (mockLocs.isEmpty) {
                          mockLocs.add({'id': '1000', 'nombre': 'Localidad Centro'});
                        }

                        _mostrarSeleccionMultiple(
                          titulo: 'Seleccionar Localidades',
                          opciones: mockLocs,
                          seleccionadas: _localidadesSeleccionadas,
                          onConfirm: (res) {
                            setState(() {
                              _localidadesSeleccionadas = res;
                            });
                          }
                        );
                      }
                    ),

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _crearTarjetaProfesional,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Crear Tarjeta Profesional', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(width: 12),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, required IconData icon, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey),
          hintText: hintText,
          filled: true,
          fillColor: inputBgColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildSelectorWidget({required String label, required String valor, required VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: inputBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
