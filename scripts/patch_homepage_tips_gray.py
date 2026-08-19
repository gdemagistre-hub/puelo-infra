from pathlib import Path
t = Path("lib/Homepage.dart").read_text()
if "final visitado = _tipsVisitadosSesion.contains(r.id)" in t:
    print("already gray")
    raise SystemExit(0)
old = """                  ...recos.map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 1,
                        child: InkWell(
                          onTap: () => _ejecutarTip(r),
"""
new = """                  ...recos.map((r) {
                    final visitado = _tipsVisitadosSesion.contains(r.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Opacity(
                        opacity: visitado ? 0.55 : 1,
                        child: Material(
                        color: visitado ? const Color(0xFFF1F5F9) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: visitado ? 0 : 1,
                        child: InkWell(
                          onTap: () => _ejecutarTip(r),
"""
if old not in t:
    print("block not found")
    raise SystemExit(1)
t = t.replace(old, new, 1)
# close Opacity: after the Material's closing for this tip card
# Find the pattern after chevron that closes Material/InkWell/Padding
old_close = """                                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),"""
new_close = """                                Icon(
                                  visitado ? Icons.check_circle_outline_rounded : Icons.chevron_right_rounded,
                                  color: visitado ? const Color(0xFF94A3B8) : Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ),
                    );
                  }),"""
if old_close not in t:
    print("close not found")
    # still write partial
    Path("lib/Homepage.dart").write_text(t)
    raise SystemExit(2)
t = t.replace(old_close, new_close, 1)
Path("lib/Homepage.dart").write_text(t)
print("gray ok", t.count("{") == t.count("}"))
