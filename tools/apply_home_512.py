#!/usr/bin/env python3
from pathlib import Path

p = Path("lib/Homepage.dart")
t = p.read_text()
if "ConfirmarPagoHomeCard" in t:
    print("Homepage already 5.12")
    raise SystemExit(0)

old_imp = "import 'contacto/contactos_prestador_card.dart';"
new_imp = (
    "import 'contacto/contactos_prestador_card.dart';\n"
    "import 'mensajes/confirmar_pago_home_card.dart';"
)
if old_imp not in t:
    raise SystemExit("import marker missing")
t = t.replace(old_imp, new_imp, 1)

old_pad = """      Padding(\n          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),\n          child: homeShowcase(\n            key: HomeTourKeys.primaryBlock,\n            modoPrestador: true,"""
new_pad = """        const ConfirmarPagoHomeCard(),\n        ContactosPrestadorCard(\n          onIrMensajes: () => _selectTab(3),\n        ),\n      Padding(\n          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),\n          child: homeShowcase(\n            key: HomeTourKeys.primaryBlock,\n            modoPrestador: true,"""
if old_pad not in t:
    raise SystemExit("prestador tarjeta marker missing")
t = t.replace(old_pad, new_pad, 1)

old_dup = """        ContactosPrestadorCard(\n          onIrMensajes: () => _selectTab(3),\n        ),\n        Builder("""
new_dup = """        Builder("""
if old_dup not in t:
    raise SystemExit("old contactos card marker missing")
t = t.replace(old_dup, new_dup, 1)

if t.count("ContactosPrestadorCard(") != 1:
    raise SystemExit(f"expected 1 ContactosPrestadorCard, got {t.count('ContactosPrestadorCard(')}")
if t.count("{") != t.count("}"):
    raise SystemExit(f"braces {t.count('{')} {t.count('}')}")
p.write_text(t)
print("Homepage 5.12 patched")
