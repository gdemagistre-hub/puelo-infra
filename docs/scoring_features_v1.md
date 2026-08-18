# Scoring Features v1 — Puelo (no bancarizados)

**Model version target:** `v1.2-phase1`  
**Fecha:** 2026-08-18  
**Uso:** scorecard reglas (prod) + export listo para Vertex AI Feature Store / AutoML Tabular  
**Privacidad:** sin montos de Mis Números, sin DNI completo, sin notas del vault.

## Objetivo Stage 1 (prestador)
Features que explican *solidez / confianza* visible (badge, ranking, tips).

## Objetivo Stage 2 (microcrédito)
Mismo vector + `score_credito_preview` como label proxy hasta tener outcomes de pago reales.

## Feature groups

### A. Identidad
| Feature | Tipo | Fuente |
|---------|------|--------|
| f_auth_google | 0/1 | auth_provider |
| f_email | 0/1 | email |
| f_tel | 0/1 | telefono |
| f_tel_verificado | 0/1 | telefono_verificado |
| f_doc_ocr | 0/1 | doc_validado |
| f_foto_perfil | 0/1 | url_foto_perfil |
| f_foto_doc | 0/1 | url_foto_documento |
| f_domicilio_completo | 0/1 | direccion_geo |
| f_genero_doc | 0/1 | genero_documento |
| f_dias_alta | int | creado_en |
| f_techo_antiguedad | 40/70/100 | derivado anti-gaming |

### B. Oficio
| Feature | Tipo | Fuente |
|---------|------|--------|
| f_es_trabajador | 0/1 | es_trabajador |
| f_n_oficios | int | profesiones |
| f_zona_cobertura | 0/1 | zonas_cobertura |
| f_n_capacitaciones | int | capacitaciones |
| f_fotos_portfolio | int | trabajos portfolio |
| f_fotos_clientes | int | trabajos clientes |

### C. Reputación
| Feature | Tipo | Fuente |
|---------|------|--------|
| f_n_eval_trabajo | int | scoring |
| f_n_eval_con_foto | int | detalle |
| f_rating_promedio | 0–5 | promedioEstrellas |
| f_n_validaciones_6m | int | validaciones 183d |
| f_validadores_con_calif | int | grafo |
| f_score_servicio | 0–100 | capa B |
| f_badge_rank | -1–6 | badge |

### D. Comportamiento (sin montos)
| Feature | Tipo | Fuente |
|---------|------|--------|
| f_n_movimientos | int | stats_negocio |
| f_n_cobros | int | stats_negocio |
| f_n_fiados_pend | int | stats_negocio |
| f_n_fiados_cobrados | int | stats_negocio |
| f_fondo_emergencia | 0/1 | stats_negocio |
| f_score_comportamiento | 0–100 | capa E |

### E. Cliente / F. Riesgo
| Feature | Tipo |
|---------|------|
| f_score_cliente | 0–100 |
| f_n_eval_cliente | int |
| f_riesgo_fraude | 0–3 |
| f_n_flags_fraude | int |

### Labels proxy
| Label | Uso |
|-------|-----|
| y_score_identidad | Stage 1 UI |
| y_score_servicio | Ranking |
| y_score_credito_preview | Stage 2 shadow |
| y_badge | Stage 1 |

## Export Firestore `scoring_features/{uid}`

```json
{
  "uid": "...",
  "model_version": "v1.2-phase1",
  "features": { "f_auth_google": 1 },
  "labels": { "y_score_identidad": 72, "y_badge": "bronce" }
}
```

## Vertex (siguiente)
1. Batch diario → JSONL GCS
2. Feature Store entity prestador
3. AutoML Tabular shadow mode
4. No impact UI hasta validar

## Anti-leakage
Sin montos, DNI, teléfono en claro, ni texto libre de comentarios sin control.
