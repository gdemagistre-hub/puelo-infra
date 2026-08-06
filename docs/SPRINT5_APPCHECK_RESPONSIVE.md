# Sprint 5 — App Check suave + cierre list fields

**Fecha:** 2026-08-06  
**Backup pre-Sprint 0 (intacto):** `backup/pre-sprint0-20260806T152754Z-df00470` → `df00470`

## Objetivo
Cerrar cableado de `UsuarioListSync` en completar perfil y datos personales, y preparar App Check / responsive sin romper el menú Modo prueba.

## En este sprint

| Área | Cambio |
|------|--------|
| **Completar perfil** | Guard cámara + `UsuarioListSync.mergeUserDoc` |
| **Datos personales** | `UsuarioListSync.mergeUserDoc` |
| **Docs** | Plan App Check y responsive |

## App Check (preparación, no forzar en cliente aún)

1. Habilitar App Check en consola Firebase (proyecto puelo).
2. Providers: Play Integrity (Android), DeviceCheck/App Attest (iOS), reCAPTCHA v3 (Web).
3. Modo **monitor** primero (no enforce) para no romper el menú de prueba.
4. Solo después de métricas verdes: enforce en Firestore/Storage/Functions.

**No aplicar enforce mientras exista el menú Modo prueba sin Auth real.**

## ResponsiveShell

- Helper ya existe: `lib/responsive_shell.dart`
- Aplicar en login, home y buscador cuando se priorice UX desktop.

## No tocar
- Tag/branch backup pre-Sprint 0
- Menú “Modo prueba (equipo)”
- `ALLOW_DEV_VALIDACION` (sigue en modo equipo)

## Sprint 6+
- Enforce App Check
- Auth obligatorio en writes al retirar menú temp
- `ALLOW_DEV_VALIDACION=0`
