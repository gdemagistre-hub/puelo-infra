#!/usr/bin/env python3
"""Etapa 2 — residual copy: comprobante / Doy un pago (no recibo)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
changed = []

def patch(rel: str, replacements: list[tuple[str, str]]) -> None:
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    orig = text
    for old, new in replacements:
        if old not in text:
            # try common unicode variants
            alt = old.replace("í", "\\u00ed").replace("á", "\\u00e1").replace("ñ", "\\u00f1")
            if alt != old and alt in text:
                text = text.replace(alt, new.replace("í", "\\u00ed").replace("á", "\\u00e1").replace("ñ", "\\u00f1"))
                continue
            print(f"WARN missing in {rel}: {old[:70]!r}")
            continue
        text = text.replace(old, new)
    if text != orig:
        path.write_text(text, encoding="utf-8")
        changed.append(rel)
        print(f"OK {rel}")
    else:
        print(f"skip {rel} (no changes)")


patch(
    "lib/mensajes/emitir_recibo_sheet.dart",
    [
        (
            "Todavía no hay contactos ni conversaciones. "
            "Cuando un cliente te escriba por WhatsApp o te llame "
            "desde la app, aparece acá. "
            "También podés pegar el UID (está en su tarjeta).",
            "Todavía no hay contactos. "
            "Abrí la tarjeta del prestador y tocá WhatsApp o Doy un pago. "
            "También podés pegar el UID (está en su tarjeta).",
        ),
        (
            "Aparecen quienes te contactaron por la app y tus conversaciones. "
            "También podés pegar un UID.",
            "Aparecen prestadores que contactaste, clientes que te contactaron y conversaciones. "
            "También podés pegar un UID.",
        ),
    ],
)

patch(
    "lib/mensajes/mensajes_detalle.dart",
    [
        (
            "emití un recibo cuando haya un pago",
            "registrá un comprobante cuando haya un pago",
        ),
        (
            "emit\\u00ed un recibo cuando haya un pago",
            "registr\\u00e1 un comprobante cuando haya un pago",
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
