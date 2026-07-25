# Etapa 0 — Inventario y reglas

## Promesa de valor
- **Cliente:** Encontrá quien te hace el trabajo, con gente de confianza.
- **Prestador:** Mostrá tu trabajo y conseguí clientes cerca.
- **Fuera de alcance UI:** Life Wallet, score, préstamos.

## Tokens
| Token | Valor |
|-------|--------|
| Cliente | `#734BE4` |
| Prestador | `#28B5CD` |
| Fondo | `#F8FAFC` |
| Texto | `#1E293B` |
| Legacy (migrar) | `#0F52BA` |

## Pantallas legacy a unificar (Etapa 5 / parcial 1)
- [ ] loginScreen.dart
- [ ] registroCuenta.dart
- [ ] menuEvaluaciones.dart
- [ ] calificarTrabajo.dart
- [ ] cargaTrabajoCliente.dart
- [ ] cargaTrabajoTrabajador.dart
- [ ] registroTrabajador.dart
- [ ] pantallaValidacion.dart
- [ ] validar_domicilio.dart
- [ ] solicitar_validacion.dart
- [ ] menuPerfil.dart
- [ ] splashScreen.dart

## Ya alineadas (parcial)
- Homepage.dart
- buscadorPrestadores.dart
- datosPersonalesflotante.dart
- Domicilioflotante.dart
- perfilCompletoflotante.dart
- especialidadesLaboralesflotante.dart
- ZonaDeTrabajoflotante.dart
- tarjetaDigital.dart (parcial)

## Flags
- `AppEnv.showDevTools` → false en prod
- Build prod web: `flutter build web --dart-define=PUELLO_ENV=prod`
