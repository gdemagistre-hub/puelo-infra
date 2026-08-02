import 'package:flutter/material.dart';

/// Selector con campo de búsqueda + lista scrolleable.
/// Sirve para provincia / partido / localidad (listas largas).
class SearchablePicker {
  SearchablePicker._();

  /// Una opción. Devuelve el ítem elegido o null si cancela.
  static Future<Map<String, String>?> pickSingle({
    required BuildContext context,
    required String titulo,
    required List<Map<String, String>> opciones,
    String? selectedId,
    Color accent = const Color(0xFF734BE4),
    String hintBuscar = 'Escribí para filtrar…',
  }) async {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _SearchableSheet(
          titulo: titulo,
          opciones: opciones,
          selectedIds: selectedId != null ? {selectedId} : {},
          multi: false,
          accent: accent,
          hintBuscar: hintBuscar,
        );
      },
    );
  }

  /// Varias opciones. Devuelve la lista confirmada o null si cancela.
  static Future<List<Map<String, String>>?> pickMulti({
    required BuildContext context,
    required String titulo,
    required List<Map<String, String>> opciones,
    required List<Map<String, String>> seleccionadas,
    Color accent = const Color(0xFF28B5CD),
    String hintBuscar = 'Escribí para filtrar…',
  }) async {
    return showModalBottomSheet<List<Map<String, String>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _SearchableSheet(
          titulo: titulo,
          opciones: opciones,
          selectedIds: seleccionadas.map((e) => e['id'] ?? '').toSet(),
          initialSelected: List<Map<String, String>>.from(seleccionadas),
          multi: true,
          accent: accent,
          hintBuscar: hintBuscar,
        );
      },
    );
  }
}

class _SearchableSheet extends StatefulWidget {
  final String titulo;
  final List<Map<String, String>> opciones;
  final Set<String> selectedIds;
  final List<Map<String, String>>? initialSelected;
  final bool multi;
  final Color accent;
  final String hintBuscar;

  const _SearchableSheet({
    required this.titulo,
    required this.opciones,
    required this.selectedIds,
    required this.multi,
    required this.accent,
    required this.hintBuscar,
    this.initialSelected,
  });

  @override
  State<_SearchableSheet> createState() => _SearchableSheetState();
}

class _SearchableSheetState extends State<_SearchableSheet> {
  final _filterCtrl = TextEditingController();
  String _query = '';
  late List<Map<String, String>> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = widget.initialSelected != null
        ? List<Map<String, String>>.from(widget.initialSelected!)
        : [];
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filtradas {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.opciones;
    return widget.opciones.where((o) {
      final n = (o['nombre'] ?? '').toLowerCase();
      return n.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final height = media.size.height * (widget.multi ? 0.88 : 0.75);
    final filtradas = _filtradas;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        child: SizedBox(
          height: height - (keyboard > 0 ? keyboard * 0.15 : 0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.titulo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (widget.multi)
                      IconButton(
                        tooltip: 'Aceptar selección',
                        icon: Icon(Icons.check_circle_rounded,
                            color: widget.accent, size: 28),
                        onPressed: () => Navigator.pop(
                          context,
                          List<Map<String, String>>.from(_tempSelected),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if (widget.multi && _tempSelected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_tempSelected.length} seleccionado${_tempSelected.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.accent,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _filterCtrl,
                  // multi: no autofocus para no tapar el botón Aceptar con el teclado
                  autofocus: !widget.multi,
                  decoration: InputDecoration(
                    hintText: widget.hintBuscar,
                    prefixIcon:
                        Icon(Icons.search, color: Colors.grey.shade500),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _filterCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    filtradas.isEmpty
                        ? 'Sin resultados'
                        : '${filtradas.length} resultado${filtradas.length == 1 ? '' : 's'}'
                            '${widget.opciones.length != filtradas.length ? ' de ${widget.opciones.length}' : ''}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: filtradas.isEmpty
                    ? Center(
                        child: Text(
                          'No hay coincidencias.\nProbá con otra palabra.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: filtradas.length,
                        itemBuilder: (context, index) {
                          final item = filtradas[index];
                          final id = item['id'] ?? '';
                          final nombre = item['nombre'] ?? '';

                          if (widget.multi) {
                            final checked =
                                _tempSelected.any((e) => e['id'] == id);
                            return CheckboxListTile(
                              value: checked,
                              activeColor: widget.accent,
                              title: Text(
                                nombre,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 15,
                                ),
                              ),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    if (!_tempSelected
                                        .any((e) => e['id'] == id)) {
                                      _tempSelected.add(item);
                                    }
                                  } else {
                                    _tempSelected
                                        .removeWhere((e) => e['id'] == id);
                                  }
                                });
                              },
                            );
                          }

                          final isSelected = widget.selectedIds.contains(id);
                          return ListTile(
                            title: Text(
                              nombre,
                              style: TextStyle(
                                color: const Color(0xFF1E293B),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: widget.accent)
                                : null,
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
              if (widget.multi)
                Material(
                  elevation: 8,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(
                              context,
                              List<Map<String, String>>.from(_tempSelected),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: Text(
                              _tempSelected.isEmpty
                                  ? 'Aceptar'
                                  : 'Aceptar (${_tempSelected.length})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
