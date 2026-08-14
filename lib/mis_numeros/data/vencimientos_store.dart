import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/vault_session.dart';
import '../models/vencimiento.dart';

class VencimientosStore extends ChangeNotifier {
  static const _prefix = 'vencimientos_v2_';

  final List<Vencimiento> _items = [];
  bool loaded = false;
  String? _uid;
  bool _cloudOk = false;
  String? lastCloudError;

  List<Vencimiento> get items {
    final list = List<Vencimiento>.from(_items);
    list.sort((a, b) => a.fecha.compareTo(b.fecha));
    return list;
  }

  bool get syncedToCloud => _cloudOk;

  String get _key => '$_prefix${_uid ?? 'anon'}';

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('vencimientos');
  }

  static const _sensitive = ['titulo', 'monto'];
  static const _numeric = {'monto'};

  Future<Map<String, dynamic>> _toCloud(Vencimiento v) async {
    final clear = v.toJson();
    final vault = VaultSession.instance;
    if (!vault.isUnlocked) return clear;
    return vault.sealMap(clear, sensitiveKeys: _sensitive);
  }

  Future<Vencimiento?> _fromCloud(
    Map<String, dynamic> data,
    String docId,
  ) async {
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
      return Vencimiento.fromJson(open);
    } catch (e) {
      debugPrint('Vencimiento decrypt skip: $e');
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
              Vencimiento.fromJson(Map<String, dynamic>.from(e as Map)),
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('VencimientosStore.local: $e');
    }

    if (uid != null && uid.isNotEmpty) {
      try {
        final snap = await _col!.get(const GetOptions(source: Source.server));
        if (snap.docs.isNotEmpty) {
          _items.clear();
          for (final doc in snap.docs) {
            final data = Map<String, dynamic>.from(doc.data());
            final v = await _fromCloud(data, doc.id);
            if (v != null) _items.add(v);
          }
          await _persistLocal();
        } else if (_items.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final v in _items) {
            batch.set(_col!.doc(v.id), {
              ...await _toCloud(v),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
        _cloudOk = true;
      } catch (e) {
        debugPrint('VencimientosStore.cloud: $e');
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

  Future<bool> add(Vencimiento v) async {
    _items.add(v);
    await _persistLocal();
    notifyListeners();
    try {
      await _col?.doc(v.id).set({
        ...await _toCloud(v),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  Future<bool> togglePagado(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return false;
    _items[i] = _items[i].copyWith(pagado: !_items[i].pagado);
    await _persistLocal();
    notifyListeners();
    try {
      await _col?.doc(id).set({
        ...await _toCloud(_items[i]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  Future<bool> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persistLocal();
    notifyListeners();
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
}
