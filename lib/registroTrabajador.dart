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
  final db = FirebaseFirestore.instance;

  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _documentoController;
  late TextEditingController _nombreComercialController;
  late TextEditingController _telefonoController;

  List<String> _profesionesSeleccionadas = [];
  List<String> _opcionesProfesiones = [];
  bool _cargandoCatalogos = true;

  // ESTADO GEOGRÁFICO - CASCADA Y MEMORIA LOCAL
  String? _paisSeleccionadoId = 'AR'; 
  String? _paisSeleccionadoNombre = 'Argentina';
  String? _provinciaSeleccionadaId;
  String? _provinciaSeleccionadaNombre;
  
  List<Map<String, String>> _partidosSeleccionados = []; 
  List<Map<String, String>> _localidadesSeleccionadas = [];

  // Datos en memoria descargados al elegir la Provincia
  List<Map<String, dynamic>> _todasLasProvincias = [];
  List<Map<String, dynamic>> _partidosDeProvincia = [];
  List<Map<String, dynamic>> _localidadesDeProvincia = [];
  bool _cargandoZonas = false;

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
    _cargarProvincias();
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
      final oficiosSnapshot = await db.collection('cat_oficios').limit(1).get();
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

  // --- LÓGICA GEOGRÁFICA ---

  Future<void> _cargarProvincias() async {
    try {
      final doc = await db.collection('cat_paises').doc('AR').get();
      if (doc.exists && doc.data()!.containsKey('provincias')) {
        setState(() {
          _todasLasProvincias = List<Map<String, dynamic>>.from(doc.data()!['provincias']);
        });
      }
    } catch (e) {
      print("Error cargando provincias: $e");
    }
  }

  Future<void> _seleccionarProvincia(Map<String, String> prov) async {
    setState(() {
      _cargandoZonas = true;
      _provinciaSeleccionadaId = prov['id'];
      _provinciaSeleccionadaNombre = prov['nombre'];
      
      // Limpiamos selecciones y memoria anterior
      _partidosSeleccionados.clear();
      _localidadesSeleccionadas.clear();
      _partidosDeProvincia.clear();
      _localidadesDeProvincia.clear();
    });

    try {
      // Descargamos TODOS los partidos de la provincia
      final depQuery = await db.collection('cat_departamentos')
          .where('provincia_id', isEqualTo: prov['id']).get();
      
      // Descargamos TODAS las localidades de la provincia
      final locQuery = await db.collection('cat_localidades')
          .where('provincia_id', isEqualTo: prov['id']).get();

      setState(() {
        _partidosDeProvincia = depQuery.docs.map((d) => d.data()).toList();
        _localidadesDeProvincia = locQuery.docs.map((d) => d.data()).toList();
        _cargandoZonas = false;
      });
    } catch (e) {
      print("Error cargando zonas: $e");
      setState(() => _cargandoZonas = false);
    }
  }

  void _actualizarLocalidadesSegunPartidos(List<Map<String, String>> nuevosPartidos) {
    setState(() {
      _partidosSeleccionados = nuevosPartidos;
      
      // Si el usuario desmarcó un partido, removemos las localidades que pertenecían a él
      final idsPartidosSeleccionados = nuevosPartidos.map((p) => p['id']).toList();
      
      _localidadesSeleccionadas.removeWhere((locSeleccionada) {
        final locDataOriginal = _localidadesDeProvincia.firstWhere(
          (l) => l['localidad_id'] == locSeleccionada['id'],
          orElse: () => {},
        );
        if (locDataOriginal.isEmpty) return true;
        
        return !idsPartidosSeleccionados.contains(locDataOriginal['partido_id']);
      });
    });
  }


  // --- DIÁLOGOS DE INTERFAZ ---

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

  // --- GUARDAR DATOS ---

  void _crearTarjetaProfesional() async {
    if (_nombreController.text.trim().isEmpty || _apellidoController.text.trim().isEmpty || _provinciaSeleccionadaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa los datos obligatorios y la zona.')),
      );
      return;
    }

    try {
      final nuevoUsuarioRef = db.collection('usuarios').doc();
      
      await nuevoUsuarioRef.set({
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'documento': _documentoController.text.trim(),
        'nombre_comercial': _nombreComercialController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'profesiones': _profesionesSeleccionadas,
        'creado_en': FieldValue.serverTimestamp(),
        'rol': 'trabajador',
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
                    
                    // Selector País (Por ahora fijo en AR)
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
                            });
                          }
                        );
                      }
                    ),

                    // Selector Provincia (Dinámico desde base)
                    _buildSelectorWidget(
                      label: 'Provincia',
                      valor: _provinciaSeleccionadaNombre ?? 'Seleccionar Provincia',
                      onTap: () {
                        List<Map<String, String>> opciones = _todasLasProvincias.map((p) {
                          return {'id': p['id'].toString(), 'nombre': p['nombre'].toString()};
                        }).toList();

                        _mostrarSeleccionUnica(
                          titulo: 'Seleccionar Provincia',
                          opciones: opciones,
                          onConfirm: _seleccionarProvincia
                        );
                      }
                    ),

                    // Indicador de carga de zonas
                    if (_cargandoZonas)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    // Selector Partido (Múltiple, filtrado en memoria)
                    _buildSelectorWidget(
                      label: 'Partidos / Departamentos',
                      valor: _partidosSeleccionados.isEmpty 
                          ? 'Seleccionar (Múltiple)' 
                          : _partidosSeleccionados.map((e) => e['nombre']).join(', '),
                      onTap: _provinciaSeleccionadaId == null || _cargandoZonas ? null : () {
                        
                        List<Map<String, String>> opcionesPartidos = _partidosDeProvincia.map((p) {
                          return {
                            'id': p['departamento_id'].toString(), 
                            'nombre': p['departamento_nombre'].toString()
                          };
                        }).toList();

                        _mostrarSeleccionMultiple(
                          titulo: 'Seleccionar Partidos',
                          opciones: opcionesPartidos,
                          seleccionadas: _partidosSeleccionados,
                          onConfirm: _actualizarLocalidadesSegunPartidos
                        );
                      }
                    ),

                    // Selector Localidad (Múltiple, filtrado en memoria por los partidos elegidos)
                    _buildSelectorWidget(
                      label: 'Localidades',
                      valor: _localidadesSeleccionadas.isEmpty 
                          ? 'Seleccionar Localidades (Múltiple)' 
                          : _localidadesSeleccionadas.map((e) => e['nombre']).join(', '),
                      onTap: _partidosSeleccionados.isEmpty || _cargandoZonas ? null : () {
                        
                        // Solo mostramos localidades cuyos partidos fueron seleccionados
                        final idsPartidos = _partidosSeleccionados.map((p) => p['id']).toList();
                        final locsFiltradas = _localidadesDeProvincia.where((l) => idsPartidos.contains(l['partido_id']));

                        List<Map<String, String>> opcionesLocalidades = locsFiltradas.map((l) {
                          return {
                            'id': l['localidad_id'].toString(), 
                            'nombre': l['localidad_nombre'].toString()
                          };
                        }).toList();

                        _mostrarSeleccionMultiple(
                          titulo: 'Seleccionar Localidades',
                          opciones: opcionesLocalidades,
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
