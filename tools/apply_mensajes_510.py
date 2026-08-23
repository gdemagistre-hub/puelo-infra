#!/usr/bin/env python3
from pathlib import Path

p = Path("lib/mensajes/mensajes_list.dart")
t = p.read_text()
if "class _ContactosPendientes" in t:
    print("mensajes_list already 5.10")
    raise SystemExit(0)

old_empty = """                      return _EmptyState(
                        onEmitir: () => _openEmitir(context),
                      );"""
new_empty = """                      return _EmptyState(
                        onEmitir: () => _openEmitir(context),
                        onEmitirA: (cUid, cNombre) => _openEmitir(
                          context,
                          contraparteUid: cUid,
                          contraparteNombre: cNombre,
                        ),
                      );"""
if old_empty not in t:
    raise SystemExit("empty call marker missing")
t = t.replace(old_empty, new_empty, 1)

old_open = """  Future<void> _openEmitir(BuildContext context) async {
    if (!UserSession().hasRealAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrá con Google o Email para registrar un pago'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const EmitirReciboSheet(),
    );"""
new_open = """  Future<void> _openEmitir(
    BuildContext context, {
    String? contraparteUid,
    String? contraparteNombre,
  }) async {
    if (!UserSession().hasRealAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrá con Google o Email para registrar un pago'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final fijo = (contraparteUid ?? '').trim();
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => EmitirReciboSheet(
        contraparteUidFijo: fijo.isEmpty ? null : fijo,
        contraparteNombre: contraparteNombre,
      ),
    );"""
if old_open not in t:
    raise SystemExit("openEmitir marker missing")
t = t.replace(old_open, new_open, 1)

old_h = """              'Primero contactá al prestador desde su tarjeta (WhatsApp o Doy un pago). '
              'Acá ves comprobantes pendientes de confirmar y evaluaciones.',"""
new_h = """              'Acá ves comprobantes y evaluaciones. '
              'El pago se registra desde la tarjeta (Doy un pago). '
              'Quien recibe lo confirma.',"""
if old_h not in t:
    raise SystemExit("header marker missing")
t = t.replace(old_h, new_h, 1)

snippet = Path("tools/snippets/mensajes_empty_510.dart").read_text()
start = t.find("class _EmptyState extends StatelessWidget {")
end = t.find("class _ErrorBox extends StatelessWidget {")
if start < 0 or end < 0 or end <= start:
    raise SystemExit(f"empty/error markers {start} {end}")
t = t[:start] + snippet + "\n\n" + t[end:]

if t.count("{") != t.count("}"):
    raise SystemExit(f"braces {t.count('{')} {t.count('}')}")
p.write_text(t)
print("mensajes_list 5.10 patched")
