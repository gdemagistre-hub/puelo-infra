#!/usr/bin/env python3
"""Etapa 2 — residual copy: comprobante / Doy un pago (no recibo)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
changed = []

def patch(rel: str, replacements: list) -> None:
    path = ROOT / rel
    if not path.exists():
        print(f"MISSING {rel}")
        return
    text = path.read_text(encoding="utf-8")
    orig = text
    for old, new in replacements:
        if old not in text:
            print(f"WARN missing in {rel}: {old[:70]!r}")
            continue
        text = text.replace(old, new)
        print(f"  ok: {old[:50]!r}")
    if text != orig:
        path.write_text(text, encoding="utf-8")
        changed.append(rel)
        print(f"OK {rel}")
    else:
        print(f"skip {rel} (no changes)")

# emitir — multiline dart concatenations
patch(
    "lib/mensajes/emitir_recibo_sheet.dart",
    [
        (
            "'Todavía no hay contactos ni conversaciones. '\n"
            "                                    'Cuando un cliente te escriba por WhatsApp o te llame '\n"
            "                                    'desde la app, aparece acá. '\n"
            "                                    'También podés pegar el UID (está en su tarjeta).'",
            "'Todavía no hay contactos. '\n"
            "                                    'Abrí la tarjeta del prestador y tocá WhatsApp o Doy un pago. '\n"
            "                                    'También podés pegar el UID (está en su tarjeta).'",
        ),
        (
            "'Aparecen quienes te contactaron por la app y tus conversaciones. '\n"
            "                'También podés pegar un UID.'",
            "'Aparecen prestadores que contactaste, clientes que te contactaron y conversaciones. '\n"
            "                'También podés pegar un UID.'",
        ),
    ],
)

# detalle — unicode escapes as stored in file
patch(
    "lib/mensajes/mensajes_detalle.dart",
    [
        (
            "Escrib\\u00ed algo o emit\\u00ed un recibo cuando haya un pago o se\\u00f1a.",
            "Escrib\\u00ed algo o registr\\u00e1 un comprobante cuando haya un pago o se\\u00f1a.",
        ),
        (
            "Escribí algo o emití un recibo cuando haya un pago o seña.",
            "Escribí algo o registrá un comprobante cuando haya un pago o seña.",
        ),
    ],
)

patch(
    "lib/mensajes/mensajes_service.dart",
    [
        (
            "Necesitás entrar con Google para emitir recibos",
            "Necesitás entrar con Google para registrar un pago",
        ),
        (
            "Ese recibo ya fue respondido.",
            "Ese comprobante ya fue confirmado.",
        ),
    ],
)

patch(
    "lib/tarjetaDigital.dart",
    [
        (
            "Iniciá sesión con Google para registrar un pago",
            "Entrá con Google (no el menú de prueba) para registrar un pago",
        ),
    ],
)

patch(
    "functions/index.js",
    [
        (
            "Ya hay un recibo pendiente en este hilo. Esperá la respuesta o que se resuelva.",
            "Ya hay un comprobante pendiente en este hilo. Esperá la confirmación o que se resuelva.",
        ),
        (
            "last_summary: `Recibo $${monto} · Pendiente`",
            "last_summary: `Pago $${monto} · Pendiente`",
        ),
        (
            'throw new HttpsError("not-found", "Recibo no encontrado");',
            'throw new HttpsError("not-found", "Comprobante no encontrado");',
        ),
        (
            'throw new HttpsError("failed-precondition", "No es un recibo");',
            'throw new HttpsError("failed-precondition", "No es un comprobante de pago");',
        ),
        (
            "No podés responder tu propio recibo",
            "No podés confirmar tu propio comprobante",
        ),
        (
            "Este recibo ya no está pendiente (fue respondido o no es el activo)",
            "Este comprobante ya no está pendiente (fue confirmado o no es el activo)",
        ),
        (
            "? `Recibo $${recibo.monto} · Aceptado`\n        : `Recibo $${recibo.monto} · Rechazado`",
            "? `Pago $${recibo.monto} · Aceptado`\n        : `Pago $${recibo.monto} · Rechazado`",
        ),
    ],
)

print("CHANGED:", ",".join(changed) if changed else "(none)")
