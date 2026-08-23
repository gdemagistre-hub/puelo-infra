#!/usr/bin/env python3
from pathlib import Path

p = Path("lib/buscadorPrestadores.dart")
t = p.read_text()
if "_avatarFila" in t and "_emptyState" in t:
    print("already applied")
    raise SystemExit(0)

old_init = "  String _initials(Map<String, dynamic> data) {"
new_init = """  String? _fotoUrl(Map<String, dynamic> data) {
    final raw = (data['url_foto_perfil'] ?? data['foto_perfil'] ?? '')
        .toString()
        .trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }

  String _initials(Map<String, dynamic> data) {"""
if old_init not in t:
    raise SystemExit("initials missing")
t = t.replace(old_init, new_init, 1)

marker = "Icons.search_off_rounded"
if marker not in t:
    raise SystemExit("empty marker missing")
old_empty_start = """                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      const SizedBox(height: 80),
                                      Icon(
                                        Icons.search_off_rounded,"""
if old_empty_start not in t:
    raise SystemExit("empty start missing")
i = t.find(old_empty_start)
j = t.find("                                : ListView.builder(", i)
if j < 0:
    raise SystemExit("list builder missing")
t = (
    t[:i]
    + """                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      const SizedBox(height: 56),
                                      _emptyState(),
                                    ],
                                  )
"""
    + t[j:]
)

old_av = """                                                  CircleAvatar(
                                                    radius: 26,
                                                    backgroundColor:
                                                        _clientePrimary
                                                            .withOpacity(0.14),
                                                    child: Text(
                                                      _initials(data),
                                                      style: const TextStyle(
                                                        color: _clientePrimary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),"""
new_av = """                                                  _avatarFila(
                                                    foto: _fotoUrl(data),
                                                    initials: _initials(data),
                                                  ),"""
if old_av not in t:
    raise SystemExit("avatar missing")
t = t.replace(old_av, new_av, 1)

old_zona = """                                                        if (zona.isNotEmpty)
                                                          Text(
                                                            zona,
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade500,
                                                              fontSize: 11,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),"""
new_zona = """                                                        if (zona.isNotEmpty ||
                                                            cerca)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                              top: 2,
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                if (cerca) ...[
                                                                  Container(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                      horizontal: 6,
                                                                      vertical: 1,
                                                                    ),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: _clientePrimary
                                                                          .withOpacity(0.10),
                                                                      borderRadius:
                                                                          BorderRadius.circular(8),
                                                                    ),
                                                                    child: const Text(
                                                                      'Cerca',
                                                                      style: TextStyle(
                                                                        fontSize: 10,
                                                                        fontWeight:
                                                                            FontWeight.w800,
                                                                        color: _clientePrimary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                ],
                                                                if (zona.isNotEmpty)
                                                                  Expanded(
                                                                    child: Text(
                                                                      zona,
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .grey.shade500,
                                                                        fontSize: 11,
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow:
                                                                          TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),"""
if old_zona not in t:
    raise SystemExit("zona missing")
t = t.replace(old_zona, new_zona, 1)

t = t.replace(
    "/// UX 5.2: búsqueda, chips de oficio, ranking zona→confianza Phase0, badge, WhatsApp.",
    "/// UX 5.2 + 5.7: foto en fila, chip Cerca, empty state con salida.",
    1,
)

helpers = """
  void _limpiarFiltros() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedRubro = 'Todos';
    });
    _cargarPrestadores(reset: true);
  }

  Widget _avatarFila({required String? foto, required String initials}) {
    final fallback = Text(
      initials,
      style: const TextStyle(
        color: _clientePrimary,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
    return CircleAvatar(
      radius: 26,
      backgroundColor: _clientePrimary.withOpacity(0.14),
      child: foto == null
          ? fallback
          : ClipOval(
              child: Image.network(
                foto,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: fallback),
              ),
            ),
    );
  }

  Widget _emptyState() {
    final hayFiltro = _selectedRubro != 'Todos' || _searchQuery.isNotEmpty;
    final titulo = hayFiltro
        ? 'Nadie con ese filtro ahora'
        : 'Todavía no hay prestadores acá';
    final sub = hayFiltro
        ? 'Probá otro oficio o sacá el filtro para ver a todos.'
        : AppCopy.sinPrestadoresZona;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _clientePrimary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 34,
              color: _clientePrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          if (hayFiltro)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _limpiarFiltros,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _clientePrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ver todos',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () => _cargarPrestadores(reset: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _clientePrimary,
                  side: const BorderSide(color: _clientePrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Actualizar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
"""
idx = t.rstrip().rfind("}")
t = t[:idx] + helpers + "}\n"
if t.count("{") != t.count("}"):
    raise SystemExit(f"brace mismatch {t.count('{')} {t.count('}')}")
p.write_text(t)
print("patched", t.count("{"), t.count("}"))
