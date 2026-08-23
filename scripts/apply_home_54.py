#!/usr/bin/env python3
"""Apply 5.4 prestador tips hierarchy onto lib/Homepage.dart."""
from pathlib import Path

p = Path("lib/Homepage.dart")
s = p.read_text()
if "SIGUIENTE PASO" in s:
    print("already patched")
    raise SystemExit(0)

s = s.replace(
    "import 'cargaTrabajoTrabajador.dart';",
    "import 'cargaTrabajoTrabajador.dart';\nimport 'capacitacionesflotante.dart';",
    1,
)
s = s.replace(
    "subtitle: 'Hasta 5 cuentan en tu Confianza',",
    "subtitle: 'Se ven en tu tarjeta digital',",
    1,
)

old = (
    "    if (out.length < 5) {\n"
    "      add(_RecoItem(\n"
    "        id: 'fotos_trabajo',\n"
    "        title: 'Subí fotos de trabajos hechos',\n"
    "        subtitle: 'Se ven en tu tarjeta digital',\n"
    "        icon: Icons.photo_library_outlined,\n"
    "        onTap: () => _abrirFlotante(const CargaTrabajoTrabajadorWidget()),\n"
    "      ));\n"
    "    }\n"
    "\n"
    "    return out;"
)
new = (
    "    if (out.length < 5) {\n"
    "      add(_RecoItem(\n"
    "        id: 'fotos_trabajo',\n"
    "        title: 'Subí fotos de trabajos hechos',\n"
    "        subtitle: 'Se ven en tu tarjeta digital',\n"
    "        icon: Icons.photo_library_outlined,\n"
    "        onTap: () => _abrirFlotante(const CargaTrabajoTrabajadorWidget()),\n"
    "      ));\n"
    "    }\n"
    "    final caps = data['capacitaciones'] as List? ?? [];\n"
    "    if (caps.isEmpty && out.length < 5) {\n"
    "      add(_RecoItem(\n"
    "        id: 'capacitaciones',\n"
    "        title: 'Sumá un curso o capacitación',\n"
    "        subtitle: 'Opcional · da solidez a tu perfil',\n"
    "        icon: Icons.school_outlined,\n"
    "        onTap: () => _abrirFlotante(const CapacitacionesFlotanteWidget()),\n"
    "      ));\n"
    "    }\n"
    "\n"
    "    return out;"
)
if old not in s:
    raise SystemExit("fotos block not found")
s = s.replace(old, new, 1)

old = (
    "                    Text(\n"
    "                      label.isNotEmpty ? label : 'Sin nivel aún',\n"
    "                      style: TextStyle(\n"
    "                        fontSize: 28,\n"
    "                        fontWeight: FontWeight.w900,\n"
    "                        letterSpacing: -0.6,\n"
    "                        color: label.isNotEmpty ? Color(colors.foreground) : const Color(0xFF94A3B8),\n"
    "                      ),\n"
    "                    ),\n"
    "                    const SizedBox(height: 16),"
)
new = (
    "                    Text(\n"
    "                      label.isNotEmpty ? label : 'Sin nivel aún',\n"
    "                      style: TextStyle(\n"
    "                        fontSize: 28,\n"
    "                        fontWeight: FontWeight.w900,\n"
    "                        letterSpacing: -0.6,\n"
    "                        color: label.isNotEmpty ? Color(colors.foreground) : const Color(0xFF94A3B8),\n"
    "                      ),\n"
    "                    ),\n"
    "                    if (ScoringService.explicacionBadge(badge.isEmpty ? null : badge)\n"
    "                        .isNotEmpty) ...[\n"
    "                      const SizedBox(height: 4),\n"
    "                      Text(\n"
    "                        ScoringService.explicacionBadge(badge.isEmpty ? null : badge),\n"
    "                        style: TextStyle(\n"
    "                          fontSize: 13,\n"
    "                          height: 1.35,\n"
    "                          color: Colors.grey.shade600,\n"
    "                        ),\n"
    "                      ),\n"
    "                    ],\n"
    "                    const SizedBox(height: 16),"
)
if old not in s:
    raise SystemExit("badge block not found")
s = s.replace(old, new, 1)

marker = "        Builder(\n          builder: (context) {\n            final recos = _recomendacionesPrestador(_dp);"
start = s.find(marker)
reco = s.find("\nclass _RecoItem {")
if start < 0 or reco < 0:
    raise SystemExit(f"markers {start} {reco}")

tips = Path("scripts/home54_tips_snippet.dart").read_text()
s = s[:start] + tips + s[reco:]
if "SIGUIENTE PASO" not in s:
    raise SystemExit("missing SIGUIENTE PASO")
if s.count("{") - s.count("}") != 0:
    raise SystemExit("brace imbalance")
p.write_text(s)
print("patched", len(s))
