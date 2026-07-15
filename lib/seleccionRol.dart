import 'package:flutter/material.dart';
import 'cargaTrabajoTrabajador.dart';
import 'cargaTrabajoCliente.dart';

class SeleccionRolWidget extends StatelessWidget {
  const SeleccionRolWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargar Trabajos'),
        backgroundColor: const Color(0xFF0F52BA),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Cómo querés ingresar hoy?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F52BA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.engineering),
                label: const Text('Ingresar como Trabajador', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CargaTrabajoTrabajadorWidget()),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F52BA),
                  side: const BorderSide(color: Color(0xFF0F52BA), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.person),
                label: const Text('Ingresar como Cliente', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CargaTrabajoClienteWidget()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
