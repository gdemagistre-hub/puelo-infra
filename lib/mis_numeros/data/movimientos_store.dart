import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/vault_session.dart';
import '../finanzas_bridge.dart';
import '../models/movimiento.dart';

enum PeriodoVista { hoy, semana, mes }

/// Cloud (Firestore Finanzas) = fuente de verdad. Local = cache + cola.
class MovimientosStore extends ChangeNotifier {
  static const _prefix = 'mis_numeros_movimientos_v2_';
  static const _pendingPrefix = 'mis_numeros_pending_v1_';

  final List<Movimiento> _items = [];
  bool _loaded = false;
  String? _uid;
  bool _cloudOk = false;
  String? lastCloudError;
  bool _syncing = false;

  List<Movimiento> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;
  String? get uid => _uid;
  bool get syncedToCloud => _cloudOk;
  bool get syncing => _syncing;
  int get totalCount => _items.length;

  String get _key => '$_prefix${_uid ?? 'anon'}';
  String get _pendingKey => '$_pendingPrefix${_uid ?? 'anon'}';

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return FinanzasBridge.finanzasDb
        .collection('usuarios')
        .doc(uid)
        .collection('movimientos');
  }

  Future<void> loadForUser(String? uid) async {
    _uid = uid;
    _loaded = false;
    _cloudOk = false;
    lastCloudError = null;
    _syncing = true;
    notifyListeners();
    _items.clear();

    await _loadLocalCache();

    if (uid == null || uid.isEmpty) {
      _loaded = true;
      _syncing = false;
      notifyListeners();
      return;
    }

    await _ensureUserDoc(uid);

    try {
      final snap = await _col!.get(const GetOptions(source: Source.server));
      final cloud = <Movimiento>[];
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final m = await _fromCloud(data, doc.id);
        if (m != null) cloud.add(m);
      }

      if (cloud.isNotEmpty) {
        _items
          ..clear()
          ..addAll(cloud);
        _items.sort((a, b) => b.fecha.compareTo(a.fecha));
        await _persistLocal();
        _cloudOk = true;
        lastCloudError = null;
      } else if (_items.isNotEmpty) {
        await _uploadAllToCloud();
        _cloudOk = true;
        lastCloudError = null;
      } else {
        _cloudOk = true;
        lastCloudError = null;
      }

      await _flushPending();
    } catch (e, st) {
      debugPrint('MovimientosStore.cloud load: $e\n$st');
      _cloudOk = false;
      lastCloudError = _friendlyError(e);
    }

    _loaded = true;
    _syncing = false;
    notifyListeners();
  }

  static const _sensitive = ['monto', 'nota'];
  static const _numeric = {'monto'};

  Future<Map<String, dynamic>> _toCloud(Movimiento m) async {
    final clear = m.toJson();
    final vault = VaultSession.instance;
    if (!vault.isUnlocked) return clear;
    return vault.sealMap(clear, sensitiveKeys: _sensitive);
  }

  Future<Movimiento?> _fromCloud(
      Map<String, dynamic> data, String docId) async {
    try {
      final vault = VaultSession.instance;
      Map<String, dynamic> open = data;
      if (data['enc'] == true && vault.isUnlocked) {
        open = await vault.openMap(data,
            sensitiveKeys: _sensitive, numericKeys: _numeric);
      }
      open['id'] = open['id'] ?? docId;
      if (open['monto'] is String) {
        open['monto'] = double.tryParse(open['monto'] as String) ?? 0;
      }
      return Movimiento.fromJson(open);
    } catch (e) {
      debugPrint('Movimiento decrypt skip: $e');
      return null;
    }
  }

  Future<void> reloadFromCloud() => loadForUser(_uid);

  Future<void> _ensureUserDoc(String uid) async {
    try {
      final ref = FinanzasBridge.finanzasDb.collection('usuarios').doc(uid);
      await ref.set({
        'uid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'app': 'puelo-prox'
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ensureUserDoc: $e');
    }
  }

  Future<void> ensureUserProfile(
      {String? email, String? displayName}) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FinanzasBridge.finanzasDb.collection('usuarios').doc(uid).set({
        'uid': uid,
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
        'app': 'puelo-prox',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ensureUserProfile: $e');
    }
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          try {
            _items.add(
                Movimiento.fromJson(Map<String, dynamic>.from(e as Map)));
          } catch (_) {}
        }
      }
      _items.sort((a, b) => b.fecha.compareTo(a.fecha));
    } catch (e) {
      debugPrint('MovimientosStore.local: $e');
    }
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('persistLocal: $e');
    }
  }

  Future<void> _uploadAllToCloud() async {
    final col = _col;
    if (col == null || _items.isEmpty) return;
    for (var i = 0; i < _items.length; i += 400) {
      final chunk = _items.skip(i).take(400);
      final batch = FinanzasBridge.finanzasDb.batch();
      for (final m in chunk) {
        final sealed = await _toCloud(m);
        batch.set(
            col.doc(m.id), {...sealed, 'updatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    }
  }

  Future<void> _cloudSetStrict(Movimiento m) async {
    final col = _col;
    if (col == null) throw StateError('Sin usuario autenticado');
    final sealed = await _toCloud(m);
    await col
        .doc(m.id)
        .set({...sealed, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _enqueuePending(Movimiento m) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      final list = raw == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      list.removeWhere((e) => e['id'] == m.id);
      list.add(m.toJson());
      await prefs.setString(_pendingKey, jsonEncode(list));
    } catch (e) {
      debugPrint('enqueuePending: $e');
    }
  }

  Future<void> _flushPending() async {
    final col = _col;
    if (col == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => Movimiento.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final remaining = <Movimiento>[];
      for (final m in list) {
        try {
          await _cloudSetStrict(m);
          if (!_items.any((x) => x.id == m.id)) _items.add(m);
        } catch (_) {
          remaining.add(m);
        }
      }
      if (remaining.isEmpty) {
        await prefs.remove(_pendingKey);
      } else {
        await prefs.setString(
            _pendingKey, jsonEncode(remaining.map((e) => e.toJson()).toList()));
      }
      _items.sort((a, b) => b.fecha.compareTo(a.fecha));
      await _persistLocal();
    } catch (e) {
      debugPrint('flushPending: $e');
    }
  }

  Future<bool> add(Movimiento m) async {
    _items.insert(0, m);
    notifyListeners();
    await _persistLocal();
    try {
      await _cloudSetStrict(m);
      _cloudOk = true;
      lastCloudError = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('MovimientosStore.add cloud fail: $e');
      await _enqueuePending(m);
      _cloudOk = false;
      lastCloudError = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persistLocal();
    final col = _col;
    if (col == null) return false;
    try {
      await col.doc(id).delete();
      _cloudOk = true;
      lastCloudError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _cloudOk = false;
      lastCloudError = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied')) {
      return 'Firestore rechazo el guardado (reglas).';
    }
    if (s.contains('unavailable') || s.contains('network')) {
      return 'Sin conexion. Guardado local.';
    }
    if (s.contains('not-found') || s.contains('NOT_FOUND')) {
      return 'Firestore no esta creado.';
    }
    return 'Error nube: $s';
  }

  List<Movimiento> delDia([DateTime? dia]) {
    final d = dia ?? DateTime.now();
    return _items
        .where((m) =>
            m.fecha.year == d.year &&
            m.fecha.month == d.month &&
            m.fecha.day == d.day)
        .toList();
  }

  List<Movimiento> deLaSemana([DateTime? ref]) {
    final now = ref ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _items.where((m) => !m.fecha.isBefore(start)).toList();
  }

  List<Movimiento> delMes([DateTime? ref]) {
    final d = ref ?? DateTime.now();
    return _items
        .where((m) => m.fecha.year == d.year && m.fecha.month == d.month)
        .toList();
  }

  List<Movimiento> porPeriodo(PeriodoVista periodo) {
    switch (periodo) {
      case PeriodoVista.hoy:
        return delDia();
      case PeriodoVista.semana:
        return deLaSemana();
      case PeriodoVista.mes:
        return delMes();
    }
  }

  /// Solo cobros del oficio.
  double totalCobros(List<Movimiento> list) =>
      list.where((m) => m.esCobro).fold<double>(0, (s, m) => s + m.monto);

  /// Solo gastos del trabajo (materiales, transporte, etc.). No incluye retiros.
  double totalGastos(List<Movimiento> list) =>
      list.where((m) => m.esGasto).fold<double>(0, (s, m) => s + m.monto);

  /// Plata que te pasaste a casa / bolsillo personal.
  double totalRetiros(List<Movimiento> list) =>
      list.where((m) => m.esRetiro).fold<double>(0, (s, m) => s + m.monto);

  /// Plata que quedó en el negocio = Cobros − Gastos trabajo − Retiros a casa.
  double saldoNegocio(List<Movimiento> list) =>
      totalCobros(list) - totalGastos(list) - totalRetiros(list);

  /// Compat: mismo cálculo que saldoNegocio (incluye retiros como salida).
  double saldo(List<Movimiento> list) => saldoNegocio(list);

  double get saldoTotal => saldo(_items);
}
