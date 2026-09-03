# INFORME COMPLETO — Trabajo Práctico Base de Datos II — Unidad 2 Semana 3

> **Universidad Tecnológica Nacional — Tecnicatura Universitaria en Programación**
> **Asignatura:** Base de Datos II — Unidad 2 Semana 3 (Optimización de Consultas — filtros, planes e índices)
> **Autor:** Jerónimo Coronel
> **Fecha:** 2026-09-03
> **Motor:** PostgreSQL 18.6 (psql / pg_dump / createdb) — Windows
> **Esquema base:** FoodStore — `tp-Coronel-BaseDeDatosII/db/schema.sql` + `db/schema_completo.sql`
> **Repositorio:** https://github.com/jeronimocoronel784-hue/BaseDeDatos2
> **Carpeta canónica local:** `C:\BaseDeDatos2\tp-Coronel-BaseDeDatosII\`
> **Estado:** ✅ Entrega completa — 5/5 — defendible línea por línea con EXPLAIN ANALYZE

![UTN](https://img.shields.io/badge/UTN-TUP%20Programación-informational) ![PostgreSQL 18](https://img.shields.io/badge/PostgreSQL-18-336791) ![Estado](https://img.shields.io/badge/Estado-5%2F5%20completo-brightgreen) ![Fecha](https://img.shields.io/badge/Fecha-2026--09--03-blue)

---

## Índice

- [0. Resumen ejecutivo](#0-resumen-ejecutivo)
- [1. Esquema FoodStore](#1-esquema-foodstore)
- [2. Parte 1 — Carga masiva 50k/20k/200k](#2-parte-1--carga-masiva)
- [3. Parte 2 — Laboratorio EXPLAIN ANALYZE](#3-parte-2--laboratorio)
- [4. Parte 3 — Lectura crítica IA](#4-parte-3--lectura-crítica)
- [5. Parte 4 — Specs precisas + EXCEPT](#5-parte-4--specs)
- [6. Parte 5 — Competencia + DUIA](#6-parte-5--competencia)
- [7. Estructura final y commits](#7-estructura)
- [8. Verificación y defensa oral](#8-verificación)

---

## 0. Resumen ejecutivo

TP3 aplica Unidad 2 Semana 3 sobre FoodStore poblado masivamente (50030 productos, 20020 clientes, 200020 pedidos/detalles) con IA como motor primario pero **medición obligatoria** `EXPLAIN (ANALYZE, BUFFERS)` antes/después. Cada índice propuesto se justifica por **nodo atacado** (ej: `Sort 779 + Bitmap Heap Filter RowsRemoved 3940`), con cambio esperado y validación de tiempo real. La IA propone, el estudiante mide y decide.

**Entregables 5/5:**

| # | Entregable | Archivo canónico | Líneas | Estado |
|---|---|---|---|---|
| 1 | Carga masiva 50k/20k/200k con generate_series | `db/carga_masiva_tp3.sql` (176) + `db/schema_completo.sql` (77) + `db/data.sql` (62) | 315 | ✅ |
| 2 | Laboratorio 3 consultas + índices justificados | `db/indices_tp3.sql` + `docs/optimizacion_tp3_parte2.md` | 163+ | ✅ |
| 3 | Lectura crítica 6 afirmaciones IA | `docs/lectura_critica_tp3_parte3.md` | — | ✅ |
| 4 | 2 specs + SQL IA + alternativa + EXCEPT 0 | `db/consultas_tp3_parte4.sql` + `docs/consultas_tp3_parte4.md` | — | ✅ |
| 5 | Competencia + DUIA completa | `docs/competencia_tp3_parte5.md` | — | ✅ |

**Mejora destacada:** Q1 `Sort 779 + Bitmap Heap` → `Index Scan` **6.7x** (2.87→0.43ms, cost 779→105, Buffers 528→103).

---

## 1. Esquema FoodStore

`db/schema.sql:1` (72 líneas) — 5 tablas, `forma_pago_enum`, `ON DELETE RESTRICT`, `activo BOOLEAN`, `CHECK`s, `idx_pedido_cliente`, `idx_producto_categoria_activo`. `db/schema_completo.sql:1` copia idempotente con `IF NOT EXISTS` para cátedra.

Diagrama: `categoria 1—∞ producto —∞ detalle_pedido ∞—1 pedido 1—1 cliente` (PK compuesta `id_pedido+id_producto`).

---

## 2. Parte 1 — Carga masiva

**Script:** `db/carga_masiva_tp3.sql:1` (176 líneas, 10507 bytes) — `generate_series` sin PL/pgSQL, respeta `CHECK (precio>=0, stock>=0, cantidad>0)`, `UNIQUE email`, `FK RESTRICT`, sin `ALTER TABLE`.

**Volumen medido en `foodstore_trabajo`:**
```
producto 50030 (50000 + 30 seed) | cliente 20020 (20000+20) | pedido 200020 (200k+20) | detalle 200020
precio 500.00-5000.00 | stock 0-200 | 8 categorías: 6254 c/u (6253 en 2, pareja ±1) | ANALYZE aplicado
Pre-carga: 12KB dump | Post-carga: 7.17MB dump
```

**Técnicas y mejoras (sin PL/pgSQL):**
- `WITH cats AS (row_number() OVER ...)+((g-1)%cnt)+1` → equitativa perfecta, no `ORDER BY random()`
- Salto primo `997` para detalle → pseudo-aleatorio sin costo
- `LEAST(cantidad, stock) + stock>=5` → evita R2 `stock insuficiente`
- `precio_unitario = producto.precio` → dentro de R3 `0.5x-1.5x`
- `ON CONFLICT DO NOTHING` → idempotencia
- `ANALYZE` final → histogramas para EXPLAIN real

**Protocolo:** `createdb -T foodstore_original foodstore_trabajo` + `pg_dump -Fc` + `BEGIN; \i carga_masiva_tp3.sql; ROLLBACK;` verificado.

---

## 3. Parte 2 — Laboratorio

**3 queries base (`db/queries.sql:1`):**
- Q1: `producto WHERE id_categoria=1 AND activo AND precio BETWEEN 500-2000 ORDER BY precio LIMIT 100`
- Q2: `pedido JOIN detalle JOIN producto WHERE id_cliente=1 ORDER BY fecha DESC LIMIT 50`
- Q3: `pedido JOIN cliente JOIN detalle WHERE fecha 90d AND activo GROUP BY ... HAVING sum>10000 LIMIT 20` (97ms, lenta real)

**Tabla Parte 2.2 (ver docs/optimizacion_tp3_parte2.md completo):**

| Q | ANTES (nodo, cost, exec, buffers) | Índice propuesto (nodo atacado) | DESPUÉS (nodo, cost, exec) | Mejora |
|---|---|---|---|---|
| Q1 | Sort 779 + Bitmap Heap Filter RowsRemoved 3940, cost 779.36, 2.87ms, 528 | `idx_producto_categoria_activo_precio (id_categoria, activo, precio)` — Sort+Filter → Index Cond | Index Scan sin Sort, cost 105.78, 0.429ms, 103 | **6.7x** ✅ |
| Q2 | Sort 252 + Bitmap id_cliente, cost 252, 1.08ms, 136 | `idx_pedido_cliente_fecha (id_cliente, fecha DESC)` — Sort eliminado | Bitmap Index Scan sobre nuevo índice pero Sort persiste, 0.618ms, 133 | 1.75x ⚠️ parcial (21 filas) |
| Q3 | Parallel Seq Scan pedido 8236 RowsRemoved 175k + Gather, cost 16504, 97.4ms, 4912 | `idx_pedido_fecha (fecha)` — Seq Scan → Bitmap | Bitmap Heap Scan Index Cond fecha, cost 11422, 90.23ms, 4667 | 1.08x ✅ |

**Criterio cátedra:** Q1 valida hipótesis, Q2/Q3 documentan "qué se esperaba, qué pasó, por qué" — no se ocultan.

---

## 4. Parte 3 — Lectura crítica

Plan real Q1 con índice: `Limit cost 0.41..49.29 → Index Scan idx_producto_categoria_activo_precio Index Cond exacto, Buffers 55, Exec 0.307ms`.

IA generó 6 frases con errores típicos (ver `docs/lectura_critica_tp3_parte3.md`):

| Afirmación IA | ¿Correcta? | Corrección |
|---|---|---|
| "cost 0.41..49.29 ms" | No | cost son unidades abstractas, no ms; actual time 0.115..0.257ms |
| "Limit tarda 49.29ms" | No | rows=50 es estimación, no filtradas; Limit detiene Index Scan |
| "Lee 50 filas del disco" | No | Buffers hit=55 son páginas cache, no disco (read=1) |
| "Usa idx_producto_categoria_activo" | No | Usa `idx_producto_categoria_activo_precio` (con precio) — el viejo no cubre BETWEEN |
| "No hay Sort por LIMIT" | No | No hay Sort por índice ordenado, no por LIMIT (con LIMIT y sin índice igual hay Sort 779) |
| "Buffers hit=55 filas" | No | Buffers son páginas 8KB, no filas (rows=50) |

---

## 5. Parte 4 — Specs

**Spec 1 (resumen):** categorías vigentes + count productos vigentes (incluye 0), ORDER cantidad DESC — Versión A `LEFT JOIN GROUP BY` vs B `subconsulta correlacionada` — `EXCEPT` 0/0, 8 filas (5956→5882).

**Spec 2 (subconsulta):** clientes vigentes sin pedidos, ORDER id — Versión A `NOT EXISTS` vs B `LEFT JOIN IS NULL` — `NOT IN` descartada por NULL — `EXCEPT` 0/0 (0 filas tras carga masiva, todos tienen ≥9 pedidos; equivalencia ∅=∅ válida).

Ver `db/consultas_tp3_parte4.sql` + `docs/consultas_tp3_parte4.md`.

---

## 6. Parte 5 — Competencia

Consulta común: Q1 `producto por categoría + precio + ORDER BY` — **Gana Coronel 6.7x** (2.87→0.43ms) con `idx_producto_categoria_activo_precio`.

Estrategias probadas 6 (3 aceptadas, 2 descartadas, 1 parcial) — ver `docs/competencia_tp3_parte5.md` con bitácora y DUIA completa (7 filas).

---

## 7. Estructura final y commits

```
tp-Coronel-BaseDeDatosII/
├── db/
│   ├── schema.sql, schema_completo.sql, data.sql, queries.sql
│   ├── carga_masiva_tp3.sql, indices_tp3.sql, consultas_tp3_parte4.sql
│   └── backups/ (preCarga 12KB, postCarga 7.17MB, .gitignore *.dump)
├── docs/
│   ├── optimizacion_tp3_parte2.md, lectura_critica_tp3_parte3.md
│   ├── consultas_tp3_parte4.md, competencia_tp3_parte5.md
│   └── INFORME_COMPLETO_TP3.md (este archivo)
```

**Commits TP3:**
```
54a3958 feat(tp3-parte2): laboratorio EXPLAIN 3 consultas
d77ec43 feat(tp3-parte1): schema_completo + carga masiva 50k/20k/200k
```

---

## 8. Verificación y defensa oral

```bash
createdb foodstore_original && psql -d foodstore_original -f db/schema_completo.sql && psql -d foodstore_original -f db/data.sql
dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
pg_dump -Fc -f db/backups/foodstore_trabajo_pre.dump foodstore_trabajo
psql -d foodstore_trabajo -f db/carga_masiva_tp3.sql  # generate_series
psql -d foodstore_trabajo -f db/indices_tp3.sql
psql -d foodstore_trabajo -c "EXPLAIN (ANALYZE, BUFFERS) SELECT ..."  # validar nodo
psql -d foodstore_trabajo -f db/consultas_tp3_parte4.sql  # EXCEPT 0
```

Cada `CREATE INDEX` y `INSERT` es defendible línea por línea (ver comentarios en `.sql:125`).

---

*Informe TP3 — 2026-09-03 — Jerónimo Coronel — BD II Unidad 2 Semana 3*
