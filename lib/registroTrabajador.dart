import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistroTrabajadorWidget extends StatefulWidget {
  const RegistroTrabajadorWidget({super.key});

  static const String routeName = 'registroTrabajador';
  static const String routePath = '/registroTrabajador';

  @override
  State<RegistroTrabajadorWidget> createState() =>
      _RegistroTrabajadorWidgetState();
}

class _RegistroTrabajadorWidgetState extends State<RegistroTrabajadorWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Controladores de Texto Locales
  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _documentoController;
  late TextEditingController _nombreComercialController;
  late TextEditingController _telefonoController;

  // Nodos de Foco Locales
  final FocusNode _nombreFocusNode = FocusNode();
  final FocusNode _apellidoFocusNode = FocusNode();
  final FocusNode _documentoFocusNode = FocusNode();
  final FocusNode _nombreComercialFocusNode = FocusNode();
  final FocusNode _telefonoFocusNode = FocusNode();

  // Estados para selecciones múltiples
  List<String> _profesionesSeleccionadas = [];
  List<String> _zonasSeleccionadas = [];

  // Listas dinámicas que se llenarán desde Firestore
  List<String> _opcionesProfesiones = [];
  List<String> _opcionesZonas = [];
  bool _cargandoCatalogos = true;

  // Paleta de colores unificada para Puelo
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

    // Disparamos la carga de catálogos al iniciar la pantalla
    _cargarCatalogosDesdeFirestore();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _documentoController.dispose();
    _nombreComercialController.dispose();
    _telefonoController.dispose();

    _nombreFocusNode.dispose();
    _apellidoFocusNode.dispose();
    _documentoFocusNode.dispose();
    _nombreComercialFocusNode.dispose();
    _telefonoFocusNode.dispose();
    super.dispose();
  }

  // Método para leer los catálogos en tiempo real
  Future<void> _cargarCatalogosDesdeFirestore() async {
    try {
      // 1. Cargar Catálogo de Oficios
      final oficiosSnapshot = await FirebaseFirestore.instance.collection('cat_oficios').limit(1).get();
      List<String> oficiosCargados = [];
      if (oficiosSnapshot.docs.isNotEmpty) {
        final data = oficiosSnapshot.docs.first.data();
        final List<dynamic>? maestro = data['maestro'] as List<dynamic>?;
        if (maestro != null) {
          oficiosCargados = maestro.map((e) => e.toString()).toList();
        }
      }

      // 2. Cargar Catálogo de Zonas
      final zonasSnapshot = await FirebaseFirestore.instance.collection('cat_zonas').limit(1).get();
      List<String> zonasCargadas = [];
      if (zonasSnapshot.docs.isNotEmpty) {
        final data = zonasSnapshot.docs.first.data();
        final List<dynamic>? maestro = data['maestro'] as List<dynamic>?;
        if (maestro != null) {
          zonasCargadas = maestro.map((e) => e.toString()).toList();
        }
      }

      if (mounted) {
        setState(() {
          _opcionesProfesiones = oficiosCargados;
          _opcionesZonas = zonasCargadas;
          _cargandoCatalogos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoCatalogos = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar catálogos: $e')),
        );
      }
    }
  }

  // Helper para mostrar un diálogo de selección múltiple premium
  void _mostrarSeleccionMultiple({
    required String titulo,
    required List<String> opciones,
    required List<String> seleccionadas,
    required Function(List<String>) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSeleccionadas = List.from(seleccionadas);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              title: Text(
                titulo, 
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
              ),
              contentPadding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
              content: SizedBox(
                width: double.maxFinite,
                child: opciones.isEmpty 
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('No hay opciones disponibles en este catálogo.', textAlign: TextAlign.center),
                      )
                    : SingleChildScrollView(
                        child: ListBody(
                          children: opciones.map((opcion) {
                            final isChecked = tempSeleccionadas.contains(opcion);
                            return CheckboxListTile(
                              title: Text(
                                opcion,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              value: isChecked,
                              activeColor: primaryColor,
                              checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                              controlAffinity: ListTileControlAffinity.trailing,
                              onChanged: (bool? checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    tempSeleccionadas.add(opcion);
                                  } else {
                                    tempSeleccionadas.remove(opcion);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSeleccionadas);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Row(
            children: [
              // Sección Principal del Formulario
              Expanded(
                flex: 8,
                child: Container(
                  height: double.infinity,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 32.0),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Botón de Retorno sutil
                            Align(
                              alignment: Alignment.topLeft,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                                color: const Color(0xFF64748B),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Encabezado
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Puelo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Completa tu perfil',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Regístrate para ofrecer tus servicios y conectar con nuevos clientes.',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Separador Visual: Información Personal
                            _buildSectionHeader('Datos Personales'),

                            // Campo: Nombre
                            _buildTextField(
                              controller: _nombreController,
                              focusNode: _nombreFocusNode,
                              hintText: 'Nombre',
                              icon: Icons.person_outline_rounded,
                            ),

                            // Campo: Apellido
                            _buildTextField(
                              controller: _apellidoController,
                              focusNode: _apellidoFocusNode,
                              hintText: 'Apellido',
                              icon: Icons.person_outline_rounded,
                            ),

                            // Campo: Documento
                            _buildTextField(
                              controller: _documentoController,
                              focusNode: _documentoFocusNode,
                              hintText: 'DNI / Documento',
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 16),

                            // Separador Visual: Información Comercial
                            _buildSectionHeader('Información de Servicio'),

                            // Campo: Nombre Comercial
                            _buildTextField(
                              controller: _nombreComercialController,
                              focusNode: _nombreComercialFocusNode,
                              hintText: 'Nombre de Fantasía o Comercial',
                              icon: Icons.storefront_rounded,
                            ),

                            // Campo: Teléfono
                            _buildTextField(
                              controller: _telefonoController,
                              focusNode: _telefonoFocusNode,
                              hintText: 'Teléfono de contacto',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),

                            // Selector de Profesiones
                            _buildSelectorTile(
                              titulo: 'Profesión u Oficio',
                              valores: _profesionesSeleccionadas,
                              cargando: _cargandoCatalogos,
                              onTap: () {
                                if (_cargandoCatalogos) return;
                                _mostrarSeleccionMultiple(
                                  titulo: 'Seleccioná tus Especialidades',
                                  opciones: _opcionesProfesiones,
                                  seleccionadas: _profesionesSeleccionadas,
                                  onConfirm: (lista) {
                                    setState(() {
                                      _profesionesSeleccionadas = lista;
                                    });
                                  },
                                );
                              },
                            ),

                            // Selector de Zonas
                            _buildSelectorTile(
                              titulo: 'Zonas de Cobertura',
                              valores: _zonasSeleccionadas,
                              cargando: _cargandoCatalogos,
                              onTap: () {
                                if (_cargandoCatalogos) return;
                                _mostrarSeleccionMultiple(
                                  titulo: 'Seleccioná tus Zonas de Trabajo',
                                  opciones: _opcionesZonas,
                                  seleccionadas: _zonasSeleccionadas,
                                  onConfirm: (lista) {
                                    setState(() {
                                      _zonasSeleccionadas = lista;
                                    });
                                  },
                                );
                              },
                            ),

                            const SizedBox(height: 32),

                            // Botón de Envío Prominente
                            ElevatedButton(
                              onPressed: _crearTarjetaProfesional,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Crear Tarjeta Profesional',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Sección Lateral Decorativa (Visible solo en Desktop/Tablet)
              if (isDesktop)
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        image: const DecorationImage(
                          fit: BoxFit.cover,
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1514924013411-cbf25faa35bb?ixlib=rb-4.0.3&auto=format&fit=crop&w=1380&q=80',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Separadores de sección en el formulario
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5)),
        ],
      ),
    );
  }

  // Constructor para campos de entrada modernos
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          filled: true,
          fillColor: inputBgColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primaryColor, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // Constructor elegante para los selectores de tipo input (adaptado para carga asíncrona)
  Widget _buildSelectorTile({
    required String titulo,
    required List<String> valores,
    required bool cargando,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: cargando ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          decoration: BoxDecoration(
            color: inputBgColor,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cargando ? 'Cargando catálogo...' : titulo,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    ),
                    if (valores.isNotEmpty && !cargando) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: valores
                            .map((val) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    val, 
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: primaryColor,
                                      fontWeight: FontWeight.w600,
                                    )
                                  ),
                                ))
                            .toList(),
                      )
                    ]
                  ],
                ),
              ),
              cargando 
                ? SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)
                  )
                : const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF94A3B8), size: 28),
            ],
          ),
        ),
      ),
    );
  }

  // Callback de Guardado e Integración con Firestore
  void _crearTarjetaProfesional() async {
    if (_nombreController.text.trim().isEmpty || _apellidoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa Nombre y Apellido')),
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
        'zonas': _zonasSeleccionadas,
        'rol': 'trabajador',
        'creado_en': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil creado correctamente')),
        );
        
        Navigator.pushNamed(
          context, 
          '/tarjetaDigital', 
          arguments: {'usuarioRef': nuevoUsuarioRef}
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar en base de datos: $e')),
        );
      }
    }
  }
}
