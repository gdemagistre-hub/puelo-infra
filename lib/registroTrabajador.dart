import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Homepage.dart';
import 'user_session.dart'; // Importamos el Singleton de sesión

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

  String? _selectedUsuarioId;
  bool _cargandoDatosIniciales = true;

  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _documentoController;
  late TextEditingController _nombreComercialController;
  late TextEditingController _telefonoController;

  List<String> _profesionesSeleccionadas = [];
  List<String> _opcionesProfesiones = [];

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

    _selectedUsuarioId = UserSession().uid;
    _inicializarPantalla();
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

  // ==========================================
  // CARGA INICIAL
  // ==========================================
  Future<void> _inicializarPantalla() async {
    setState(() => _cargandoDatosIniciales = true);

    await Future.wait([
      _cargarCatalogos(),
      _cargarProvincias(),
      if (_selectedUsuarioId != null) _cargarDatosUsuarioActual(),
    ]);

    setState(() => _cargandoDatosIniciales = false);
  }

  Future<void> _cargarDatosUsuarioActual() async {
    try {
      final doc = await db.collection('usuarios').doc(_selectedUsuarioId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nombreController.text = data['nombre'] ?? '';
        _apellidoController.text = data['apellido'] ?? '';
        _documentoController.text = data['documento'] ?? '';
        _nombreComercialController.text = data['nombre_comercial'] ?? '';
        _telefonoController.text = data['telefono'] ?? '';
        
        // Si ya tenía profesiones guardadas, las cargamos
        if (data['profesiones'] != null) {
          _profesionesSeleccionadas = List<String>.from(data['profesiones']);
        }
      }
    } catch (e) {
      debugPrint("Error cargando usuario: $e");
    }
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
    } catch (e) {
      debugPrint("Error cargando oficios: $e");
    }
  }

  // --- LÓGICA GEOGRÁFICA ---

  Future<void> _cargarProvincias() async {
    try {
      final doc = await db.collection('cat_paises').doc('AR').get();
      if (doc.exists && doc.data()!.containsKey('provincias')) {
        _todasLasProvincias = List<Map<String, dynamic>>.from(doc.data()!['provincias']);
      }
    } catch (e) {
      debugPrint("Error cargando provincias: $e");
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
      final depQuery = await db.collection('cat_departamentos')
          .where('provincia_id', isEqualTo: prov['id']).get();
      
      final locQuery = await db.collection('cat_localidades')
          .where('provincia_id', isEqualTo: prov['id']).get();

      setState(() {
        _partidosDeProvincia = depQuery.docs.map((d) => d.data()).toList();
        _localidadesDeProvincia = locQuery.docs.map((d) => d.data()).toList();
        _cargandoZonas = false;
      });
    } catch (e) {
      debugPrint("Error cargando zonas: $e");
      setState(() => _cargandoZonas = false);
    }
  }

  void _actualizarLocalidadesSegunPartidos(List<Map<String, String>> nuevosPartidos) {
    setState(() {
      _partidosSeleccionados = nuevosPartidos;
      
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
    if (_selectedUsuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró la sesión del usuario.')),
      );
      return;
    }

    if (_nombreController.text.trim().isEmpty || 
        _apellidoController.text.trim().isEmpty || 
        _provinciaSeleccionadaId == null ||
        _profesionesSeleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completá los datos obligatorios, al menos una especialidad y la zona.')),
      );
      return;
    }

    try {
      // Ahora apuntamos al documento existente del usuario
      final usuarioRef = db.collection('usuarios').doc(_selectedUsuarioId);
      
      // Usamos SetOptions(merge: true) para actualizar o crear sin borrar los datos que ya existan (ej. foto de perfil)
      await usuarioRef.set({
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'documento': _documentoController.text.trim(),
        'nombre_comercial': _nombreComercialController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'profesiones': _profesionesSeleccionadas,
        'rol': 'trabajador',
        'es_trabajador': true, // Bandera clave para identificarlo como prestador
        'tarjeta_actualizada_en': FieldValue.serverTimestamp(),
        'zonas_cobertura': {
          'pais_id': _paisSeleccionadoId,
          'pais_nombre': _paisSeleccionadoNombre,
          'provincia_id': _provinciaSeleccionadaId,
          'provincia_nombre': _provinciaSeleccionadaNombre,
          'partidos': _partidosSeleccionados,
          'localidades': _localidadesSeleccionadas,
        }
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil profesional actualizado correctamente')),
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
    if (_selectedUsuarioId == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Iniciá sesión nuevamente para ver tu perfil.')),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Crear Perfil Profesional'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: _cargandoDatosIniciales
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionHeader('Datos Personales y Comerciales'),
                          _buildTextField(controller: _nombreController, hintText: 'Nombre', icon: Icons.person_outline_rounded),
                          _buildTextField(controller: _apellidoController, hintText: 'Apellido', icon: Icons.person_outline_rounded),
                          _buildTextField(controller: _documentoController, hintText: 'Documento', icon: Icons.badge_outlined, keyboardType: TextInputType.number),
                          _buildTextField(controller: _nombreComercialController, hintText: 'Nombre Comercial (Opcional)', icon: Icons.storefront_rounded),
                          _buildTextField(controller: _telefonoController, hintText: 'Teléfono (WhatsApp)', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),

                          _buildSectionHeader('Especialidades'),
                          _buildSelectorWidget(
                            label: 'Oficios / Especialidades',
                            valor: _profesionesSeleccionadas.isEmpty 
                                ? 'Seleccionar Especialidades' 
                                : _profesionesSeleccionadas.join(', '),
                            onTap: () {
                              List<Map<String, String>> opciones = _opcionesProfesiones.map((p) {
                                return {'id': p, 'nombre': p};
                              }).toList();

                              _mostrarSeleccionMultiple(
                                titulo: 'Especialidades',
                                opciones: opciones,
                                seleccionadas: _profesionesSeleccionadas.map((p) => {'id': p, 'nombre': p}).toList(),
                                onConfirm: (res) {
                                  setState(() {
                                    _profesionesSeleccionadas = res.map((e) => e['nombre']!).toList();
                                  });
                                }
                              );
                            }
                          ),

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
                            child: const Text('Activar Tarjeta Profesional', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
