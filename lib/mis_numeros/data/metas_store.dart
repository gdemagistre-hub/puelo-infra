import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/vault_session.dart';
import '../models/meta_ahorro.dart';

class MetasStore extends ChangeNotifier {
  static const _prefix = 'metas_ahorro_v2_';

  final List<MetaAhorro> _items = [];
  bool loaded = false;
  String? _uid;
  bool _cloudOk = false;
  String? lastCloudError;

  List<MetaAhorro> get items => List.unmodifiable(_items);
  bool get syncedToCloud => _cloudOk;

  /// Primer fondo de emergencia (si existe).
  MetaAhorro? get fondoEmergencia {
    for (final m in _items) {
      if (m.esFondoEmergencia) return m;
    }
    return null;
  }

  /// Metas aspiracionales (vacaciones, herramientas, etc.).
  List<MetaAhorro> get metasAspiracionales =>
      _items.where((m) => !m.esFondoEmergencia).toList();

  String get _key => '$_prefix${_uid ?? 'anon'}';

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('metas');
  }

  static const _sensitive = ['titulo', 'objetivo', 'ahorrado'];
  static const _numeric = {'objetivo', 'ahorrado'};

  Future<Map<String, dynamic>> _toCloud(MetaAhorro m) async {
    final clear = m.toJson();
    final vault = VaultSession.instance;
    if (!vault.isUnlocked) return clear;
    return vault.sealMap(clear, sensitiveKeys: _sensitive);
  }

  Future<MetaAhorro?> _fromCloud(
      Map<String, dynamic> data, String docId) async {
    try {
      var open = data;
      final vault = VaultSession.instance;
      if (data['enc'] == true && vault.isUnlocked) {
        open = await vault.openMap(
          data,
          sensitiveKeys: _sensitive,
          numericKeys: _numeric,
        );
      }
      open['id'] = open['id'] ?? docId;
      return MetaAhorro.fromJson(open);
    } catch (e) {
      debugPrint('Meta decrypt skip: $e');
      return null;
    }
  }

  Future<void> loadForUser(String? uid) async {
    _uid = uid;
    loaded = false;
    _cloudOk = false;
    lastCloudError = null;
    notifyListeners();
    _items.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          try {
            _items.add(
              MetaAhorro.fromJson(Map<String, dynamic>.from(e as Map)),
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('MetasStore.local: $e');
    }

    if (uid != null && uid.isNotEmpty) {
      try {
        final snap = await _col!.get(const GetOptions(source: Source.server));
        if (snap.docs.isNotEmpty) {
          _items.clear();
          for (final doc in snap.docs) {
            final data = Map<String, dynamic>.from(doc.data());
            final m = await _fromCloud(data, doc.id);
            if (m != null) _items.add(m);
          }
          await _persistLocal();
        } else if (_items.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final m in _items) {
            batch.set(_col!.doc(m.id), {
              ...await _toCloud(m),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
        _cloudOk = true;
        lastCloudError = null;
      } catch (e) {
        debugPrint('MetasStore.cloud: $e');
        _cloudOk = false;
        lastCloudError = e.toString();
      }
    }

    loaded = true;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _cloudSet(MetaAhorro m) async {
    final col = _col;
    if (col == null) throw StateError('Sin usuario');
    await col.doc(m.id).set({
      ...await _toCloud(m),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> add(MetaAhorro meta) async {
    // Un solo fondo de emergencia.
    if (meta.esFondoEmergencia && fondoEmergencia != null) {
      return false;
    }
    _items.insert(0, meta);
    notifyListeners();
    await _persistLocal();
    try {
      await _cloudSet(meta);
      _cloudOk = true;
      lastCloudError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _cloudOk = false;
      lastCloudError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(MetaAhorro meta) async {
    final i = _items.indexWhere((e) => e.id == meta.id);
    if (i < 0) return false;
    _items[i] = meta;
    notifyListeners();
    await _persistLocal();
    try {
      await _cloudSet(meta);
      _cloudOk = true;
      lastCloudError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _cloudOk = false;
      lastCloudError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persistLocal();
    try {
      await _col?.doc(id).delete();
      _cloudOk = true;
      notifyListeners();
      return true;
    } catch (e) {
      _cloudOk = false;
      lastCloudError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> sumarAhorro(String id, double monto) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0 || monto <= 0) return false;
    final updated = _items[i].copyWith(ahorrado: _items[i].ahorrado + monto);
    return update(updated);
  }

  /// Sacar plata del fondo/meta (uso del colchón o deshacer aparte).
  Future<bool> restarAhorro(String id, double monto) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0 || monto <= 0) return false;
    final actual = _items[i].ahorrado;
    if (monto > actual + 0.001) return false;
    final nuevo = (actual - monto).clamp(0, double.infinity);
    final updated = _items[i].copyWith(ahorrado: nuevo.toDouble());
    return update(updated);
  }

  /// Crea el Fondo días flojos si aún no existe.
  Future<MetaAhorro?> asegurarFondoEmergencia({double objetivo = 50000}) async {
    final existing = fondoEmergencia;
    if (existing != null) return existing;
    final meta = MetaAhorro(
      id: 'fondo_emergencia_${DateTime.now().millisecondsSinceEpoch}',
      titulo: 'Fondo días flojos',
      objetivo: objetivo,
      ahorrado: 0,
      creada: DateTime.now(),
      esFondoEmergencia: true,
    );
    final ok = await add(meta);
    return ok ? meta : null;
  }
}
