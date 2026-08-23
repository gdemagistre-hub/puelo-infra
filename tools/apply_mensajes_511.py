#!/usr/bin/env python3
from pathlib import Path

def patch_list():
    p = Path("lib/mensajes/mensajes_list.dart")
    t = p.read_text()
    if "Confirmá el pago" in t:
        print("list already 5.11")
        return
    old = """    final summary = (widget.data['last_summary'] as String?) ?? 'Conversación';
    final pending = widget.data['pending_recibo_event_id'] != null ||
        widget.data['pending_calificacion_event_id'] != null;
    final name = _otherName ?? '…';
    final initial = name.isNotEmpty && name != '…' ? name[0].toUpperCase() : '?';
"""
    new = """    final summary = (widget.data['last_summary'] as String?) ?? 'Conversación';
    final pendingRecibo = widget.data['pending_recibo_event_id'] != null;
    final pendingCalif = widget.data['pending_calificacion_event_id'] != null;
    final reciboActor =
        (widget.data['pending_recibo_actor_uid'] ?? '').toString();
    final califActor =
        (widget.data['pending_calificacion_actor_uid'] ?? '').toString();
    final deboPago = pendingRecibo &&
        reciboActor.isNotEmpty &&
        reciboActor != widget.myUid;
    final deboEval = pendingCalif &&
        califActor.isNotEmpty &&
        califActor != widget.myUid;
    final pending = pendingRecibo || pendingCalif;
    final name = _otherName ?? '…';
    final initial = name.isNotEmpty && name != '…' ? name[0].toUpperCase() : '?';
    final badge = deboPago
        ? 'Confirmá el pago'
        : (deboEval
            ? 'Confirmá eval.'
            : (pending ? 'Esperando' : null));
    final badgeColor = (deboPago || deboEval)
        ? const Color(0xFFF59E0B)
        : const Color(0xFF94A3B8);
"""
    if old not in t:
        raise SystemExit("list pending marker missing")
    t = t.replace(old, new, 1)

    old_badge = """              if (pending)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pendiente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                )
"""
    new_badge = """              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                )
"""
    if old_badge not in t:
        raise SystemExit("list badge marker missing")
    t = t.replace(old_badge, new_badge, 1)
    if t.count("{") != t.count("}"):
        raise SystemExit(f"list braces {t.count('{')} {t.count('}')}")
    p.write_text(t)
    print("list patched")


def patch_detalle():
    p = Path("lib/mensajes/mensajes_detalle.dart")
    t = p.read_text()
    if "_BannerConfirmar" in t:
        print("detalle already 5.11")
        return

    needle = "    Color border = const Color(0xFFE2E8F0);"
    if needle not in t:
        raise SystemExit("detalle border marker missing")
    t = t.replace(
        needle,
        needle
        + "\n    if (decision == null) {\n      border = const Color(0xFFF59E0B);\n    }",
        1,
    )

    if r"S\u00ed, gracias" in t:
        t = t.replace(r"S\u00ed, gracias", r"S\u00ed, lo recib\u00ed", 1)
    elif "Sí, gracias" in t:
        t = t.replace("Sí, gracias", "Sí, lo recibí", 1)
    else:
        raise SystemExit("detalle cta marker missing")

    old_lv = """                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: timeline.length,
"""
    new_lv = """                Map<String, dynamic>? pendingPago;
                String? pendingPagoId;
                for (final e in events.reversed) {
                  final dd = e.data();
                  if ((dd['tipo'] as String? ?? '') != 'recibo_emitido') {
                    continue;
                  }
                  if (dd['actor_uid'] == myUid) continue;
                  if (respuestasRecibo.containsKey(e.id)) continue;
                  pendingPago = dd;
                  pendingPagoId = e.id;
                  break;
                }

                return Column(
                  children: [
                    if (pendingPago != null && pendingPagoId != null)
                      _BannerConfirmar(
                        monto: MensajesService.formatMonto(pendingPago['monto']),
                        busy: _busy,
                        onAceptar: () => _responderRecibo(
                          reciboEventId: pendingPagoId!,
                          decision: 'aceptado',
                        ),
                        onRechazar: () => _confirmReject(pendingPagoId!),
                      ),
                    Expanded(
                      child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: timeline.length,
"""
    if old_lv not in t:
        raise SystemExit("detalle listview marker missing")
    t = t.replace(old_lv, new_lv, 1)

    old_close = """                  },
                );
              },
            ),
          ),
          Material(
            color: Colors.white,
            elevation: 8,
"""
    new_close = """                  },
                ),
                    ),
                  ],
                );
              },
            ),
          ),
          Material(
            color: Colors.white,
            elevation: 8,
"""
    if old_close not in t:
        raise SystemExit("detalle close marker missing")
    t = t.replace(old_close, new_close, 1)

    banner = '''
class _BannerConfirmar extends StatelessWidget {
  final String monto;
  final bool busy;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  const _BannerConfirmar({
    required this.monto,
    required this.busy,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Te registraron un pago de $monto',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF92400E),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Confirmá si lo recibiste. Queda sellado en PROX.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAceptar,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Sí, lo recibí',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: busy ? null : onRechazar,
                  child: const Text(
                    'Revisar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
'''
    idx = t.find("class _TextoBubble extends StatelessWidget {")
    if idx < 0:
        raise SystemExit("texto bubble marker missing")
    t = t[:idx] + banner + "\n" + t[idx:]

    if t.count("{") != t.count("}"):
        raise SystemExit(f"detalle braces {t.count('{')} {t.count('}')}")
    p.write_text(t)
    print("detalle patched")


if __name__ == "__main__":
    patch_list()
    patch_detalle()
