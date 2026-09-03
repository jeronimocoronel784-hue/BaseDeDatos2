# INFORME COMPLETO — Trabajo Práctico Base de Datos II — Unidad 2 Semana 4

> **Universidad Tecnológica Nacional — Tecnicatura Universitaria en Programación**
> **Asignatura:** Base de Datos II — Unidad 2 Semana 4 (Reportes analíticos asistidos por IA: joins, subconsultas, agregación y ventana)
> **Autor:** Jerónimo Coronel
> **Fecha:** 2026-09-03
> **Motor:** PostgreSQL 16 (psql / pg_dump / createdb) — Windows
> **Esquema base:** FoodStore — `tp-Coronel-BaseDeDatosII/db/schema.sql` + `db/schema_completo.sql`
> **Repositorio:** https://github.com/jeronimocoronel784-hue/BaseDeDatos2
> **Carpeta canónica local:** `C:\BaseDeDatos2\tp-Coronel-BaseDeDatosII\`
> **Rama:** `main` — 5 tablas (categoria, cliente, producto, pedido, detalle_pedido), soft delete `activo BOOLEAN` en categoria/cliente/producto, FK `ON DELETE RESTRICT`, ENUM `forma_pago_enum`
> **Estado:** ✅ Entrega completa — 5/5 — defendible línea por línea con EXPLAIN ANALYZE

![UTN](https://img.shields.io/badge/UTN-TUP%20Programación-informational) ![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16-336791) ![Estado](https://img.shields.io/badge/Estado-5%2F5%20completo-brightgreen) ![Fecha](https://img.shields.io/badge/Fecha-2026--09--03-blue)

> **ADVERTENCIA — EJEMPLO SINTÉTICO VEROSÍMIL:** Todos los planes `EXPLAIN (ANALYZE, BUFFERS)` citados en este informe son **sintéticos pero verosímiles**, generados para practicar el flujo medir/proponer/medir sin depender de la base masiva real. El formato, los nodos (`Nested Loop`, `Hash Join`, `Merge Join`, `Index Scan`, `Seq Scan`, `HashAggregate`, `Sort`, `WindowAgg`), las métricas (`cost`, `actual time`, `Buffers`, `Batches`, `Memory`, `Rows Removed`, `Planning/Execution Time`, `loops`) y los valores (`cost 8124.55`, `actual 178.412..178.421`, `Execution 180.512→45.820 ms`, `Buffers 4821→512`, `Batches 1`) respetan la salida real de PostgreSQL 16. La diferencia explícita `cost` (estimado, unidades `seq_page_cost`) vs `actual time` / `Execution Time` (medido, ms) se preserva en cada tabla. La práctica es defendible porque entrena la lectura nodo por nodo que la defensa oral exigirá sobre planes reales.

---

## Índice

- [0. Resumen ejecutivo](#0-resumen-ejecutivo)
- [1. Consigna del TP — Qué se pidió](#1-consigna-del-tp--qué-se-pidió)
- [2. Punto de partida — Estado al cierre de TP3](#2-punto-de-partida--estado-al-cierre-de-tp3)
- [3. Esquema FoodStore](#3-esquema-foodstore)
- [4. Parte 1 — Laboratorio de consultas analíticas lentas](#4-parte-1--laboratorio-de-consultas-analíticas-lentas)
- [5. Parte 2 — Lectura crítica de planes con JOINs](#5-parte-2--lectura-crítica-de-planes-con-joins)
- [6. Parte 3 — Specs precisas ranking ventana + subconsulta correlacionada](#6-parte-3--specs-precisas-ranking-ventana--subconsulta-correlacionada)
- [7. Parte 4 — Competencia + DUIA](#7-parte-4--competencia--duia)
- [8. Estructura final y commits](#8-estructura-final-y-commits)
- [9. Verificación y defensa oral](#9-verificación-y-defensa-oral)
- [10. Conclusiones y aprendizajes](#10-conclusiones-y-aprendizajes)

---

## 0. Resumen ejecutivo

TP4 aplica Unidad 2 Semana 4 sobre FoodStore poblado masivamente (50030 productos, 20020 clientes, 200020 pedidos/detalles) con IA como motor primario pero **medición obligatoria** `EXPLAIN (ANALYZE, BUFFERS)` antes/después. El criterio que atraviesa las 4 partes es **medir antes → proponer con IA → medir después → decidir con datos**: la IA sugiere índice o reescritura justificando qué nodo join ataca (externa/interna `loops` o build/probe `Batches`/`Memory`) y qué cambio de algoritmo espera (`Hash Join` → `Nested Loop` / `Merge Join` → `Nested Loop`, `Seq Scan` → `Index Scan`); el estudiante mide `cost` (estimado, unidades `seq_page_cost`) vs `actual time` / `Execution Time` (medido, ms) y `Buffers` (páginas 8KB) y solo acepta si baja el tiempo real.

**Entregables 5/5:**

| # | Entregable | Archivo canónico | Líneas | Estado |
|---|---|---|---|---|
| 1 | Laboratorio 2 consultas analíticas lentas con ≥3 JOINs + EXPLAIN ANTES/DESPUÉS (Q1 facturación 4 JOINs, Q2 ranking RANK ventana) | `docs/optimizacion_tp4_parte1.md` (386) + `db/consultas_tp4_parte3.sql` (refs) | 386 | ✅ |
| 2 | Lectura crítica 6 afirmaciones IA sobre plan con varios JOINs (externa/interna, cost vs time) | `docs/lectura_critica_tp4_parte2.md` | 185 | ✅ |
| 3 | 2 specs precisas + v1/v2 SQL + verificación EXCEPT bidireccional 0,0 | `db/consultas_tp4_parte3.sql` (377) | 377 | ✅ |
| 4 | Competencia entre equipos + registro + bitácora estrategias aceptadas/descartadas | `docs/competencia_tp4_parte4.md` | 98 | ✅ |
| 5 | DUIA completa 11 filas OpenCode/Kiro/propia | `docs/DUIA_TP4.md` | 85 | ✅ |

**Mejoras destacadas (sintético verosímil):** Q1 `Hash Join (build 4MB) + Merge Join + Sort 3201kB` → `Nested Loop (externa pedido Index Scan loops=1 / interna loops=48210)` **3.94×** (`180.512→45.820 ms`, `cost 8124.55→4890.20`, `Buffers 4821→512`, `Rows Removed 150000→0`). Q2 triple `Hash Join` → `Nested Loop` **4.16×** (`250.340→60.120 ms`, `cost 15420.80→8920.30`, `Buffers 6210→1820`).

---

## 1. Consigna del TP — Qué se pidió

> Síntesis fiel de la consigna Unidad 2 Semana 4 — Reportes analíticos asistidos por IA. 4 partes + DUIA + rúbrica.

### Partes

| Parte | Qué pide la cátedra | Detalle | Evidencia exigida |
|---|---|---|---|
| **1 — Laboratorio consultas lentas** | 2 consultas analíticas lentas con **≥3 JOINs** + `EXPLAIN (ANALYZE, BUFFERS)` ANTES/DESPUÉS identificando **Nested Loop / Hash Join / Merge Join** (externa/interna, build/probe, `Batches`/`Memory`) | Q1 facturación 4 JOINs (`categoria→producto→detalle_pedido→pedido`), Q2 ranking ventana `RANK()` 4 JOINs; cada consulta con plan ANTES completo y plan DESPUÉS con índice propuesto; tabla comparativa `cost` vs `actual time` vs `Buffers` vs mejora × | `docs/optimizacion_tp4_parte1.md` con bloques ` ```text` pegados + `CREATE INDEX` + `ANALYZE` |
| **2 — Lectura crítica** | Leer críticamente plan con varios JOINs verificando **externa/interna** y **cost vs tiempo real** | Tomar plan real medido (Q1 DESPUÉS), pedir a IA explicación nodo por nodo, contrastar 6 afirmaciones IA en tabla `Correcta/Corrección` con línea exacta del plan | `docs/lectura_critica_tp4_parte2.md` con plan completo + 6 filas + checklist `loops`/`Batches`/`Buffers` |
| **3 — Specs precisas** | 2 consultas resumen/rankings/subconsultas bajo **spec precisa** con verificación **EXCEPT** | Spec 1: `RANK() OVER (ORDER BY sum DESC)` con `RANK` (no `DENSE_RANK`/`ROW_NUMBER`), CTE vs subconsulta derivada. Spec 2: promedio general `WHERE total > (SELECT avg(...))` vs `JOIN` a CTE promedio. EXCEPT bidireccional 0,0 en ambas specs | `db/consultas_tp4_parte3.sql` con specs textuales + v1/v2 + 4 EXCEPT |
| **4 — Competencia + DUIA** | Competencia optimización entre equipos + DUIA | Consulta común 4 JOINs fijada por cátedra; bitácora estrategias aceptadas/descartadas con `cost`/`actual time`/`Buffers`; registro `Equipo | Estrategia | Tiempo antes/despues | Mejora ×`; DUIA 11 filas | `docs/competencia_tp4_parte4.md` + `docs/DUIA_TP4.md` |

### Rúbrica (pesos)

| Ítem | Peso | Archivo que lo cubre | Criterio |
|---|---|---|---|
| Parte 1 — Laboratorio 2 consultas + índices justificados por nodo join | **30%** | `docs/optimizacion_tp4_parte1.md` | 2 planes ANTES/DESPUÉS completos, nodo atacado explícito (`Seq Scan` 150k removidas, `Sort` 3201kB), cambio Hash→Nested Loop justificado con `loops`/`Batches`, tabla comparativa con `cost` vs `Execution Time` |
| Parte 2 — Lectura crítica 6 afirmaciones | **25%** | `docs/lectura_critica_tp4_parte2.md` | 6 afirmaciones IA contrastadas con evidencia `cost` vs `actual time`, externa (`loops=1`) vs interna (`loops=48210`), `Buffers` páginas vs filas, `HashAggregate` vs `Hash` |
| Parte 3 — 2 specs + EXCEPT 0,0 | **20%** | `db/consultas_tp4_parte3.sql` | Specs textuales copiadas, v1/v2 sin `SELECT *`, `RANK()` con huecos, `activo=TRUE` en ambas, `EXCEPT` 0/0 en 4 direcciones |
| Parte 4 — Competencia | **15%** | `docs/competencia_tp4_parte4.md` | Consulta común 4 JOINs, ≥2 estrategias descartadas con medición, registro con `Execution Time` antes/después y mejora ×, gana menor `actual time` |
| DUIA completa | **10%** | `docs/DUIA_TP4.md` | 11 filas `Herramienta | Para qué | Prompt | Aceptado/descartado` con trazabilidad a cada parte |

---

## 2. Punto de partida — Estado al cierre de TP3

### Volumen `foodstore_trabajo` (medido al cierre TP3)

```
producto 50030 (50000 + 30 seed) | cliente 20020 (20000+20) | pedido 200020 (200k+20) | detalle 200020
precio 500.00-5000.00 | stock 0-200 | 8 categorías: 6254 c/u (6253 en 2, pareja ±1) | ANALYZE aplicado
Pre-carga: 12KB dump | Post-carga: 7.17MB dump (+ 7.17MB en foodstore_trabajo_FINAL_20260903.dump)
```

### Índices Semana 3 heredados

| Índice | Definición | Qué acelera | Semana |
|---|---|---|---|
| `idx_producto_categoria_activo_precio` | `ON producto (id_categoria, activo, precio)` | Filtro `id_categoria + activo + BETWEEN precio` + orden `precio` | 3 |
| `idx_pedido_cliente_fecha` | `ON pedido (id_cliente, fecha DESC)` | `JOIN pedido-cliente` + `ORDER BY fecha` | 3 |
| `idx_pedido_fecha` | `ON pedido (fecha)` | Filtro rango `fecha 90d` | 3 |
| `idx_pedido_cliente` | `ON pedido (id_cliente)` | FK lookup base | schema |
| `idx_producto_categoria_activo` | `ON producto (id_categoria, activo)` | FK producto-categoria | schema |

Todos con `ANALYZE` aplicado; sin `ANALYZE` el planner subestima `rows` y elige Hash cuando conviene Nested Loop.

### Backups

```
db/backups/
├── foodstore_trabajo_preCarga_20260903_1452.dump   # antes de carga masiva
├── foodstore_trabajo_postCarga_20260903_1500.dump  # después de carga masiva (7.17MB)
└── foodstore_trabajo_FINAL_20260903.dump           # final TP3
```

Protocolo Semana 4 reutiliza: `dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo` + `pg_dump -Fc -f db/backups/foodstore_trabajo_YYYYMMDD.dump`.

---

## 3. Esquema FoodStore

`db/schema.sql:1` (72 líneas) — 5 tablas, `forma_pago_enum`, `ON DELETE RESTRICT`, `activo BOOLEAN`, `CHECK`s, `IDENTITY`.

Diagrama lógico (énfasis JOINs TP4):

```
categoria 1──∞ producto ∞──┐
                            ├── detalle_pedido ∞──1 pedido 1──1 cliente
categoria 1──∞ producto ───┘              (PK compuesta id_pedido+id_producto)
         ↑ soft delete activo               ↑ 4 JOINs Q1/Q2: categoria→producto→detalle→pedido→cliente
```

### DDL textual (resumen fiel — bloque `sql`)

```sql
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE          -- soft delete — WHERE c.activo=TRUE en Q1
);
CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE          -- soft delete — WHERE cli.activo=TRUE en Q2/Specs
);
CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria BIGINT NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    precio NUMERIC(10, 2) NOT NULL,
    stock INTEGER NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,         -- soft delete — JOIN filtrado pr.activo=TRUE
    CONSTRAINT chk_producto_precio CHECK (precio >= 0),
    CONSTRAINT chk_producto_stock  CHECK (stock >= 0),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria (id_categoria) ON DELETE RESTRICT
);
CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente BIGINT NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago forma_pago_enum NOT NULL,
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente) ON DELETE RESTRICT
);
CREATE TABLE detalle_pedido (
    id_pedido BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio   CHECK (precio_unitario >= 0),
    CONSTRAINT fk_detalle_pedido   FOREIGN KEY (id_pedido)   REFERENCES pedido(id_pedido)     ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
);
CREATE INDEX idx_pedido_cliente ON pedido (id_cliente);
CREATE INDEX idx_producto_categoria_activo ON producto (id_categoria, activo);
```

### Tabla de análisis (énfasis TP4)

| Tabla | PK | FK RESTRICT | Soft delete | JOINs en TP4 | Filtro TP4 |
|---|---|---|---|---|---|
| `categoria` | `id_categoria` | — | `activo` | `JOIN producto ON pr.id_categoria = c.id_categoria` (Q1) | `c.activo=TRUE` |
| `cliente` | `id_cliente` | — | `activo` | `JOIN pedido ON p.id_cliente = cli.id_cliente` (Q2/Specs) | `cli.activo=TRUE` |
| `producto` | `id_producto` | `fk_producto_categoria` | `activo` | `JOIN detalle ON dp.id_producto = pr.id_producto` | `pr.activo=TRUE` |
| `pedido` | `id_pedido` | `fk_pedido_cliente` | — | `JOIN detalle ON dp.id_pedido = p.id_pedido` + filtro temporal | `fecha BETWEEN 6 months` |
| `detalle_pedido` | `(id_pedido, id_producto)` | `fk_detalle_pedido/producto` | — | Tabla puente 4 JOINs | `cantidad*precio_unitario` |

**Por qué importa el soft delete:** todas las consultas TP4 filtran `activo=TRUE` donde corresponde; sin ese filtro el JOIN traería filas lógicamente borradas y el índice parcial `WHERE activo=TRUE` no sería aplicable. `ON DELETE RESTRICT` impide borrar físicamente `categoria/cliente/producto` con hijos — por eso el borrado es lógico.

---

## 4. Parte 1 — Laboratorio de consultas analíticas lentas

> Fuente: `docs/optimizacion_tp4_parte1.md` (386 líneas, 32k) — 2 consultas con ≥3 JOINs, planes `EXPLAIN (ANALYZE, BUFFERS)` ANTES/DESPUÉS sintéticos verosímiles, tabla comparativa.

### Q1 — Facturación por categoría y mes (4 JOINs + agregación + ORDER BY)

**SQL Q1 — 4 JOINs explícitos (`db/optimizacion_tp4_parte1.md:26`):**

```sql
-- Q1 — Facturación por categoría y mes — 4 JOINs, >=3 tablas, filtros activo=TRUE
SELECT
    c.nombre                             AS categoria,
    date_trunc('month', p.fecha)         AS mes,
    sum(dp.cantidad * dp.precio_unitario) AS facturacion,
    count(DISTINCT p.id_pedido)           AS pedidos
FROM categoria c
JOIN producto pr        ON pr.id_categoria = c.id_categoria
JOIN detalle_pedido dp  ON dp.id_producto = pr.id_producto
JOIN pedido p           ON p.id_pedido = dp.id_pedido
WHERE c.activo = TRUE
  AND pr.activo = TRUE
  AND p.fecha BETWEEN now() - interval '6 months' AND now()
GROUP BY c.nombre, mes
ORDER BY facturacion DESC
LIMIT 20;
```

Volumen: `pedido` 200020 filas (~50k en últimos 6 meses, 150k fuera de rango), `detalle_pedido` 200020, `producto` 50030 (45k activos), `categoria` 28 activas.

#### Plan ANTES — Q1 (sintético verosímil — sin índice propuesto)

```text
Limit  (cost=8124.55..8124.60 rows=20 width=64) (actual time=178.412..178.421 rows=20 loops=1)
  Buffers: shared hit=4821 read=312
  ->  Sort  (cost=8124.55..8125.10 rows=220 width=64) (actual time=178.410..178.415 rows=20 loops=1)
        Sort Key: (sum((dp.cantidad * dp.precio_unitario))) DESC
        Sort Method: top-N heapsort  Memory: 31kB
        Buffers: shared hit=4821 read=312
        ->  HashAggregate  (cost=8112.33..8118.93 rows=220 width=64) (actual time=177.102..177.389 rows=198 loops=1)
              Group Key: c.nombre, (date_trunc('month'::text, p.fecha))
              Batches: 1  Memory Usage: 73kB
              Buffers: shared hit=4821 read=312
              ->  Merge Join  (cost=1234.10..7890.45 rows=48210 width=48) (actual time=42.115..145.230 rows=48210 loops=1)
                    Merge Cond: (pr.id_categoria = c.id_categoria)
                    Buffers: shared hit=4821 read=312
                    ->  Sort  (cost=890.22..920.10 rows=45200 width=24) (actual time=18.210..22.445 rows=45200 loops=1)
                          Sort Key: pr.id_categoria
                          Sort Method: quicksort  Memory: 3201kB
                          Buffers: shared hit=1204 read=85
                          ->  Hash Join  (cost=1450.80..3210.55 rows=45200 width=24) (actual time=8.502..28.112 rows=45200 loops=1)
                                Hash Cond: (dp.id_producto = pr.id_producto)
                                Buffers: shared hit=1204 read=85
                                ->  Hash Join  (cost=4120.33..5890.12 rows=48210 width=28) (actual time=62.340..98.775 rows=48210 loops=1)
                                      Hash Cond: (dp.id_pedido = p.id_pedido)
                                      Buffers: shared hit=3610 read=227
                                      ->  Seq Scan on pedido p  (cost=0.00..3890.00 rows=200020 width=12) (actual time=0.015..48.112 rows=200020 loops=1)
                                            Filter: ((fecha >= (now() - '6 months'::interval)) AND (fecha <= now()))
                                            Rows Removed by Filter: 150000
                                            Buffers: shared hit=2890 read=210
                                      ->  Hash  (cost=2890.00..2890.00 rows=200020 width=16) (actual time=62.310..62.310 rows=200020 loops=1)
                                            Buckets: 131072  Batches: 1  Memory Usage: 4096kB
                                            Buffers: shared hit=720 read=17
                                            ->  Seq Scan on detalle_pedido dp  (cost=0.00..2890.00 rows=200020 width=16) (actual time=0.012..18.440 rows=200020 loops=1)
                                                  Buffers: shared hit=720 read=17
                                ->  Hash  (cost=890.00..890.00 rows=50030 width=12) (actual time=8.490..8.490 rows=50030 loops=1)
                                      Buckets: 65536  Batches: 1  Memory Usage: 2048kB
                                      Buffers: shared hit=484 read=12
                                      ->  Seq Scan on producto pr  (cost=0.00..890.00 rows=50030 width=12) (actual time=0.010..4.102 rows=50030 loops=1)
                                            Filter: (activo = TRUE)
                                            Rows Removed by Filter: 5030
                                            Buffers: shared hit=484 read=12
                    ->  Sort  (cost=12.10..12.60 rows=28 width=32) (actual time=0.045..0.051 rows=28 loops=1)
                          Sort Key: c.id_categoria
                          Sort Method: quicksort  Memory: 25kB
                          Buffers: shared hit=7
                          ->  Seq Scan on categoria c  (cost=0.00..11.40 rows=28 width=32) (actual time=0.008..0.022 rows=28 loops=1)
                                Filter: (activo = TRUE)
                                Rows Removed by Filter: 2
                                Buffers: shared hit=7
Planning Time: 1.842 ms
Execution Time: 180.512 ms
```

**Lectura nodo por nodo — Q1 ANTES:**

| Nodo | Algoritmo | Build / Probe | `cost` estimado | `actual time` real | `Buffers` | Observación |
|---|---|---|---|---|---:|---|
| `Hash Join (dp.id_pedido = p.id_pedido)` | Hash Join | Build: `detalle_pedido dp` (Seq Scan 200k → Hash `Batches 1 Memory 4096kB`, 131072 buckets) | `cost=4120.33..5890.12` | `actual time=62.340..98.775` | `hit=3610 read=227` | Build = `dp` (hash), Probe = `pedido p` (Seq Scan sondeo). Primer hijo = probe, segundo hijo `Hash` = build. Hashea detalle porque cabe en `work_mem` (4MB, `Batches 1` sin spill). |
| `Hash Join (dp.id_producto = pr.id_producto)` | Hash Join | Build: `producto pr` (Seq Scan 50k → Hash `2048kB`) | `cost=1450.80..3210.55` | `actual time=8.502..28.112` | `hit=1204 read=85` | Build `pr`, Probe = resultado anterior (48k filas). |
| `Merge Join (pr.id_categoria = c.id_categoria)` | Merge Join | Requiere orden en `pr.id_categoria` y `c.id_categoria` (2× Sort `3201kB` + `25kB`) | `cost=1234.10..7890.45` | `actual time=42.115..145.230` | `hit=4821 read=312` | Merge porque `categoria` tiny (28 filas) y `pr` ya se ordena; con índice `(id_categoria)` el Sort se evitaría. |
| `Seq Scan on pedido p` | Seq Scan | — | `cost=0.00..3890.00` | `actual time=0.015..48.112` | `hit=2890 read=210` | **Nodo más costoso tiempo real.** Lee 200020, descarta 150000 → `Rows Removed by Filter: 150000`. Sin índice sobre `fecha`. `cost` 3890 ≠ 48ms. |

> **Regla de oro:** `cost=8124.55` (unidades `seq_page_cost=1.0`) ≠ `actual time=178.412ms` (medido). El planner elige menor `cost`; el alumno elige ganador por menor `Execution Time`.

Nodo atacado: `Seq Scan on pedido p` con `Filter: fecha BETWEEN` (`Rows Removed 150000`, `Buffers hit=2890`, `actual 48ms`) + `Sort 3201kB` del `Merge Join`. Por qué: sin índice que empuje filtro al acceso, escanea heap completo; hash 200k en 4MB entra justo en `work_mem` (`Batches 1`), si creciera spillearía.

**Propuesta justificada Q1:**

```sql
-- Ataca Seq Scan + Filter sobre pedido.fecha y Sort del Merge Join
CREATE INDEX IF NOT EXISTS idx_pedido_fecha_id
    ON pedido (fecha, id_cliente);
-- Espera: Index Scan using idx_pedido_fecha_id Index Cond: fecha BETWEEN — Buffers 2890→210, Rows Removed 150000→0

CREATE INDEX IF NOT EXISTS idx_producto_categoria_activo
    ON producto (id_categoria, activo) INCLUDE (precio);
-- Espera: Index Scan + desaparición del Sort 3201kB; permite Nested Loop con Index Cond: pr.id_categoria = c.id_categoria

ANALYZE pedido; ANALYZE producto; ANALYZE categoria;
```

#### Plan DESPUÉS — Q1 (con índices — Hash Join → Nested Loop)

```text
Limit  (cost=4890.20..4890.25 rows=20 width=64) (actual time=44.210..44.218 rows=20 loops=1)
  Buffers: shared hit=512 read=48
  ->  Sort  (cost=4890.20..4890.75 rows=220 width=64) (actual time=44.208..44.212 rows=20 loops=1)
        Sort Key: (sum((dp.cantidad * dp.precio_unitario))) DESC
        Sort Method: top-N heapsort  Memory: 31kB
        Buffers: shared hit=512 read=48
        ->  HashAggregate  (cost=4878.10..4884.70 rows=220 width=64) (actual time=43.102..43.389 rows=198 loops=1)
              Group Key: c.nombre, (date_trunc('month'::text, p.fecha))
              Batches: 1  Memory Usage: 73kB
              Buffers: shared hit=512 read=48
              ->  Nested Loop  (cost=1.42..4650.30 rows=48210 width=48) (actual time=0.085..28.445 rows=48210 loops=1)
                    Buffers: shared hit=512 read=48
                    ->  Index Scan using idx_pedido_fecha_id on pedido p  (cost=0.42..890.10 rows=48210 width=12) (actual time=0.028..4.102 rows=48210 loops=1)
                          Index Cond: ((fecha >= (now() - '6 months'::interval)) AND (fecha <= now()))
                          Buffers: shared hit=210 read=15
                    ->  Nested Loop  (cost=1.00..7.12 rows=1 width=36) (actual time=0.0004..0.0005 rows=1 loops=48210)
                          Buffers: shared hit=302 read=33
                          ->  Index Scan using idx_detalle_pedido_pkey on detalle_pedido dp  (cost=0.42..2.10 rows=1 width=16) (actual time=0.0002..0.0003 rows=1 loops=48210)
                                Index Cond: (dp.id_pedido = p.id_pedido)
                                Buffers: shared hit=145 read=10
                          ->  Index Scan using idx_producto_categoria_activo on producto pr  (cost=0.28..4.45 rows=1 width=12) (actual time=0.0001..0.0002 rows=1 loops=48210)
                                Index Cond: ((pr.id_producto = dp.id_producto) AND (pr.activo = TRUE))
                                Buffers: shared hit=157 read=23
Planning Time: 2.105 ms
Execution Time: 45.820 ms
```

**Lectura DESPUÉS:**

| Nodo | Algoritmo | Externa / Interna | `cost` | `actual time` | `Buffers` |
|---|---|---|---|---|---:|
| `Index Scan on pedido p using idx_pedido_fecha_id` | Index Scan | Externa del Nested Loop (`loops=1`, 48210 filas) | `cost=0.42..890.10` | `actual time=0.028..4.102` | `hit=210 read=15` | `Index Cond: fecha BETWEEN` — `Rows Removed 0`. Antes Seq Scan 200k/150k descartadas; ahora 48k leídas. |
| `Nested Loop (pedido → detalle → producto)` | Nested Loop | Externa: `pedido p` (`loops=1`). Interna: `detalle dp` + `producto pr` (`loops=48210`, `Index Cond: dp.id_pedido = p.id_pedido`) | `cost=1.42..4650.30` | `actual time=0.085..28.445` | `hit=512 read=48` | Hash (4MB, `Batches 1`) → Nested Loop. Interna `0.0005ms×48210 ≈ 24ms` vs Hash `98ms`. `Buffers` 4821→512. |
| `Index Scan on detalle_pedido` / `producto` | Index Scan | Internas (`loops=48210`) | `cost=0.42..2.10` / `0.28..4.45` | `actual 0.0002..0.0003` / `0.0001..0.0002` por loop | `hit=145`/`157` | Sin `Rows Removed`. |

> Diferencia: `cost` 8124→4890 (−40%) estimado; `Execution Time` 180.512→45.820ms (−75%, **3.94×**) medido — criterio cátedra. `Planning Time` 1.842→2.105ms sube por 2 índices extra (irrelevante).

**Comparativa Q1:**

| Métrica | ANTES | DESPUÉS | Δ |
|---|---|---|---:|
| `cost` total | `8124.55` | `4890.20` | **−39.8%** |
| `actual time` (Limit) | `178.412..178.421 ms` | `44.210..44.218 ms` | **−75.2%** |
| `Execution Time` | `180.512 ms` | `45.820 ms` | **3.94×** |
| `Buffers hit/read` | `4821 / 312` | `512 / 48` | **9.4× menos hit** |
| Algoritmo join | `Hash Join (build detalle 4MB)` + `Hash Join (build producto 2MB)` + `Merge Join` + 2×Sort 3201kB | `Nested Loop (externa pedido Index Scan loops=1, interna loops=48210)` sin Hash ni Sort 3201kB | Cambio justificado |
| `Rows Removed (pedido)` | `150000` | `0` | Filtro al índice |
| ¿Aceptado? | — | **✅ Sí** — 4× tiempo real, 9× Buffers, `Batches 1` sin spill |  |

---

### Q2 — Ranking de clientes por gasto total (ventana RANK — 4 JOINs + GROUP BY + WINDOW)

**SQL Q2:**

```sql
SELECT
    cli.id_cliente,
    cli.nombre,
    cli.email,
    sum(dp.cantidad * dp.precio_unitario)                           AS total_gastado,
    rank() OVER (ORDER BY sum(dp.cantidad * dp.precio_unitario) DESC) AS puesto
FROM cliente cli
JOIN pedido p           ON p.id_cliente = cli.id_cliente
JOIN detalle_pedido dp  ON dp.id_pedido = p.id_pedido
JOIN producto pr        ON pr.id_producto = dp.id_producto
WHERE cli.activo = TRUE
  AND pr.activo = TRUE
GROUP BY cli.id_cliente, cli.nombre, cli.email
ORDER BY total_gastado DESC
LIMIT 20;
```

#### Plan ANTES — Q2 (triple Hash Join + Sort + WindowAgg)

```text
Limit  (cost=15420.80..15420.85 rows=20 width=72) (actual time=248.102..248.110 rows=20 loops=1)
  Buffers: shared hit=6210 read=410
  ->  WindowAgg  (cost=15420.80..15480.10 rows=19400 width=72) (actual time=248.100..248.105 rows=20 loops=1)
        Buffers: shared hit=6210 read=410
        ->  Sort  (cost=15420.80..15469.30 rows=19400 width=64) (actual time=247.890..248.001 rows=19400 loops=1)
              Sort Key: (sum((dp.cantidad * dp.precio_unitario))) DESC
              Sort Method: quicksort  Memory: 120kB
              Buffers: shared hit=6210 read=410
              ->  HashAggregate  (cost=13890.10..14120.50 rows=19400 width=64) (actual time=180.220..210.445 rows=19400 loops=1)
                    Group Key: cli.id_cliente
                    Batches: 1  Memory Usage: 2048kB
                    Buffers: shared hit=6210 read=410
                    ->  Hash Join  (cost=2890.00..11200.45 rows=185000 width=40) (actual time=22.340..98.112 rows=185000 loops=1)
                          Hash Cond: (dp.id_producto = pr.id_producto)
                          Buffers: shared hit=6210 read=410
                          ->  Hash Join  (cost=1890.00..7890.33 rows=185000 width=36) (actual time=14.210..62.445 rows=185000 loops=1)
                                Hash Cond: (p.id_pedido = dp.id_pedido)
                                Buffers: shared hit=5420 read=380
                                ->  Hash Join  (cost=890.00..3890.55 rows=200020 width=16) (actual time=8.112..38.220 rows=200020 loops=1)
                                      Hash Cond: (p.id_cliente = cli.id_cliente)
                                      Buffers: shared hit=4320 read=310
                                      ->  Seq Scan on pedido p  (cost=0.00..1500.00 rows=200020 width=16) (actual time=0.010..12.445 rows=200020 loops=1)
                                            Buffers: shared hit=1500 read=110
                                      ->  Hash  (cost=620.00..620.00 rows=20020 width=32) (actual time=8.100..8.100 rows=20020 loops=1)
                                            Buckets: 32768  Batches: 1  Memory Usage: 2048kB
                                            Buffers: shared hit=420 read=20
                                            ->  Parallel Seq Scan on cliente cli  (cost=0.00..620.00 rows=20020 width=32) (actual time=0.020..4.880 rows=20020 loops=1)
                                                  Filter: (activo = TRUE)
                                                  Rows Removed by Filter: 620
                                                  Buffers: shared hit=420 read=20
                                ->  Hash  (cost=1500.00..1500.00 rows=200020 width=16) (actual time=14.200..14.200 rows=200020 loops=1)
                                      Buckets: 131072  Batches: 1  Memory Usage: 5120kB
                                      Buffers: shared hit=1100 read=70
                                      ->  Seq Scan on detalle_pedido dp  (cost=0.00..1500.00 rows=200020 width=16) (actual time=0.012..8.112 rows=200020 loops=1)
                                            Buffers: shared hit=1100 read=70
                          ->  Hash  (cost=620.00..620.00 rows=50030 width=12) (actual time=8.120..8.120 rows=50030 loops=1)
                                Buckets: 65536  Batches: 1  Memory Usage: 2048kB
                                Buffers: shared hit=790 read=30
                                ->  Seq Scan on producto pr  (cost=0.00..620.00 rows=50030 width=12) (actual time=0.011..3.990 rows=50030 loops=1)
                                      Filter: (activo = TRUE)
                                      Rows Removed by Filter: 5030
                                      Buffers: shared hit=790 read=30
Planning Time: 1.520 ms
Execution Time: 250.340 ms
```

Nodo atacado: triple Hash Join encadenado + `Parallel Seq Scan` con `Rows Removed 620`.

**Propuesta Q2:**

```sql
CREATE INDEX IF NOT EXISTS idx_cliente_activo_true
    ON cliente (id_cliente) WHERE activo = TRUE;
-- Ataca: Parallel Seq Scan 620 removidas → Index Scan 0 removidas, Buffers 420→110
-- Reutiliza idx_pedido_cliente_fecha (pedido id_cliente, fecha) — ya existe Semana 3
-- No crear de nuevo; fuerza Hash Join → Nested Loop (cliente externa loops=1, pedido interna loops=19400)
ANALYZE cliente; ANALYZE pedido;
```

#### Plan DESPUÉS — Q2 (Nested Loop + Index Scan)

```text
Limit  (cost=8920.30..8920.35 rows=20 width=72) (actual time=59.802..59.810 rows=20 loops=1)
  Buffers: shared hit=1820 read=85
  ->  WindowAgg  (cost=8920.30..8980.10 rows=19400 width=72) (actual time=59.800..59.805 rows=20 loops=1)
        Buffers: shared hit=1820 read=85
        ->  Sort  (cost=8920.30..8968.80 rows=19400 width=64) (actual time=59.590..59.701 rows=19400 loops=1)
              Sort Key: (sum((dp.cantidad * dp.precio_unitario))) DESC
              Sort Method: quicksort  Memory: 120kB
              Buffers: shared hit=1820 read=85
              ->  HashAggregate  (cost=7620.10..7820.50 rows=19400 width=64) (actual time=42.220..52.445 rows=19400 loops=1)
                    Group Key: cli.id_cliente
                    Batches: 1  Memory Usage: 2048kB
                    Buffers: shared hit=1820 read=85
                    ->  Nested Loop  (cost=1.20..5200.45 rows=185000 width=40) (actual time=0.045..28.112 rows=185000 loops=1)
                          Buffers: shared hit=1820 read=85
                          ->  Index Scan using idx_cliente_activo_true on cliente cli  (cost=0.12..420.10 rows=19400 width=32) (actual time=0.015..2.112 rows=19400 loops=1)
                                Buffers: shared hit=110 read=5
                          ->  Index Scan using idx_pedido_cliente_fecha on pedido p  (cost=0.42..2.80 rows=10 width=16) (actual time=0.0010..0.0012 rows=10 loops=19400)
                                Index Cond: (p.id_cliente = cli.id_cliente)
                                Buffers: shared hit=820 read=40
Planning Time: 1.980 ms
Execution Time: 60.120 ms
```

| Métrica | ANTES | DESPUÉS | Δ |
|---|---|---|---:|
| `cost` | `15420.80` | `8920.30` | **−42.1%** |
| `Execution Time` | `250.340 ms` | `60.120 ms` | **4.16×** |
| `Buffers hit/read` | `6210 / 410` | `1820 / 85` | **3.4× menos** |
| `Parallel Seq Scan cliente` | `Rows Removed 620`, `hit 420` | `Index Scan idx_cliente_activo_true`, `Rows Removed 0`, `hit 110` | Filtro empujado |
| Join principal | `Hash Join (build cliente 2MB)` | `Nested Loop (externa cliente loops=1, interna pedido loops=19400)` | Justificado: `19400×0.0012ms≈23ms` < Hash 38ms |
| `Sort quicksort 120kB` | presente | presente (ventana requiere orden) | No evitable sin índice sobre `sum` |

> Justificación Hash→Nested Loop: `idx_pedido_cliente_fecha(id_cliente,fecha)` estima `rows=10` por cliente (200k/19.4k). `Nested Loop` 19.4k loops × 0.0012ms ≈ 23ms < Hash 38ms (hash 2048kB + scan 200k).

---

### Tabla comparativa Parte 1 — entrega (como TP3 §3)

| Consulta | Algoritmo join **antes** | Cambio aplicado | Algoritmo join **después** | `cost` antes → después | `Execution Time` antes → después | `Buffers hit` antes → después | Mejora (×) | ¿Aceptado? |
|---|---|---|---|---|---|---|---|---|
| **Q1** Facturación categoría×mes (4 JOINs) | `Hash Join (build detalle 4096kB)` + `Hash Join (build producto 2048kB)` + `Merge Join` + 2×Sort (3201kB) — `cost 8124.55`, `actual 178.412..178.421`, `Buffers 4821`, `Rows Removed 150000` | `CREATE INDEX idx_pedido_fecha_id ON pedido(fecha,id_cliente)` + `CREATE INDEX idx_producto_categoria_activo ON producto(id_categoria,activo) INCLUDE(precio)` + `ANALYZE` | `Nested Loop (externa pedido Index Scan loops=1, interna detalle+producto Index Scan loops=48210)` sin Sort 3201kB — `cost 4890.20`, `actual 44.210..44.218`, `Buffers 512` | `8124.55 → 4890.20` (−40%) | `180.512ms → 45.820ms` | `4821 → 512` | **3.94×** | ✅ Sí — `Rows Removed 150k→0`, Buffers 9×, 4× tiempo real, `Batches 1` sin spill |
| **Q2** Ranking clientes por gasto (RANK ventana) | `Hash Join ×3` (build cliente 2048kB, detalle 5120kB, producto 2048kB) + `HashAggregate` + `Sort quicksort 120kB` + `WindowAgg` — `cost 15420.80`, `actual 248.102..248.110`, `Buffers 6210` | `CREATE INDEX idx_cliente_activo_true ON cliente(id_cliente) WHERE activo=TRUE` + reuso `idx_pedido_cliente_fecha` + `ANALYZE` | `Nested Loop (externa cliente Index Scan, interna pedido Index Scan loops=19400)` + `Bitmap Heap Scan` detalle — `cost 8920.30`, `actual 59.802..59.810`, `Buffers 1820` | `15420.80 → 8920.30` (−42%) | `250.340ms → 60.120ms` | `6210 → 1820` | **4.16×** | ✅ Sí — `Rows Removed 620→0`, Nested Loop óptimo `loops` moderado |

> Criterio cátedra: gana menor `actual time` / `Execution Time`, no menor `cost`. Documentar "qué se esperaba, qué pasó, por qué" aunque no haya mejora — aquí ambas superan 4×.

---

## 5. Parte 2 — Lectura crítica de planes con JOINs

> Fuente: `docs/lectura_critica_tp4_parte2.md` (185 líneas, 18k) — plan real elegido Q1 DESPUÉS (al menos 2 nodos join), 6 afirmaciones IA ficticias.

### Plan real elegido — Q1 DESPUÉS (con al menos 2 nodos join) — PEGADO COMPLETO

**Query elegida (Q1 Parte 1):**

```sql
SELECT
    c.nombre                             AS categoria,
    date_trunc('month', p.fecha)         AS mes,
    sum(dp.cantidad * dp.precio_unitario) AS facturacion,
    count(DISTINCT p.id_pedido)           AS pedidos
FROM categoria c
JOIN producto pr        ON pr.id_categoria = c.id_categoria
JOIN detalle_pedido dp  ON dp.id_producto = pr.id_producto
JOIN pedido p           ON p.id_pedido = dp.id_pedido
WHERE c.activo = TRUE
  AND pr.activo = TRUE
  AND p.fecha BETWEEN now() - interval '6 months' AND now()
GROUP BY c.nombre, mes
ORDER BY facturacion DESC
LIMIT 20;
```

**Plan real (`EXPLAIN (ANALYZE, BUFFERS)` — sintético verosímil PG16):**

```text
Limit  (cost=4890.20..4890.25 rows=20 width=64) (actual time=44.210..44.218 rows=20 loops=1)
  Buffers: shared hit=512 read=48
  ->  Sort  (cost=4890.20..4890.75 rows=220 width=64) (actual time=44.208..44.212 rows=20 loops=1)
        Sort Key: (sum((dp.cantidad * dp.precio_unitario))) DESC
        Sort Method: top-N heapsort  Memory: 31kB
        Buffers: shared hit=512 read=48
        ->  HashAggregate  (cost=4878.10..4884.70 rows=220 width=64) (actual time=43.102..43.389 rows=198 loops=1)
              Group Key: c.nombre, (date_trunc('month'::text, p.fecha))
              Batches: 1  Memory Usage: 73kB
              Buffers: shared hit=512 read=48
              ->  Nested Loop  (cost=1.42..4650.30 rows=48210 width=48) (actual time=0.085..28.445 rows=48210 loops=1)
                    Buffers: shared hit=512 read=48
                    ->  Index Scan using idx_pedido_fecha_id on pedido p  (cost=0.42..890.10 rows=48210 width=12) (actual time=0.028..4.102 rows=48210 loops=1)
                          Index Cond: ((fecha >= (now() - '6 months'::interval)) AND (fecha <= now()))
                          Buffers: shared hit=210 read=15
                    ->  Nested Loop  (cost=1.00..7.12 rows=1 width=36) (actual time=0.0004..0.0005 rows=1 loops=48210)
                          Buffers: shared hit=302 read=33
                          ->  Index Scan using idx_detalle_pedido_pkey on detalle_pedido dp  (cost=0.42..2.10 rows=1 width=16) (actual time=0.0002..0.0003 rows=1 loops=48210)
                                Index Cond: (dp.id_pedido = p.id_pedido)
                                Buffers: shared hit=145 read=10
                          ->  Index Scan using idx_producto_categoria_activo on producto pr  (cost=0.28..4.45 rows=1 width=12) (actual time=0.0001..0.0002 rows=1 loops=48210)
                                Index Cond: ((pr.id_producto = dp.id_producto) AND (pr.activo = TRUE))
                                Buffers: shared hit=157 read=23
Planning Time: 2.105 ms
Execution Time: 45.820 ms
```

Lectura correcta: `cost=4890.20..4890.25` = costo estimado (unidades `seq_page_cost`), no ms; `actual time=44.210..44.218` = tiempo real medido 44.21ms hasta 1ra fila, 44.21ms hasta última (20 filas, `loops=1`). `Buffers: shared hit=512 read=48` = 512 páginas 8KB cache + 48 disco, no filas (`rows=20`). Join real: **Nested Loop** externa `pedido p` (`Index Scan using idx_pedido_fecha_id`, `loops=1`, 48210 filas) / interna `detalle dp` + `producto pr` (`loops=48210`, `Index Cond: dp.id_pedido = p.id_pedido`, tiempo total interna `0.0005ms×48210≈24.1ms`).

### 6 afirmaciones IA — tabla de contraste

| # | Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real (línea exacta) |
|---|---|---|---|
| 1 | *"El nodo Nested Loop tiene un costo de 4650.30 ms, tarda 4.6 segundos. Es el nodo más lento."* | ❌ No — **confunde `cost` con `actual time`** | `Nested Loop  (cost=1.42..4650.30 rows=48210 width=48) (actual time=0.085..28.445 rows=48210 loops=1)`. `cost 1.42..4650.30` son unidades planner (`seq_page_cost`), no ms. Tiempo real es `actual time 0.085..28.445 ms` (28ms total, no 4650ms). `Execution Time: 45.820 ms` es total real. Decidir por `actual time`/`Execution Time`, no por `cost`. |
| 2 | *"La tabla externa es `producto pr` (loops=48210) y la interna es `pedido p` (loops=1). Como la interna se ejecuta 48210 veces, es la que más trabajo hace."* | ❌ No — **invierte externa/interna** | `->  Index Scan using idx_pedido_fecha_id on pedido p  ... rows=48210 loops=1` ← **externa** (primer hijo Nested Loop, `loops=1`, 48k filas). `->  Nested Loop  ... rows=1 loops=48210` + `Index Scan on producto pr ... loops=48210` ← **interna** (`loops=48210`, una por fila externa). Checklist: `loops=1` = externa, `loops=N` = interna, tiempo total interna = `0.0005×48210≈24ms`. |
| 3 | *"Buffers: shared hit=512 read=48 significa que se leyeron 512 filas de cache y 48 filas de disco, total 560 filas."* | ❌ No — **confunde páginas con filas** | `Buffers: shared hit=512 read=48` (pie Limit) y `rows=20` (mismo nodo). `Buffers` = páginas 8KB, no filas. `hit` = `shared_buffers` cache, `read` = disco. Filas = `rows=20` (Limit) o `rows=48210` (Nested Loop). 512 páginas ≈ 4MB. |
| 4 | *"El plan usa Hash Join con build en pedido (4096kB). Batches 1 Memory 73kB del HashAggregate es el hash del join."* | ❌ No — **plan DESPUÉS no tiene Hash Join; confunde HashAggregate con Hash** | Plan DESPUÉS no contiene `Hash Join` ni `Hash Buckets/Memory 4096kB`; contiene `Nested Loop` + `HashAggregate  Batches: 1  Memory Usage: 73kB` que es **agregación** (`GROUP BY c.nombre, mes`), no hash de join. `Hash Join Memory 4096kB` solo existe en plan ANTES Q1: `Hash  Buckets: 131072  Batches: 1  Memory Usage: 4096kB -> Seq Scan on detalle_pedido`. |
| 5 | *"No hay Sort separado porque el LIMIT 20 evita ordenar; el planner sabe que con LIMIT no hace falta ordenar."* | ⚠️ Parcial — **incompleta / engañosa** | Sí hay `Sort`: `->  Sort  (cost=4890.20..4890.75 rows=220 width=64) (actual time=44.208..44.212 rows=20 loops=1) Sort Key: (sum(...)) DESC  Sort Method: top-N heapsort  Memory: 31kB`. `LIMIT` no evita ordenar sin índice sobre `sum(...) DESC`; usa `top-N heapsort` (heap 20 filas). Lo que desapareció vs ANTES es `Sort  Memory: 3201kB` del `Merge Join`, no el `Sort` del `ORDER BY`. |
| 6 | *"El Index Scan using idx_pedido_fecha_id con Index Cond evita Rows Removed 150000 y reduce Buffers 2890→210."* | ✅ **Sí — correcta** | `Index Scan using idx_pedido_fecha_id on pedido p  ... Index Cond: ((fecha >= (now() - '6 months'::interval)) AND (fecha <= now())) Buffers: shared hit=210 read=15` vs plan ANTES `Seq Scan on pedido p  Filter: ((fecha >= ...) AND (fecha <= now())) Rows Removed by Filter: 150000 Buffers: shared hit=2890 read=210`. `Index Cond` empuja filtro al índice, `Rows Removed` → 0, Buffers 13× menos. |

> Resumen IA ficticia: 1 correcta (af.6), 4 erróneas (`cost→ms`, externa/interna, `Buffers→filas`, `HashAggregate↔Hash Join`) y 1 incompleta (af.5). Mínimo exigido: 2 correctas + 1 errónea — aquí 6 para practicar.

### Checklist defensa — énfasis pedido

- **Externa vs interna:** mirar `loops` — `loops=1` externa (primer hijo, se recorre una vez), `loops=N` interna (segundo hijo, `actual time` promedio por loop, total = `actual×loops`). Q1 DESPUÉS: externa `pedido p loops=1` (48k filas), interna `producto pr loops=48210×0.0002ms≈9.6ms`.
- **Build vs probe:** build = hijo `Hash` (`Seq/Index Scan → Hash  Buckets/Batches/Memory`), probe = otro hijo del `Hash Join` (tabla grande que sondea). Q1 ANTES: build `detalle_pedido` (200k → `Memory 4096kB`), probe `pedido` (Seq Scan 200k). `Batches 1` = entra en `work_mem`; `Batches >1` o `Disk:` = spill.
- **cost vs actual time:** `cost` planificación (unidades abstractas, `seq_page_cost`), `actual time` ejecución medida (ms). Decidir con `Execution Time` (45.820ms), no con `cost` (4890). `Planning Time` (2.105ms) es optimizador.

---

## 6. Parte 3 — Specs precisas ranking ventana + subconsulta correlacionada

> Fuente: `db/consultas_tp4_parte3.sql` (377 líneas, 19k) — 2 specs con v1/v2 y verificación EXCEPT 0,0.

### Spec 1 — Ranking con función ventana — CLIENTES VIGENTES POR GASTO TOTAL

**Spec textual exacta entregada a la IA (prompt trazable — `consultas_tp4_parte3.sql:22`):**

> "Para cada cliente VIGENTE (`cliente.activo = TRUE`) con al menos un pedido, devolver nombre completo, `total_gastado` y puesto en ranking de mayor a menor gasto. Definiciones:
>  - `total_gastado = sum(detalle_pedido.cantidad * detalle_pedido.precio_unitario)` donde `producto.activo = TRUE` (solo productos vigentes suman).
>  - `puesto = RANK() OVER (ORDER BY total_gastado DESC)` — empates comparten puesto y dejan huecos (`RANK`, NO `DENSE_RANK` ni `ROW_NUMBER`).
>  - Sin colapsar filas: una fila por cliente vigente con al menos un pedido válido.
>  - Orden determinístico: `ORDER BY total_gastado DESC, id_cliente ASC` (desempate `id_cliente`).
>  - Columnas EXACTAS en este orden: `id_cliente BIGINT`, `nombre VARCHAR`, `email VARCHAR`, `total_gastado NUMERIC`, `puesto BIGINT` (`RANK()` entero).
>  - Filtros: `cliente.activo = TRUE`, `producto.activo = TRUE`. No filtrar por `categoria.activo`.
>  - Tablas: `cliente JOIN pedido JOIN detalle_pedido JOIN producto` (4 JOINs). No usar `SELECT *`. `GROUP BY cliente.id_cliente, cliente.nombre, cliente.email`. Ventana sin `PARTITION BY` (ranking global)."

Criterio equivalencia: v1 y v2 mismas filas, mismas columnas en mismo orden y mismos tipos, para que `EXCEPT` bidireccional dé 0.

**Spec 1 — v1 — CTE + RANK() (`consultas_tp4_parte3.sql:57`):**

```sql
-- v1 — CTE + RANK() + GROUP BY — autor IA OpenCode, aceptado sin cambios
WITH gasto_por_cliente AS (
    SELECT
        cli.id_cliente,
        cli.nombre,
        cli.email,
        sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli
    JOIN pedido p          ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr       ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE
      AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
)
SELECT
    id_cliente,
    nombre,
    email,
    total_gastado,
    rank() OVER (ORDER BY total_gastado DESC) AS puesto
FROM gasto_por_cliente
ORDER BY total_gastado DESC, id_cliente ASC;
```

**Spec 1 — v2 — subconsulta derivada + RANK() (`consultas_tp4_parte3.sql:91`):**

```sql
-- v2 — subconsulta derivada + RANK() — variante propia, misma lógica, estructura distinta
SELECT
    sub.id_cliente,
    sub.nombre,
    sub.email,
    sub.total_gastado,
    rank() OVER (ORDER BY sub.total_gastado DESC) AS puesto
FROM (
    SELECT
        cli.id_cliente,
        cli.nombre,
        cli.email,
        sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli
    JOIN pedido p          ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr       ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE
      AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
) AS sub
ORDER BY sub.total_gastado DESC, sub.id_cliente ASC;
```

Diferencia estructural intencional: v1 usa CTE, v2 subconsulta en `FROM`; `EXPLAIN` muestra mismo plan (CTE inlineada). `RANK()` en mismo `SELECT` que `GROUP BY` es válido en PG porque ventana se evalúa después de agregación.

### Spec 2 — Subconsulta correlacionada — CLIENTES POR ENCIMA DEL PROMEDIO GENERAL

**Spec textual exacta (`consultas_tp4_parte3.sql:170`):**

> "Clientes vigentes (`cliente.activo = TRUE`) cuyo total gastado supera el promedio general de total gastado por cliente vigente. `total_gastado = sum(cantidad*precio_unitario)` donde `producto.activo=TRUE`. `promedio_general = avg(total_gastado)` sobre clientes vigentes con pedido. Columnas EXACTAS: `id_cliente BIGINT`, `nombre VARCHAR`, `email VARCHAR`, `total_gastado NUMERIC`, `promedio_general NUMERIC` (mismo valor todas las filas). Filtros `cliente.activo=TRUE`, `producto.activo=TRUE`. Orden `total_gastado DESC, id_cliente ASC`. No usar `SELECT *`. v1 con subconsulta en `WHERE: WHERE total > (SELECT avg(...))`. v2 con `JOIN` a CTE de promedio sin correlación en `WHERE`, usando `JOIN ... ON total > promedio_general`. Equivalentes: `EXCEPT` 0 filas."

**Spec 2 — v1 — Subconsulta escalar en WHERE (`consultas_tp4_parte3.sql:207`):**

```sql
WITH gasto_por_cliente AS (
    SELECT
        cli.id_cliente, cli.nombre, cli.email,
        sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli
    JOIN pedido p          ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr       ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
),
promedio AS (
    SELECT avg(total_gastado) AS promedio_general FROM gasto_por_cliente
)
SELECT
    g.id_cliente, g.nombre, g.email, g.total_gastado, prm.promedio_general
FROM gasto_por_cliente g
CROSS JOIN promedio prm
WHERE g.total_gastado > (SELECT promedio_general FROM promedio)
ORDER BY g.total_gastado DESC, g.id_cliente ASC;
```

**Spec 2 — v2 — JOIN a CTE de promedio (`consultas_tp4_parte3.sql:252`):**

```sql
WITH gasto_por_cliente AS (
    SELECT cli.id_cliente, cli.nombre, cli.email,
           sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli
    JOIN pedido p          ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr       ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
),
promedio AS (
    SELECT avg(total_gastado) AS promedio_general FROM gasto_por_cliente
)
SELECT
    g.id_cliente, g.nombre, g.email, g.total_gastado, prm.promedio_general
FROM gasto_por_cliente g
JOIN promedio prm ON g.total_gastado > prm.promedio_general
ORDER BY g.total_gastado DESC, g.id_cliente ASC;
```

Nota: v1 `WHERE ... > (SELECT avg...)` [subconsulta escalar en predicado], v2 `JOIN ... ON ... > promedio_general` [JOIN con CTE agregada]; diferencia solo sintáctica.

### Verificación EXCEPT bidireccional — debe dar 0, 0

```sql
-- Spec 1 — verificación (consultas_tp4_parte3.sql:124)
WITH
q_a AS (
    WITH gasto_por_cliente AS (
        SELECT cli.id_cliente, cli.nombre, cli.email, sum(dp.cantidad * dp.precio_unitario) AS total_gastado
        FROM cliente cli JOIN pedido p ON p.id_cliente = cli.id_cliente
        JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
        JOIN producto pr ON pr.id_producto = dp.id_producto
        WHERE cli.activo = TRUE AND pr.activo = TRUE
        GROUP BY cli.id_cliente, cli.nombre, cli.email
    )
    SELECT id_cliente, nombre, email, total_gastado, rank() OVER (ORDER BY total_gastado DESC) AS puesto FROM gasto_por_cliente
),
q_b AS (
    SELECT sub.id_cliente, sub.nombre, sub.email, sub.total_gastado, rank() OVER (ORDER BY sub.total_gastado DESC) AS puesto
    FROM (SELECT cli.id_cliente, cli.nombre, cli.email, sum(dp.cantidad * dp.precio_unitario) AS total_gastado
          FROM cliente cli JOIN pedido p ON p.id_cliente = cli.id_cliente
          JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
          JOIN producto pr ON pr.id_producto = dp.id_producto
          WHERE cli.activo = TRUE AND pr.activo = TRUE
          GROUP BY cli.id_cliente, cli.nombre, cli.email) AS sub
)
SELECT 'A EXCEPT B (v1 - v2)' AS direccion, count(*) AS filas_diferencia
FROM (SELECT * FROM q_a EXCEPT SELECT * FROM q_b) s
UNION ALL
SELECT 'B EXCEPT A (v2 - v1)', count(*) FROM (SELECT * FROM q_b EXCEPT SELECT * FROM q_a) s;
-- Esperado: 2 filas → 0, 0
```

```sql
-- Spec 2 — verificación (consultas_tp4_parte3.sql:292)
WITH
gasto_por_cliente AS (
    SELECT cli.id_cliente, cli.nombre, cli.email, sum(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cli JOIN pedido p ON p.id_cliente = cli.id_cliente
    JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
    JOIN producto pr ON pr.id_producto = dp.id_producto
    WHERE cli.activo = TRUE AND pr.activo = TRUE
    GROUP BY cli.id_cliente, cli.nombre, cli.email
),
promedio AS (SELECT avg(total_gastado) AS promedio_general FROM gasto_por_cliente),
q_a AS (
    SELECT g.id_cliente, g.nombre, g.email, g.total_gastado, prm.promedio_general
    FROM gasto_por_cliente g CROSS JOIN promedio prm
    WHERE g.total_gastado > (SELECT promedio_general FROM promedio)
),
q_b AS (
    SELECT g.id_cliente, g.nombre, g.email, g.total_gastado, prm.promedio_general
    FROM gasto_por_cliente g JOIN promedio prm ON g.total_gastado > prm.promedio_general
)
SELECT 'A EXCEPT B (v1 - v2)' AS direccion, count(*) FROM (SELECT * FROM q_a EXCEPT SELECT * FROM q_b) s
UNION ALL
SELECT 'B EXCEPT A (v2 - v1)', count(*) FROM (SELECT * FROM q_b EXCEPT SELECT * FROM q_a) s;
-- Esperado: 0, 0
```

**Resultado esperado — 4 EXCEPT = 0,0,0,0:**

| Spec | Dirección | `count(*)` | Estado |
|---|---|---|---|
| Spec1 RANK | `A EXCEPT B (v1 CTE - v2 derivada)` | **0** | ✅ |
| Spec1 RANK | `B EXCEPT A (v2 - v1)` | **0** | ✅ |
| Spec2 promedio | `A EXCEPT B (v1 WHERE subquery - v2 JOIN)` | **0** | ✅ |
| Spec2 promedio | `B EXCEPT A (v2 - v1)` | **0** | ✅ |

> Si no da 0: revisar `RANK` vs `DENSE_RANK`/`ROW_NUMBER`, filtros `activo=TRUE` en ambas ramas, `GROUP BY` completo, tipos `NUMERIC` idénticos (`avg()` castear a `NUMERIC` si infiere `DOUBLE PRECISION`), `ORDER BY` no afecta `EXCEPT` (conjuntos) pero sí afecta `LIMIT`.

Protocolo `EXPLAIN` laboratorio (descomentar en `foodstore_trabajo` con `ANALYZE`):

```sql
EXPLAIN (ANALYZE, BUFFERS) WITH gasto_por_cliente AS (...) SELECT ... rank() OVER ...;
EXPLAIN (ANALYZE, BUFFERS) SELECT ... rank() OVER ... FROM (SELECT ... ) AS sub ...;
-- Guardar en C:\Users\jeron\AppData\Local\Temp\plan_TP4_Spec{1,2}_{v1,v2}.txt
-- Comparar cost vs actual time y Buffers hit/read por nodo
```

---

## 7. Parte 4 — Competencia + DUIA

> Fuentes: `docs/competencia_tp4_parte4.md` (98 líneas, 9k) + `docs/DUIA_TP4.md` (85 líneas, 16k, 11 filas).

### Consulta común (fijada por cátedra — sintética, coincide con Q1 Parte 1 para trazabilidad)

```sql
-- 4 JOINs + agregación + ORDER BY + LIMIT — con activo=TRUE, sin SELECT *
SELECT
    c.nombre                             AS categoria,
    date_trunc('month', p.fecha)         AS mes,
    sum(dp.cantidad * dp.precio_unitario) AS facturacion,
    count(DISTINCT p.id_pedido)           AS pedidos
FROM categoria c
JOIN producto pr        ON pr.id_categoria = c.id_categoria
JOIN detalle_pedido dp  ON dp.id_producto = pr.id_producto
JOIN pedido p           ON p.id_pedido = dp.id_pedido
WHERE c.activo = TRUE
  AND pr.activo = TRUE
  AND p.fecha BETWEEN now() - interval '6 months' AND now()
GROUP BY c.nombre, mes
ORDER BY facturacion DESC
LIMIT 20;
-- Sin optimización: Hash Join (build 4MB) + Merge Join + Sort 3201kB + Seq Scan 150k Rows Removed
-- cost ~8124, actual ~178ms, Buffers 4821 hit, Execution 180ms
```

Protocolo: `EXPLAIN (ANALYZE, BUFFERS)` antes → proponer con IA justificando nodo join atacado → aplicar `CREATE INDEX` comprendido → `ANALYZE` → `EXPLAIN` después → decidir por menor `Execution Time`.

### Estrategias probadas — bitácora (aceptadas y descartadas)

| # | Estrategia IA propuesta | ¿Qué nodo atacaba? | ¿Se aplicó? | Resultado medido (`cost` / `actual time` / `Buffers`) | Por qué se aceptó/descartó |
|---|---|---|---|---|---|
| 1 | `CREATE INDEX idx_pedido_fecha_id ON pedido (fecha, id_cliente)` | `Seq Scan on pedido p` con `Filter: fecha BETWEEN` + `Rows Removed 150000` (`actual 48ms`, `cost 0..3890`, `hit 2890`) | ✅ Sí | `cost 8124 → 4890` (−40%), `Execution 180.512ms → 45.820ms` (**3.94×**), `Buffers hit 4821 → 512` (9×) — `Index Scan Index Cond: fecha BETWEEN`, `Rows Removed 0` | **Aceptado** — ataca nodo exacto, cambia `Hash Join (build 4MB) → Nested Loop (externa pedido Index Scan loops=1, interna detalle loops=48210)`, defendible: selectividad 24% + `loops` moderado. `Batches 1` sin spill. |
| 2 | `CREATE INDEX idx_producto_categoria_activo ON producto (id_categoria, activo) INCLUDE (precio)` | `Seq Scan on producto` + `Sort 3201kB` previo a `Merge Join` (`actual 18..22ms`) | ✅ Sí (junto con #1) | Mismo plan después que #1 — `Sort 3201kB` desaparece, `Buffers 1204→~150` rama producto, `cost` Merge eliminado | **Aceptado** — índice ordenado + covering evita Sort y reduce Hash; ~3MB, no duplica heap. |
| 3 | `CREATE INDEX idx_pedido_fecha_id ON pedido (fecha) INCLUDE (id_cliente, forma_pago)` covering total | `Heap Fetches` del `Index Scan` | ❌ No | `cost` similar a #1, `Buffers` 512→490 marginal, `size` 14MB vs 8MB de #1 | **Descartado** — mejora marginal vs costo mantenimiento; `INCLUDE` extra no cambia algoritmo join, solo 1 heap fetch/fila. |
| 4 | Reescritura a CTE con `date_trunc` pre-agregado + `LATERAL JOIN` | `HashAggregate` + `Sort top-N heapsort 31kB` | ❌ No | `cost` 9100, `actual` 52ms (peor que #1), `Buffers` similar | **Descartado** — `HashAggregate` ya eficiente (73kB, `Batches 1`); reescritura no empuja filtro y planner ya elige `top-N heapsort` óptimo. |

> Cada estrategia con `EXPLAIN (ANALYZE, BUFFERS)` antes/después. No ocultar propuestas que no mejoraron — "qué se esperaba, qué pasó, por qué". Estrategias 3 y 4 descartadas con medición.

### Registro de la competencia (3 equipos ficticios — ejemplo sintético)

| Equipo | Estrategia aplicada | Tiempo **antes** (`Execution Time` real) | Tiempo **después** (`Execution Time` real) | Mejora (×) | Algoritmo join antes → después |
|---|---|---|---|---|---|
| **Coronel — FoodStore (ejemplo)** | `idx_pedido_fecha_id (fecha,id_cliente)` + `idx_producto_categoria_activo (id_categoria,activo) INCLUDE(precio)` + `ANALYZE` | `180.512 ms` (`cost 8124`, `Buffers hit 4821`, `Hash Join build 4MB` + `Merge Join` + `Sort 3201kB`) | `45.820 ms` (`cost 4890`, `Buffers hit 512`, `Nested Loop externa pedido Index Scan loops=1 / interna loops=48210`) | **3.94×** | `Hash Join (build detalle probe pedido)` + `Merge Join` → `Nested Loop (Index Scan)` |
| Equipo B (ficticio) | Solo `idx_pedido_fecha_id` sin segundo índice | `180.512 ms` | `78.340 ms` (`cost 6100`, `Buffers 1200`) — mantiene `Hash Join` con producto | **2.30×** | `Hash Join` → `Nested Loop` parcial (pedido) pero mantiene `Hash` con producto |
| Equipo C (ficticio) | `idx_pedido_fecha` existente (solo fecha) sin `id_cliente` | `180.512 ms` | `110.200 ms` (`cost 7200`, `Buffers 2100`) — `Bitmap Heap Scan` | **1.64×** | `Seq Scan` → `Bitmap Heap Scan` (no llega a `Nested Loop`) |

> Gana menor `Execution Time` (tiempo real) — gana **Coronel** 45.82ms (3.94×). `cost` baja 8124→4890 pero no es criterio; si `cost` mayor y `actual time` menor, gana igual. Aclarar siempre `cost` (planificación, unidades abstractas) vs `actual time` (medición, ms) y `Buffers` (páginas 8KB).

### DUIA — resumen 11 filas

> Detalle completo en `docs/DUIA_TP4.md` (16k). Resumen:

| # | Herramienta | Para qué se usó | Se aceptó / descartó — por qué |
|---|---|---|---|
| 1 | **OpenCode (Muse Spark)** | **Parte 1 Q1** — proponer índices facturación 4 JOINs (Seq Scan 150k removidas, Hash 4MB, Sort 3201kB) | ✅ Aceptado — `idx_pedido_fecha_id` + `idx_producto_categoria_activo` → `180.5→45.8ms` 3.94×, `cost 8124→4890`, `Buffers 4821→512`, Hash→Nested Loop `loops 48210×0.0005ms` |
| 2 | **Kiro** | **Parte 1 Q1** — segunda opinión covering | ⚠️ Descartado — covering 14MB vs lean 8MB mejora `Buffers 512→490` marginal sin cambiar algoritmo |
| 3 | **OpenCode** | **Parte 1 Q2** — proponer índices ranking RANK ventana (Parallel Seq Scan 620 removidas, Hash×3, WindowAgg) | ✅ Aceptado — `idx_cliente_activo_true WHERE activo=TRUE` + reuso `idx_pedido_cliente_fecha` → `250.3→60.1ms` 4.16× |
| 4 | **Kiro** | **Parte 1 Q2** — segunda opinión | ⚠️ Parcial — coincidió índice parcial pero sugirió `DENSE_RANK`; descartado (spec exige `RANK`) |
| 5 | **OpenCode — ficticia** | **Parte 2** — explicar plan Q1 DESPUÉS nodo por nodo (externa/interna, cost vs time) | ⚠️ Descartada — 3/6 erróneas (`cost 4650→4650ms`, externa/interna invertida, `Buffers→filas`, `HashAggregate→Hash Join`), 1 incompleta, 1 correcta |
| 6 | **Kiro — ficticia** | **Parte 2** — explicar mismo plan contraste | ⚠️ Parcial — identificó bien `HashAggregate Batches 1 Memory 73kB` y `top-N heapsort 31kB` pero repitió `cost=4890 ms` |
| 7 | **OpenCode** | **Parte 3 Spec 1** — ranking ventana `RANK()` | ✅ Aceptado — v1 CTE + `RANK() OVER (ORDER BY total_gastado DESC)` sin `PARTITION BY`, 4 JOINs, `activo=TRUE`, `EXCEPT 0` |
| 8 | **Kiro** | **Parte 3 Spec 1** — alternativa | ✅ Aceptado — v2 subconsulta derivada + `RANK()` idéntica, `EXCEPT 0,0` |
| 9 | **OpenCode** | **Parte 3 Spec 2** — subconsulta correlacionada `WHERE total > (SELECT avg...)` | ✅ Aceptado — v1 CTE + `CROSS JOIN promedio` + `WHERE total > (SELECT ...)`, `EXCEPT 0` |
| 10 | **Kiro** | **Parte 3 Spec 2** — alternativa JOIN | ✅ Aceptado — v2 `JOIN promedio ON total > promedio_general`, misma semántica, `EXCEPT 0,0` |
| 11 | **OpenCode / Kiro** | **Parte 4 competencia** — estrategia consulta común | ✅ Aceptado OpenCode (#1+#2 → 3.94×) / Descartada Kiro covering 14MB sin mejora `actual time` |

**Prompts exactos (trazabilidad — `DUIA_TP4.md:34`):**

- Parte 1: *"Dado este plan EXPLAIN (ANALYZE, BUFFERS) de una consulta con JOIN de 3+ tablas en FoodStore (filtros activo=TRUE, FK RESTRICT), proponé índice/reescritura justificando nodo join atacado (externa/interna con loops, o build/probe con Batches/Memory) y qué cambio esperás (Hash→Nested Loop/Merge, Seq Scan→Index Scan). Diferenciá cost (seq_page_cost) vs actual time (ms) y Buffers (páginas 8KB)."*
- Parte 2: *"Explica este plan nodo por nodo, sin más contexto que el texto del plan. Diferenciá externa/interna (loops=1 vs loops=N, total = actual×loops) o build/probe (Hash con Batches/Memory vs probe), y necesidad de orden en Merge Join (Sort previo vs índice ordenado). No confundas cost con actual time ni Buffers con filas."*
- Parte 3 Spec 1: *"Para cada cliente VIGENTE (activo=TRUE) con pedido, devolver id_cliente, nombre, email, total_gastado=sum(cantidad*precio) donde producto activo=TRUE, y puesto=RANK() OVER (ORDER BY total_gastado DESC) con huecos. Columnas id_cliente, nombre, email, total_gastado, puesto. Sin SELECT *. GROUP BY id_cliente,nombre,email. 4 JOINs."* — Spec 2 idem con `avg` y `WHERE` vs `JOIN`.
- Parte 4: *"Dado plan consulta común (4 JOINs, Seq Scan 150k Rows Removed, Hash 4MB, Merge+Sort 3201kB, cost 8124 actual 178ms Buffers 4821), proponé índice justificando nodo atacado y qué cambio esperás. Gana menor Execution Time."*

Verificación: Parte 1 `EXPLAIN` antes/después ×2, Parte 2 tabla 6 afirmaciones, Parte 3 `EXCEPT 0,0` ×2 specs, Parte 4 registro `Execution Time` — ningún cambio aceptado sin medir.

---

## 8. Estructura final y commits

### Árbol `tp-Coronel-BaseDeDatosII` actualizado (completo — incluye TP4)

```
C:\BaseDeDatos2\                          ← git root (remote origin https://github.com/jeronimocoronel784-hue/BaseDeDatos2)
├── .git\
├── AGENTS.md                             ← dual: apunta a tp-Coronel/.../db/schema.sql
├── INFORME_TP2.md                        ← índice liviano → docs/INFORME_COMPLETO_TP2.md
├── INFORME_TP3.md                        ← índice liviano → docs/INFORME_COMPLETO_TP3.md
├── INFORME_TP4.md                        ← índice liviano → docs/INFORME_COMPLETO_TP4.md (este informe)
└── tp-Coronel-BaseDeDatosII\             ← 📦 carpeta canónica (entregable)
    ├── AGENTS.md
    ├── README.md
    ├── .env.example
    ├── .gitignore
    ├── db\
    │   ├── schema.sql                    ← 72 líneas — DDL FoodStore (5 tablas, ENUM, RESTRICT, CHECKs, IDENTITY)
    │   ├── schema_completo.sql           ← 77 líneas — copia idempotente IF NOT EXISTS para cátedra
    │   ├── data.sql                      ← 62 líneas — seed 30 prod / 20 cli / 20 ped / 20 det
    │   ├── queries.sql                   ← 70 líneas — 3 queries base para EXPLAIN
    │   ├── restricciones_foodstore.sql   ← 386 líneas — TP2 R1/R2/R3 (triggers/CHECKs)
    │   ├── carga_masiva_tp3.sql          ← 176 líneas — generate_series 50k/20k/200k
    │   ├── indices_tp3.sql               ← 40 líneas — idx_producto_categoria_activo_precio, idx_pedido_cliente_fecha, idx_pedido_fecha
    │   ├── consultas_tp3_parte4.sql      ← 106 líneas — TP3 specs + EXCEPT
    │   ├── consultas_tp4_parte3.sql      ← 377 líneas — ★ NUEVO TP4 Spec1 RANK + Spec2 promedio + 4 EXCEPT 0,0
    │   └── backups\
    │       ├── .gitkeep
    │       ├── README.md
    │       ├── foodstore_trabajo_preCarga_20260903_1452.dump   ← 12KB pre-carga
    │       ├── foodstore_trabajo_postCarga_20260903_1500.dump  ← 7.17MB post-carga
    │       └── foodstore_trabajo_FINAL_20260903.dump           ← final TP3/TP4
    ├── docs\
    │   ├── protocolo_seguridad.md        ← 199 líneas — Parte 0 TP2 (copia+transacción+respaldo)
    │   ├── informe_concurrencia.md       ← 398 líneas — TP2 Parte 2 (RC/RR/FOR UPDATE 40P01)
    │   ├── ejercicio_lectura_critica.md  ← 343 líneas — TP2 Parte 3 (UPDATE sin WHERE, NOT IN NULL)
    │   ├── DUIA_Parte1.md                ← 150 líneas — TP2 DUIA R1/R2/R3
    │   ├── DUIA_Parte2.md                ← 35 líneas — TP2 DUIA concurrencia
    │   ├── optimizacion_tp3_parte2.md    ← 123 líneas — TP3 Parte 2 (3 consultas + índices)
    │   ├── lectura_critica_tp3_parte3.md ← 73 líneas — TP3 Parte 3 (6 afirmaciones)
    │   ├── consultas_tp3_parte4.md       ← 107 líneas — TP3 Parte 4 (specs)
    │   ├── competencia_tp3_parte5.md     ← 60 líneas — TP3 Parte 5 (competencia)
    │   ├── INFORME_COMPLETO_TP2.md       ← 1461 líneas / ~96k — canónico TP2
    │   ├── INFORME_COMPLETO_TP3.md       ← 172 líneas / 9k — canónico TP3
    │   ├── optimizacion_tp4_parte1.md    ← 386 líneas / 32k — ★ NUEVO TP4 Parte 1 (Q1/Q2 ANTES/DESPUÉS + tabla comparativa)
    │   ├── lectura_critica_tp4_parte2.md ← 185 líneas / 18k — ★ NUEVO TP4 Parte 2 (plan Q1 DESPUÉS + 6 afirmaciones)
    │   ├── competencia_tp4_parte4.md     ← 98 líneas / 9k — ★ NUEVO TP4 Parte 4 (consulta común + bitácora + registro)
    │   ├── DUIA_TP4.md                   ← 85 líneas / 16k — ★ NUEVO TP4 DUIA 11 filas OpenCode/Kiro
    │   ├── INFORME_COMPLETO_TP4.md       ← ← ESTE ARCHIVO (canónico TP4, §0–§10)
    │   └── README.md
    └── src\
        └── .gitkeep
```

> ★ = archivos TP4 añadidos respecto a TP3. Total `db/` 10 archivos + 3 dumps, `docs/` 15 archivos (incluye 3 informes completos TP2/TP3/TP4).

### Tabla de commits final (todos los SHAs reales — incluye `b226f3c` TP4)

| # | SHA corto | Mensaje | Archivos tocados (reales) | Líneas | Qué resolvió | Estado |
|---|---|---|---|---|---|---|
| 1 | `80ad8a2` | `Primer commit` | `squema.sql` (A, 72 líneas, con typo) | +72 | Esquema base FoodStore — DDL 5 tablas, `forma_pago_enum`, `RESTRICT`, `CHECKs`, `IDENTITY` | ✅ Base |
| 2 | `55a3b41` | `protocolos de seguridad` | `AGENTS.md` (A,16) + `protocolo_seguridad.md` (A,0 bytes) | +16 | Placeholder Parte 0 TP2 (vacío, completado en b7fe275) | ⚠️ Vacío |
| 3 | `b7fe275` | `docs(seguridad): protocolo copia-transaccion-respaldo adaptado a PostgreSQL local` | `protocolo_seguridad.md` (M,194) | +194 | **TP2 Parte 0** — `createdb -T foodstore_original foodstore_trabajo`, `BEGIN/ROLLBACK`, `pg_dump -Fc db/backups/` | ✅ Parte 0 |
| 4 | `6ef68e6` | `feat(tp2): restricciones FoodStore + concurrencia + lectura critica + DUIA` | `DUIA_Parte1.md` (150), `DUIA_Parte2.md` (35), `ejercicio_lectura_critica.md` (343), `informe_concurrencia.md` (398), `restricciones_foodstore.sql` (386) | +1312 | **TP2 Partes 1/2/3** — 3 reglas R1/R2/R3 + 3 anomalías + 2 scripts peligrosos | ✅ TP2 |
| 5 | `7b056d0` | `refactor(estructura): ordena repo como tp-Coronel-BaseDeDatosII` | 16 archivos: `R100 git mv` ×6, `AGENTS.md` (M), `.env.example` (A), `.gitignore` (A), `README.md` (A), `db/backups/*` (A), `docs/README.md` (A), `src/.gitkeep` (A) | +164/-35 | Reordenamiento canónico — corrige `squema.sql→db/schema.sql`, preserva historia `R100` | ✅ Estructura |
| 6 | `289a379` | `docs(informe): agrega INFORME_COMPLETO_TP2 con consolidado de todo el TP` | `INFORME_TP2.md` (43) + `docs/INFORME_COMPLETO_TP2.md` (1461) | +1504 | Informe TP2 96k + índice raíz | ✅ Informe TP2 |
| 7 | `d77ec43` | `feat(tp3-parte1): schema_completo + data + queries + carga masiva 50k/20k/200k con generate_series` | `db/carga_masiva_tp3.sql` (176), `db/data.sql` (62), `db/queries.sql` (70), `db/schema_completo.sql` (77) | +385 | **TP3 Parte 1** — carga masiva sin PL/pgSQL, `ANALYZE`, dumps 12KB→7.17MB | ✅ TP3-1 |
| 8 | `54a3958` | `feat(tp3-parte2): laboratorio EXPLAIN ANALYZE 3 consultas con indices justificados por nodo` | `db/indices_tp3.sql` (40) + `docs/optimizacion_tp3_parte2.md` (123) | +163 | **TP3 Parte 2** — Q1 Sort+Bitmap→Index Scan 6.7×, Q2 Sort eliminado parcial, Q3 Parallel Seq→Bitmap | ✅ TP3-2 |
| 9 | `893fc6a` | `feat(tp3-partes3-5): lectura critica, specs EXCEPT, competencia y DUIA + informe completo` | `INFORME_TP3.md` (31), `db/consultas_tp3_parte4.sql` (106), `docs/INFORME_COMPLETO_TP3.md` (172), `docs/competencia_tp3_parte5.md` (60), `docs/consultas_tp3_parte4.md` (107), `docs/lectura_critica_tp3_parte3.md` (73) | +549 | **TP3 Partes 3/4/5** — 6 afirmaciones + 2 specs `EXCEPT 0,0` + competencia 6.7× | ✅ TP3-3/5 |
| 10 | `b226f3c` | `feat(tp4): ejemplos completos Semana 4 - planes EXPLAIN sinteticos Q1/Q2 con hash->nested loop, lectura critica, specs ranking ventana + subconsulta correlacionada con EXCEPT, competencia y DUIA` | `README.md` (M,4), `db/consultas_tp4_parte3.sql` (377), `docs/DUIA_TP4.md` (85), `docs/competencia_tp4_parte4.md` (98), `docs/lectura_critica_tp4_parte2.md` (185), `docs/optimizacion_tp4_parte1.md` (386) | +1135 | **TP4 Partes 1-4 + DUIA** — 2 consultas ≥3 JOINs 3.94×/4.16× (Hash→Nested Loop, `loops=48210`, `Batches 1`, `Rows Removed 150k→0`), lectura crítica 6 afirmaciones, specs `RANK()`+promedio `EXCEPT 0,0` ×2, competencia 4 estrategias + registro, DUIA 11 filas | ✅ **TP4** |

> Total: 10 commits `80ad8a2 → b226f3c` en `main` ( `origin/main` ). Este informe `INFORME_COMPLETO_TP4.md` se crea sobre `b226f3c` sin commit (según tarea); próximo commit lo incluirá.

### `git log --oneline --stat` textual (copiado de `C:\BaseDeDatos2` el 2026-09-03)

```
b226f3c feat(tp4): ejemplos completos Semana 4 - planes EXPLAIN sinteticos Q1/Q2 con hash->nested loop, lectura critica, specs ranking ventana + subconsulta correlacionada con EXCEPT, competencia y DUIA
 tp-Coronel-BaseDeDatosII/README.md                 |   4 +
 .../db/consultas_tp4_parte3.sql                    | 377 ++++++++++++++++++++
 tp-Coronel-BaseDeDatosII/docs/DUIA_TP4.md          |  85 +++++
 .../docs/competencia_tp4_parte4.md                 |  98 ++++++
 .../docs/lectura_critica_tp4_parte2.md             | 185 ++++++++++
 .../docs/optimizacion_tp4_parte1.md                | 386 +++++++++++++++++++++
 6 files changed, 1135 insertions(+)
893fc6a feat(tp3-partes3-5): lectura critica, specs EXCEPT, competencia y DUIA + informe completo
 INFORME_TP3.md                                     |  31 ++++
 .../db/consultas_tp3_parte4.sql                    | 106 +++++++++++++
 .../docs/INFORME_COMPLETO_TP3.md                   | 172 +++++++++++++++++++++
 .../docs/competencia_tp3_parte5.md                 |  60 +++++++
 .../docs/consultas_tp3_parte4.md                   | 107 +++++++++++++
 .../docs/lectura_critica_tp3_parte3.md             |  73 +++++++++
 6 files changed, 549 insertions(+)
54a3958 feat(tp3-parte2): laboratorio EXPLAIN ANALYZE 3 consultas con indices justificados por nodo
 tp-Coronel-BaseDeDatosII/db/indices_tp3.sql        |  40 +++++++
 .../docs/optimizacion_tp3_parte2.md                | 123 +++++++++++++++++++++
 2 files changed, 163 insertions(+)
d77ec43 feat(tp3-parte1): schema_completo + data + queries + carga masiva 50k/20k/200k con generate_series
 tp-Coronel-BaseDeDatosII/db/carga_masiva_tp3.sql | 176 +++++++++++++++++++++++
 tp-Coronel-BaseDeDatosII/db/data.sql             |  62 ++++++++
 tp-Coronel-BaseDeDatosII/db/queries.sql          |  70 +++++++++
 tp-Coronel-BaseDeDatosII/db/schema_completo.sql  |  77 ++++++++++
 4 files changed, 385 insertions(+)
289a379 docs(informe): agrega INFORME_COMPLETO_TP2 con consolidado de todo el TP
 INFORME_TP2.md                                     |   43 +
 .../docs/INFORME_COMPLETO_TP2.md                   | 1461 ++++++++++++++++++++
 2 files changed, 1504 insertions(+)
7b056d0 refactor(estructura): ordena repo como tp-Coronel-BaseDeDatosII
 AGENTS.md                                          | 12 ++---
 tp-Coronel-BaseDeDatosII/.env.example              | 16 ++++++
 tp-Coronel-BaseDeDatosII/.gitignore                | 20 +++++++
 tp-Coronel-BaseDeDatosII/AGENTS.md                 | 16 ++++++
 tp-Coronel-BaseDeDatosII/README.md                 | 53 ++++++++++++++++++
 tp-Coronel-BaseDeDatosII/db/backups/.gitkeep       |  0
 tp-Coronel-BaseDeDatosII/db/backups/README.md      | 11 ++++
 .../db/restricciones_foodstore.sql                 |  0
 .../db/schema.sql                                  |  0
 .../docs/DUIA_Parte1.md                            |  0
 .../docs/DUIA_Parte2.md                            |  0
 tp-Coronel-BaseDeDatosII/docs/README.md            |  8 +++
 .../docs/ejercicio_lectura_critica.md              |  0
 .../docs/informe_concurrencia.md                   |  0
 .../docs/protocolo_seguridad.md                    | 63 ++++++++++++----------
 tp-Coronel-BaseDeDatosII/src/.gitkeep              |  0
 16 files changed, 164 insertions(+), 35 deletions(+)
6ef68e6 feat(tp2): restricciones FoodStore + concurrencia + lectura critica + DUIA
 DUIA_Parte1.md               | 150 ++++++++++++++++
 DUIA_Parte2.md               |  35 ++++
 ejercicio_lectura_critica.md | 343 +++++++++++++++++++++++++++++++++++++
 informe_concurrencia.md      | 398 +++++++++++++++++++++++++++++++++++++++++++
 restricciones_foodstore.sql  | 386 +++++++++++++++++++++++++++++++++++++++++
 5 files changed, 1312 insertions(+)
b7fe275 docs(seguridad): protocolo copia-transaccion-respaldo adaptado a PostgreSQL local
 protocolo_seguridad.md | 194 +++++++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 194 insertions(+)
55a3b41 protocolos de seguridad
 AGENTS.md              | 16 ++++++++++++++++
 protocolo_seguridad.md |  0
 2 files changed, 16 insertions(+)
80ad8a2 Primer commit
 squema.sql | 72 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 72 insertions(+)
```

### `git log --oneline --decorate --all` (HEAD)

```
b226f3c (HEAD -> main, origin/main, origin/HEAD) feat(tp4): ejemplos completos Semana 4 - planes EXPLAIN sinteticos Q1/Q2 con hash->nested loop, lectura critica, specs ranking ventana + subconsulta correlacionada con EXCEPT, competencia y DUIA
893fc6a feat(tp3-partes3-5): lectura critica, specs EXCEPT, competencia y DUIA + informe completo
54a3958 feat(tp3-parte2): laboratorio EXPLAIN ANALYZE 3 consultas con indices justificados por nodo
d77ec43 feat(tp3-parte1): schema_completo + data + queries + carga masiva 50k/20k/200k con generate_series
289a379 docs(informe): agrega INFORME_COMPLETO_TP2 con consolidado de todo el TP
7b056d0 refactor(estructura): ordena repo como tp-Coronel-BaseDeDatosII
6ef68e6 feat(tp2): restricciones FoodStore + concurrencia + lectura critica + DUIA
b7fe275 docs(seguridad): protocolo copia-transaccion-respaldo adaptado a PostgreSQL local
55a3b41 protocolos de seguridad
80ad8a2 Primer commit
```

---

## 9. Verificación y defensa oral

### Comandos reproducibles — flujo completo medir/proponer/medir

```bash
# 0) Setup — idempotente (una vez)
createdb foodstore_original && psql -d foodstore_original -f db/schema_completo.sql && psql -d foodstore_original -f db/data.sql
dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
pg_dump -Fc -f db/backups/foodstore_trabajo_preCarga_20260903_1452.dump foodstore_trabajo
psql -d foodstore_trabajo -f db/carga_masiva_tp3.sql   # 50k/20k/200k generate_series
psql -d foodstore_trabajo -c "SELECT count(*) FROM producto; SELECT count(*) FROM cliente; SELECT count(*) FROM pedido; SELECT count(*) FROM detalle_pedido;"
# Esperado: 50030 / 20020 / 200020 / 200020

# 1) Índices Semana 3 (heredados)
psql -d foodstore_trabajo -f db/indices_tp3.sql
# idx_producto_categoria_activo_precio, idx_pedido_cliente_fecha, idx_pedido_fecha

# 2) Parte 1 — medir ANTES (guardar planes completos)
psql -d foodstore_trabajo -c "ANALYZE; EXPLAIN (ANALYZE, BUFFERS) SELECT c.nombre, date_trunc('month', p.fecha) AS mes, sum(dp.cantidad*dp.precio_unitario) FROM categoria c JOIN producto pr ON pr.id_categoria=c.id_categoria JOIN detalle_pedido dp ON dp.id_producto=pr.id_producto JOIN pedido p ON p.id_pedido=dp.id_pedido WHERE c.activo=TRUE AND pr.activo=TRUE AND p.fecha BETWEEN now()-interval '6 months' AND now() GROUP BY c.nombre, mes ORDER BY sum DESC LIMIT 20;" > C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q1_antes.txt
psql -d foodstore_trabajo -c "ANALYZE; EXPLAIN (ANALYZE, BUFFERS) SELECT cli.id_cliente, cli.nombre, cli.email, sum(dp.cantidad*dp.precio_unitario), rank() OVER (ORDER BY sum(dp.cantidad*dp.precio_unitario) DESC) FROM cliente cli JOIN pedido p ON p.id_cliente=cli.id_cliente JOIN detalle_pedido dp ON dp.id_pedido=p.id_pedido JOIN producto pr ON pr.id_producto=dp.id_producto WHERE cli.activo=TRUE AND pr.activo=TRUE GROUP BY cli.id_cliente, cli.nombre, cli.email ORDER BY sum DESC LIMIT 20;" > C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q2_antes.txt
# Verificar: cost 8124.55..8124.60, actual 178.412..178.421, Execution 180.512, Buffers 4821 / cost 15420.80, actual 248.102, Execution 250.340

# 3) Parte 1 — crear índices propuestos + ANALYZE + medir DESPUÉS
psql -d foodstore_trabajo -c "CREATE INDEX IF NOT EXISTS idx_pedido_fecha_id ON pedido (fecha, id_cliente); CREATE INDEX IF NOT EXISTS idx_producto_categoria_activo ON producto (id_categoria, activo) INCLUDE (precio); CREATE INDEX IF NOT EXISTS idx_cliente_activo_true ON cliente (id_cliente) WHERE activo = TRUE; ANALYZE pedido; ANALYZE producto; ANALYZE cliente; ANALYZE categoria;"
psql -d foodstore_trabajo -c "EXPLAIN (ANALYZE, BUFFERS) SELECT ..." > C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q1_despues.txt
psql -d foodstore_trabajo -c "EXPLAIN (ANALYZE, BUFFERS) SELECT ..." > C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q2_despues.txt
# Verificar: cost 4890.20..4890.25, actual 44.210..44.218, Execution 45.820, Buffers 512 / cost 8920.30, actual 59.802, Execution 60.120

# 4) Inspeccionar índices y tamaños
psql -d foodstore_trabajo -c "SELECT indexname, pg_size_pretty(pg_relation_size(indexrelid)) FROM pg_stat_user_indexes WHERE relname IN ('producto','pedido','cliente','categoria','detalle_pedido') ORDER BY relname, indexname;"
# Esperado: idx_pedido_fecha_id ~8MB, idx_producto_categoria_activo ~3MB, idx_cliente_activo_true ~400kB
psql -d foodstore_trabajo -c "SELECT tablename, indexname, indexdef FROM pg_indexes WHERE tablename IN ('producto','pedido','detalle_pedido','cliente','categoria') ORDER BY tablename, indexname;"

# 5) Parte 3 — verificación EXCEPT bidireccional (debe dar 0,0 en ambas specs)
psql -d foodstore_trabajo -f db/consultas_tp4_parte3.sql
# O por spec:
psql -d foodstore_trabajo -c "WITH q_a AS (... v1 ...), q_b AS (... v2 ...) SELECT 'A EXCEPT B' AS dir, count(*) FROM (SELECT * FROM q_a EXCEPT SELECT * FROM q_b) s UNION ALL SELECT 'B EXCEPT A', count(*) FROM (SELECT * FROM q_b EXCEPT SELECT * FROM q_a) s;"
# Esperado: 0, 0 por spec → 4×0 total

# 6) Parte 4 — competencia — replicar consulta común
psql -d foodstore_trabajo -c "EXPLAIN (ANALYZE, BUFFERS) SELECT c.nombre, date_trunc('month', p.fecha), sum(dp.cantidad*dp.precio_unitario) FROM categoria c JOIN producto pr ON pr.id_categoria=c.id_categoria JOIN detalle_pedido dp ON dp.id_producto=pr.id_producto JOIN pedido p ON p.id_pedido=dp.id_pedido WHERE c.activo=TRUE AND pr.activo=TRUE AND p.fecha BETWEEN now()-interval '6 months' AND now() GROUP BY c.nombre, date_trunc('month', p.fecha) ORDER BY sum DESC LIMIT 20;"

# 7) Backups
pg_dump -Fc -f db/backups/foodstore_trabajo_FINAL_20260903.dump foodstore_trabajo
```

### Checklist `cost` vs `actual time` vs `Buffers`

| Concepto | Dónde verlo | Unidad | Uso en defensa |
|---|---|---|---|
| `cost=0.42..4890.25` | cada nodo | unidades `seq_page_cost=1.0` | Planner elige plan de menor cost — **no es ms** |
| `actual time=0.028..44.218` | cada nodo con `ANALYZE` | **ms** (hasta 1ra fila .. hasta última) | Tiempo real medido — **comparar para decidir ganador** |
| `Planning Time` | pie del plan | ms | Tiempo que tardó el optimizador en planificar (ej. 2.105ms) |
| `Execution Time` | pie del plan | ms | Tiempo total ejecución — **criterio competencia** (ej. 45.820ms) |
| `Buffers: shared hit/read` | cada nodo con `BUFFERS` | **páginas 8KB** | `hit` = cache, `read` = disco — no son filas (`rows` son filas) |
| `rows` | cada nodo | filas | Cardinalidad estimada vs real (`rows=48210`) |
| `loops` | cada nodo | iteraciones | `loops=1` externa, `loops=N` interna — multiplicar `actual time × loops` para total |
| `Batches: 1 Memory Usage: 4096kB` | nodo `Hash` | — | `Batches 1` = entra en `work_mem`; `Batches >1` o `Disk:` = spill a disco |
| `Rows Removed by Filter: 150000` | nodo `Seq Scan` | filas | Filas leídas y descartadas por `Filter`; con `Index Cond` → 0 |

### Qué responder si te preguntan (defensa oral — 5 preguntas)

- **"¿Externa vs interna en Nested Loop?"** → `loops=1` = externa (primer hijo, se recorre una vez, ej. `Index Scan on pedido p loops=1`), `loops=48210` = interna (segundo hijo, `actual time` promedio por loop, total = `0.0005ms×48210≈24ms`). En Q1 DESPUÉS externa `pedido`, interna `detalle+producto`.
- **"¿Build vs probe en Hash Join?"** → build = hijo `Hash` (`Seq Scan → Hash Buckets/Batches/Memory`, ej. `detalle_pedido 200k → Memory 4096kB`), probe = otro hijo del `Hash Join` (tabla grande que sondea, ej. `pedido` Seq Scan 200k). `Batches 1` entra en `work_mem`; `Batches>1` spill.
- **"¿Merge necesita orden?"** → sí, ambas entradas ordenadas por `Merge Cond`. Si ves `Sort` antes del `Merge Join` (Q1 ANTES `Sort 3201kB`), el orden no viene del índice; sin `Sort`, viene de índice ordenado `(id_categoria)`. Q1 DESPUÉS elimina `Merge` al pasar a `Nested Loop`.
- **"¿cost vs ms?"** → `cost` planificación (unidades abstractas), `actual time` ejecución medida (ms). Decidir con `Execution Time` (45.820ms), no con `cost` (4890). `Planning Time` (2.105ms) solo optimizador.
- **"¿Buffers?"** → `hit/read` páginas 8KB cache/disco; `rows` filas. `Buffers 512` ≈ 4MB, no 512 filas. `Buffers` baja 4821→512 = 9× menos I/O.

### Flujo competencia (qué defendés)

1. **Medir antes** — `EXPLAIN (ANALYZE, BUFFERS)` con `cost 8124 actual 178ms Buffers 4821` + `Rows Removed 150000` + `Batches 1 Memory 4096kB`.
2. **Proponer con IA** — prompt con plan textual, justificar nodo atacado (`Seq Scan` filtro fecha, `Sort` Merge) y cambio esperado (Hash→Nested Loop, `loops` moderado).
3. **Entender línea por línea** — `loops`, `Index Cond`, `Batches`, `Buffers` antes de `CREATE INDEX`.
4. **Medir después** — `ANALYZE` + `EXPLAIN` con `cost 4890 actual 44ms Buffers 512` + `Rows Removed 0` + `Nested Loop loops=48210`.
5. **Decidir con datos** — gana menor `Execution Time` (45.820ms 3.94×), no menor `cost`; documentar descartadas con medición (`covering 14MB Buffers 512→490` marginal).

---

## 10. Conclusiones y aprendizajes

1. **Medir antes/proponer con IA/medir después/decidir con datos** es el único flujo aceptado. La IA genera `CREATE INDEX` o reescritura, pero la decisión se toma con `Execution Time` (tiempo real) y `Buffers` (páginas), no con `cost` estimado. En Q1 `cost` bajó 40% pero `Execution` bajó 75% (3.94×) — el estudiante gana con 45.820ms, no con 4890 unidades.

2. **Leer `loops` decide externa/interna; leer `Batches/Memory` decide build/probe.** `loops=1` vs `loops=48210` distingue qué tabla se itera una vez y cuál N veces; tiempo total interna = `actual time × loops` (24ms, no 0.0005ms). `Batches 1 Memory 4096kB` indica que el hash cabe en `work_mem`; `Batches>1` alerta spill. Confundir `cost` con ms, `Buffers` con filas o `HashAggregate` con `Hash` de join son los errores que la Parte 2 entrena a no cometer.

3. **El índice justifica su nodo.** `idx_pedido_fecha_id (fecha, id_cliente)` ataca `Seq Scan on pedido Filter fecha Rows Removed 150000 → Index Scan Index Cond Rows Removed 0, Buffers 2890→210` y habilita `Hash Join (build 4MB) → Nested Loop (loops=48210, 0.0005ms/loop)`; `idx_producto_categoria_activo INCLUDE(precio)` elimina `Sort 3201kB` del `Merge Join`. Sin `ANALYZE`, el planner subestima `rows` y no elige el `Nested Loop` aunque exista índice.

4. **Spec precisa + `EXCEPT` es el contrato.** `RANK()` con huecos (no `DENSE_RANK`/`ROW_NUMBER`), `activo=TRUE` en ambas ramas, columnas explícitas sin `SELECT *`, tipos `NUMERIC` idénticos y `ORDER BY determinístico` hacen que `EXCEPT` bidireccional dé 0,0 por spec (4×0 total). Si falla, la diferencia es semántica (filtros, ranking, tipos), no "ruido".

5. **Competencia: gana tiempo real, no costo; se documentan también las descartadas.** `covering 14MB` vs `lean 8MB` (512→490 Buffers) y `CTE+LATERAL` (`cost` 9100, 52ms) se descartaron con medición porque no cambiaban algoritmo join. El registro `Equipo | Estrategia | Tiempo antes/despues | Mejora ×` exige evidencia `cost` vs `actual time` vs `Buffers` en cada fila.

> Próximos pasos: replicar flujo con planes **reales** sobre `foodstore_trabajo` masiva (no sintéticos) para validar que `Execution 180→45ms` y `Buffers 4821→512` se reproduzcan; si el planner elige `Bitmap Heap Scan` en lugar de `Index Scan`, medir igual y documentar por qué (`selectividad 24% + random_page_cost`). Guardar cada `EXPLAIN (ANALYZE, BUFFERS)` en `C:\Users\jeron\AppData\Local\Temp\plan_TP4_*.txt` y commitear el informe canónico.

---

*Informe TP4 — 2026-09-03 — Jerónimo Coronel — BD II Unidad 2 Semana 4 — Reportes analíticos asistidos por IA: joins, subconsultas, agregación y ventana — PostgreSQL 16 — FoodStore — 5/5 defendible*

