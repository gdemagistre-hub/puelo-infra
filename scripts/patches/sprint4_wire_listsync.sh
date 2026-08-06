#!/usr/bin/env bash
set -euo pipefail
# Sprint 4: wire UsuarioListSync + camera guards (idempotent)
# Trigger sprint5: 2026-08-06T18:15Z

# --- Domicilio ---
if ! grep -q "usuario_list_sync" lib/Domicilioflotante.dart; then
  sed -i "s|import 'user_session.dart';|import 'user_session.dart';\nimport 'usuario_list_sync.dart';|" lib/Domicilioflotante.dart
fi
python3 - <<'PY'
from pathlib import Path
p = Path('lib/Domicilioflotante.dart')
t = p.read_text()
old = """      await db.collection('usuarios').doc(uid).set({
        'calle': _calleController.text.trim(),
        'numero': _numeroController.text.trim(),
        'piso_depto': _pisoController.text.trim(),
        'cp': _cpController.text.trim(),
        'direccion_geo': {
          'provincia_id': selectedProvinciaId,
          'provincia_nombre': selectedProvinciaNombre,
          'partido_id': selectedPartidoId,
          'partido_nombre': selectedPartidoNombre,
          'localidad_id': selectedLocalidadId,
          'localidad_nombre': selectedLocalidadNombre,
        },
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));"""
new = """      await UsuarioListSync.mergeUserDoc(uid, {
        'calle': _calleController.text.trim(),
        'numero': _numeroController.text.trim(),
        'piso_depto': _pisoController.text.trim(),
        'cp': _cpController.text.trim(),
        'direccion_geo': {
          'provincia_id': selectedProvinciaId,
          'provincia_nombre': selectedProvinciaNombre,
          'partido_id': selectedPartidoId,
          'partido_nombre': selectedPartidoNombre,
          'localidad_id': selectedLocalidadId,
          'localidad_nombre': selectedLocalidadNombre,
        },
        'updated_at': FieldValue.serverTimestamp(),
      });"""
if old in t:
    p.write_text(t.replace(old, new, 1))
    print('domicilio: wired')
elif 'UsuarioListSync.mergeUserDoc' in t:
    print('domicilio: already wired')
else:
    print('domicilio: pattern not found')
    raise SystemExit(1)
PY

# --- completar_perfil ---
python3 - <<'PY'
from pathlib import Path
p = Path('lib/completar_perfil.dart')
t = p.read_text()
if 'platform_capabilities' not in t:
    t = t.replace(
        "import 'package:image_picker/image_picker.dart';\n",
        "import 'package:image_picker/image_picker.dart';\nimport 'platform_capabilities.dart';\nimport 'usuario_list_sync.dart';\n",
    )
elif 'usuario_list_sync' not in t:
    t = t.replace("import 'platform_capabilities.dart';\n", "import 'platform_capabilities.dart';\nimport 'usuario_list_sync.dart';\n")
old = """  Future<void> _tomarFoto(bool esPerfil, ImageSource source) async {
    final XFile? image =
        await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        if (esPerfil) {
          _fotoPerfilBytes = bytes;
        } else {
          _fotoDocBytes = bytes;
        }
      });
    }
  }"""
new = """  Future<void> _tomarFoto(bool esPerfil, ImageSource source) async {
    if (source == ImageSource.camera && !PlatformCapabilities.supportsCamera) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PlatformCapabilities.cameraUnsupportedMessage)),
      );
      return;
    }
    try {
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (esPerfil) {
          _fotoPerfilBytes = bytes;
        } else {
          _fotoDocBytes = bytes;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la imagen: $e')),
      );
    }
  }"""
if old in t:
    t = t.replace(old, new, 1)
    print('completar: camera guard')
elif 'PlatformCapabilities.supportsCamera' in t:
    print('completar: camera already')
else:
    print('completar: camera pattern missing')
old2 = """      await db
          .collection('usuarios')
          .doc(_selectedUsuarioId)
          .set(actualizacion, SetOptions(merge: true));"""
new2 = """      await UsuarioListSync.mergeUserDoc(_selectedUsuarioId!, actualizacion);"""
if old2 in t:
    t = t.replace(old2, new2, 1)
    print('completar: list sync')
elif 'UsuarioListSync.mergeUserDoc' in t:
    print('completar: list sync already')
else:
    print('completar: save pattern missing')
    raise SystemExit(1)
p.write_text(t)
PY

# --- datos personales ---
python3 - <<'PY'
from pathlib import Path
p = Path('lib/datosPersonalesflotante.dart')
t = p.read_text()
if 'usuario_list_sync' not in t:
    t = t.replace("import 'user_session.dart';\n", "import 'user_session.dart';\nimport 'usuario_list_sync.dart';\n")
old = """      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set(payload, SetOptions(merge: true));
      final session = UserSession();
      session.nombre = _nombreController.text.trim();
      session.apellido = _apellidoController.text.trim();
      if (session.datosCompletos != null) {
        session.datosCompletos = {...session.datosCompletos!, ...payload};
      }"""
new = """      await UsuarioListSync.mergeUserDoc(uid, payload);
      final session = UserSession();
      session.nombre = _nombreController.text.trim();
      session.apellido = _apellidoController.text.trim();"""
if old in t:
    t = t.replace(old, new, 1)
    print('datos: wired')
elif 'UsuarioListSync.mergeUserDoc' in t:
    print('datos: already')
else:
    print('datos: pattern missing')
    raise SystemExit(1)
p.write_text(t)
PY

# --- capacitaciones (idempotent: pickImageSource OR PlatformCapabilities guard) ---
python3 - <<'PY'
from pathlib import Path
p = Path('lib/capacitacionesflotante.dart')
t = p.read_text()
if 'pickImageSource' in t:
    print('cap: already pickImageSource')
elif 'PlatformCapabilities.supportsCamera' in t:
    print('cap: already PlatformCapabilities guard')
else:
    if 'platform_capabilities' not in t:
        t = t.replace(
            "import 'package:flutter/foundation.dart' show kIsWeb;\n",
            "import 'package:flutter/foundation.dart' show kIsWeb;\nimport 'platform_capabilities.dart';\n",
        )
    old = """                              ListTile(
                                leading: const Icon(Icons.photo_camera_outlined),
                                title: const Text('Tomar foto'),
                                onTap: () =>
                                    Navigator.pop(c2, ImageSource.camera),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library_outlined),
                                title: const Text('Elegir de galería'),
                                onTap: () =>
                                    Navigator.pop(c2, ImageSource.gallery),
                              ),"""
    new = """                              if (PlatformCapabilities.supportsCamera)
                                ListTile(
                                  leading: const Icon(Icons.photo_camera_outlined),
                                  title: const Text('Tomar foto'),
                                  onTap: () =>
                                      Navigator.pop(c2, ImageSource.camera),
                                ),
                              ListTile(
                                leading: const Icon(Icons.photo_library_outlined),
                                title: const Text('Elegir de galería'),
                                onTap: () =>
                                    Navigator.pop(c2, ImageSource.gallery),
                              ),"""
    if old in t:
        t = t.replace(old, new, 1)
        print('cap: wired')
        p.write_text(t)
    else:
        print('cap: pattern missing')
        raise SystemExit(1)
PY

echo "Sprint 4 patch applied OK"
