# Sprint 3 — List fields en perfiles + guards multiplataforma

**Fecha:** 2026-08-06  
**Backup pre-Sprint 0 (intacto):** `backup/pre-sprint0-20260806T152754Z-df00470` → `df00470`

## Objetivo
Cerrar el follow-up de Sprint 2 (desnormalización `list_*` en todos los writes de perfil) y reforzar guards de cámara, sin tocar el menú Modo prueba.

## Cambios

| Área | Cambio |
|------|--------|
| **Domicilio** | `PrestadorListFields` + invalida cache Home |
| **Completar perfil** | Guard cámara + `PrestadorListFields` + cache |
| **Datos personales** | `PrestadorListFields` + cache |
| **Portfolio prestador** | try/catch al elegir fotos |
| **Capacitaciones** | Oculta “Tomar foto” si no hay cámara nativa |

## No tocar
- Tag/branch backup pre-Sprint 0
- Menú “Modo prueba (equipo)”

## Pendiente (Sprint 4+)
- App Check
- `ALLOW_DEV_VALIDACION=0` (cuando el equipo deje el menú temp)
- Auth obligatorio en writes
- ResponsiveShell aplicado de punta a punta en desktop
