import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> migrarBaseDeDatos() async {
  print('🚀 Iniciando migración a Firestore desde la app...');
  final db = FirebaseFirestore.instance;

  try {
    // --- A) PROVINCIAS ---
    String provString = await rootBundle.loadString('assets/provincia.json');
    final provData = jsonDecode(provString);
    List<dynamic> provincias = provData['provincias'];

    List<Map<String, dynamic>> listaProvincias = provincias.map((p) => {
      'id': p['id'],
      'nombre': p['nombre'],
    }).toList();

    await db.collection('cat_paises').doc('AR').set({
      'nombre': 'Argentina',
      'provincias': listaProvincias
    }, SetOptions(merge: true));
    print('✅ Provincias listas.');

    // --- B) DEPARTAMENTOS ---
    String depString = await rootBundle.loadString('assets/departamentos.json');
    final depData = jsonDecode(depString);
    List<dynamic> departamentos = depData['departamentos'];

    WriteBatch batchDep = db.batch();
    int countDep = 0;

    for (var dep in departamentos) {
      final docRef = db.collection('cat_departamentos')
          .doc('AR_${dep['provincia']['id']}_${dep['id']}');
      
      batchDep.set(docRef, {
        'pais_id': 'AR',
        'provincia_id': dep['provincia']['id'],
        'provincia_nombre': dep['provincia']['nombre'],
        'departamento_id': dep['id'],
        'departamento_nombre': dep['nombre'],
      });

      countDep++;
      if (countDep % 400 == 0) {
        await batchDep.commit();
        batchDep = db.batch();
      }
    }
    if (countDep % 400 != 0) await batchDep.commit();
    print('✅ Departamentos listos.');

    // --- C) LOCALIDADES ---
    String locString = await rootBundle.loadString('assets/localidades.json');
    final locData = jsonDecode(locString);
    List<dynamic> localidades = locData['localidades'];

    WriteBatch batchLoc = db.batch();
    int countLoc = 0;

    for (var loc in localidades) {
      final docRef = db.collection('cat_localidades')
          .doc('AR_${loc['provincia']['id']}_${loc['id']}');
      
      batchLoc.set(docRef, {
        'pais_id': 'AR',
        'provincia_id': loc['provincia']['id'],
        'provincia_nombre': loc['provincia']['nombre'],
        'partido_id': loc['departamento']['id'],
        'partido_nombre': loc['departamento']['nombre'],
        'localidad_id': loc['id'],
        'localidad_nombre': loc['nombre'],
      });

      countLoc++;
      if (countLoc % 400 == 0) {
        await batchLoc.commit();
        print('📦 Lote subido: $countLoc localidades...');
        batchLoc = db.batch();
      }
    }
    if (countLoc % 400 != 0) await batchLoc.commit();
    
    print('🎉 ¡Migración completa y exitosa!');
  } catch (e) {
    print('❌ Error durante la migración: $e');
  }
}
