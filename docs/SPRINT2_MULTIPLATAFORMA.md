# Sprint 2 — Multiplataforma + list fields consistentes

**Fecha:** 2026-08-06  
**Backup pre-Sprint 0 (intacto):** tag `backup/pre-sprint0-20260806T152754Z-df00470` → commit `df00470`

## Objetivo
Evitar crashes de cámara/OCR fuera de mobile y mantener `list_*` / `zona_ids` / `list_visible` actualizados en todos los writes de perfil relevantes, sin tocar el menú Modo prueba.

## Cambios

| Área | Cambio |
|------|--------|
| **`platform_capabilities.dart`** | Helpers: `supportsCamera`, `supportsOcr`, mensajes de error por plataforma |
| **Carga trabajo (cliente/prestador)** | try/catch + `mounted` al elegir fotos |
| **Completar perfil** | Guard cámara; merge `PrestadorListFields` al guardar; invalida cache Home |
| **Datos personales** | Merge `PrestadorListFields` al guardar; invalida cache |
| **Domicilio** | Merge `PrestadorListFields`; invalida cache |
| **Registro trabajador** | Flags prestador + list fields + invalida cache |
| **Capacitaciones** | Oculta “Tomar foto” si no hay cámara nativa |
| **`responsive_shell.dart`** | Utilidad `ResponsiveShell` (max-width) lista para pantallas anchas |

## No tocar
- Tag/branch backup pre-Sprint 0
- Menú “Modo prueba (equipo)” del login

## Deploy
Push a `main` → workflow Hosting.

## Pendiente (sprints siguientes)
- App Check
- Auth obligatorio en writes (cuando se retire el menú temp)
- `ALLOW_DEV_VALIDACION=0`
- UI responsive aplicada de punta a punta en desktop
