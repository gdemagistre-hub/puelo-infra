// No olvides importar el singleton arriba
import 'user_session.dart';

Future<void> _uploadAndSave() async {
    // Ya no chequeamos _selectedCliente
    if (_selectedTrabajador == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, seleccioná un trabajador.')),
      );
      return;
    }
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenés que seleccionar al menos una foto.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      List<String> imageUrls = [];
      // ... (El código de subida a Storage se mantiene exactamente igual) ...

      // Creamos la referencia del cliente usando el Singleton
      final clienteActualRef = FirebaseFirestore.instance.collection('usuarios').doc(UserSession().uid);

      // Creamos el documento del trabajo
      final nuevoTrabajoRef = await FirebaseFirestore.instance.collection('trabajos').add({
        'trabajadorRef': _selectedTrabajador,
        'clienteRef': clienteActualRef, // Usamos la ref del usuario logueado
        'imagenes': imageUrls,
        'fechaCarga': FieldValue.serverTimestamp(),
        'cargadoPor': 'Cliente',
        'calificado': false,
        'comentarioCliente': '',
        'estrellas': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Trabajo cargado con éxito! Ahora podés calificar.')),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CalificarTrabajoWidget(
              trabajoId: nuevoTrabajoRef.id,
              trabajadorId: _selectedTrabajador!.id,
              clienteId: UserSession().uid!, // Pasamos el UID desde la sesión
            ),
          ),
        );
      }
    } catch (e) {
      // ... (Manejo de errores igual)
