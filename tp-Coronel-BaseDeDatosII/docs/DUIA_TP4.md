# DUIA — Declaración de Uso de IA — TP4 — FoodStore (EJEMPLO SINTÉTICO VEROSÍMIL)

> **UTN — Tecnicatura Universitaria en Programación — Base de Datos II**
> **Semana 4 — Partes 1 a 4 — Autor:** Jerónimo Coronel
> **Fecha:** 2026-09-03 — **EJEMPLO SINTÉTICO** para practicar flujo completo sin base masiva real
> **Esquema:** FoodStore (`db/schema.sql`) — PostgreSQL 16.8 — tablas: `categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido` — soft delete `activo BOOLEAN` — FK `ON DELETE RESTRICT`
> **Índices base Semana 3:** `idx_producto_categoria_activo_precio`, `idx_pedido_cliente_fecha`, `idx_pedido_fecha`
> **Índices Parte 1 (ejemplo sintético):** `idx_pedido_fecha_id ON pedido(fecha,id_cliente)`, `idx_producto_categoria_activo ON producto(id_categoria,activo) INCLUDE(precio)`, `idx_cliente_activo_true ON cliente(id_cliente) WHERE activo=TRUE`
> **Planes:** sintéticos verosímiles en `docs/optimizacion_tp4_parte1.md` (Q1/Q2 antes/después) y `docs/lectura_critica_tp4_parte2.md` (Q1 DESPUÉS)

---

## Tabla DUIA TP4 — resumen por herramienta (ejemplo completo)

| Herramienta | Para qué se usó | Prompt / spec resumen (textual) | Se aceptó / se descartó — por qué (con medición) |
|---|---|---|---|
| **OpenCode (Muse Spark)** | **Parte 1 Q1** — proponer índices para facturación categoría×mes (4 JOINs, filtro fecha 6 meses) | *"Dado este plan EXPLAIN (ANALYZE, BUFFERS) de Q1 (Seq Scan pedido con Filter fecha Rows Removed 150k, cost 0..3890 actual 48ms, Hash Join build detalle 4MB Batches 1, Hash Join build producto 2MB, Merge Join + Sort 3201kB, Execution 180ms), proponé un índice o reescritura justificando qué nodo join atacás (externa/interna o build/probe) y qué cambio de algoritmo esperás (Hash→Nested Loop/Merge). Incluí filtro activo=TRUE y diferencia cost vs actual time."* | ✅ **Aceptado** — propuso `idx_pedido_fecha_id (fecha,id_cliente)` + `idx_producto_categoria_activo (id_categoria,activo) INCLUDE(precio)`. Ataca `Seq Scan` con 150k removidas y `Sort` 3201kB. Medición: `cost 8124→4890` (−40%), `Execution 180.5ms→45.8ms` (**3.94×**), `Buffers 4821→512`, `Rows Removed 150k→0`, `Hash Join→Nested Loop` justificado (`loops 48210 × 0.0005ms`). |
| **Kiro** | **Parte 1 Q1** — segunda opinión / alternativa | *"Misma consulta Q1 y mismo plan que a OpenCode — proponé alternativa distinta (ej. covering INCLUDE total vs índice lean) y justificá nodo atacado y tamaño. Comparar con propuesta OpenCode."* | ⚠️ **Parcial / Descartado** — propuso covering `ON pedido(fecha) INCLUDE(id_cliente,forma_pago)` de 14MB con mejora marginal `Buffers 512→490` sin cambiar algoritmo. Se descartó por tamaño doble sin beneficio en `actual time`; se mantuvo índice lean 8MB. Documentado en `competencia_tp4_parte4.md` estrategia #3. |
| **OpenCode (Muse Spark)** | **Parte 1 Q2** — proponer índices para ranking clientes por gasto (ventana RANK, 4 JOINs) | *"Dado este plan EXPLAIN (ANALYZE, BUFFERS) de Q2 (Parallel Seq Scan cliente con Filter activo Rows Removed 620, Hash Join×3 build cliente 2MB/detalle 5MB/producto 2MB, HashAggregate, Sort quicksort 120kB, WindowAgg, Execution 250ms), proponé índice justificando nodo build/probe y qué cambio esperás."* | ✅ **Aceptado** — propuso `idx_cliente_activo_true WHERE activo=TRUE` + reuso `idx_pedido_cliente_fecha`. Ataca `Parallel Seq Scan` con 620 removidas. Medición: `cost 15420→8920` (−42%), `Execution 250.3ms→60.1ms` (**4.16×**), `Buffers 6210→1820`, `Rows Removed 620→0`, `Hash Join→Nested Loop (externa cliente loops=1, interna pedido loops=19400 × 0.0012ms)`. |
| **Kiro** | **Parte 1 Q2** — segunda opinión | *"Mismo plan Q2 — proponé alternativa y compará."* | ⚠️ **Parcial** — coincidió en índice parcial pero sugirió `DENSE_RANK` en lugar de `RANK`; se descartó porque la spec exige `RANK` con huecos (ver Parte 3). |
| **OpenCode (Muse Spark) — ficticia** | **Parte 2** — explicar plan Q1 DESPUÉS nodo por nodo | *"Explica este plan nodo por nodo, sin más contexto que el texto del plan. Diferenciá tabla externa/interna en Nested Loop (loops) y build/probe en Hash Join, y necesidad de orden en Merge Join. No confundas cost (estimado, unidades) con actual time (medido, ms) ni Buffers (páginas 8KB) con filas."* | ⚠️ **Parcial / Descartada** — 3/6 afirmaciones erróneas: confundió `cost 4650` con `4650ms` (af.1), invirtió externa/interna (`producto loops=48210` como externa, af.2), confundió `Buffers 512` con 512 filas (af.3), confundió `HashAggregate 73kB` con `Hash Join` (af.4); incompleta sobre `Sort`+`LIMIT` (af.5); 1 correcta (Index Scan evita 150k removidas, af.6). Corregido con evidencia `loops`, `cost` vs `actual time` en `lectura_critica_tp4_parte2.md` §3. |
| **Kiro — ficticia** | **Parte 2** — explicar mismo plan Q1 DESPUÉS (contraste) | *"Mismo plan Q1 DESPUÉS que a OpenCode — explica nodos join y costo vs tiempo real, señalá Batches/Memory y top-N heapsort."* | ⚠️ **Parcial** — identificó bien `HashAggregate Batches 1 Memory 73kB` (no join) y `top-N heapsort 31kB`, pero repitió error `cost=4890 ms`. Corregido idem. |
| **OpenCode (Muse Spark)** | **Parte 3 — Spec 1** ranking ventana | Spec 1 textual exacta: *"Para cada cliente VIGENTE (cliente.activo=TRUE) con al menos un pedido, devolver id_cliente, nombre, email, total_gastado=sum(cantidad*precio_unitario) donde producto.activo=TRUE, y puesto=RANK() OVER (ORDER BY total_gastado DESC) con huecos. Sin colapsar filas. Desempate id_cliente ASC. Columnas id_cliente, nombre, email, total_gastado, puesto. Sin SELECT *. GROUP BY id_cliente,nombre,email. Ventana sin PARTITION BY."* | ✅ **Aceptado** — generó **v1 CTE + RANK()** (`WITH gasto_por_cliente AS (...) SELECT ... rank() OVER (...) FROM gasto_por_cliente`) cumpliendo tablas (4 JOINs), filtros `activo=TRUE` en cliente y producto, `RANK()` (no `DENSE_RANK`/`ROW_NUMBER`), columnas explícitas, `GROUP BY` completo, `ORDER BY total_gastado DESC, id_cliente ASC`, sin `SELECT *`. Verificado `EXCEPT 0`. |
| **Kiro** | **Parte 3 — Spec 1** alternativa / verificación | *"Genera alternativa a la consulta de ranking (Spec 1) con subconsulta derivada en FROM en lugar de CTE, misma lógica, y verifica equivalencia con EXCEPT bidireccional."* | ✅ **Aceptado** — generó **v2 subconsulta derivada + RANK()** (`SELECT ... FROM (SELECT ... GROUP BY ...) AS sub`) semánticamente idéntica a v1. `EXCEPT` bidireccional `0, 0` (ver `consultas_tp4_parte3.sql` §Spec1 verificación). `EXPLAIN` muestra mismo plan (CTE inlineada). |
| **OpenCode (Muse Spark)** | **Parte 3 — Spec 2** subconsulta correlacionada | Spec 2 textual exacta: *"Clientes vigentes (cliente.activo=TRUE) cuyo total_gastado supera el promedio general de total_gastado por cliente vigente. total_gastado=sum(cantidad*precio_unitario) donde producto.activo=TRUE. promedio_general=avg(total_gastado) sobre clientes vigentes con pedido. Columnas id_cliente, nombre, email, total_gastado, promedio_general. Filtros activo=TRUE cliente y producto. Orden total_gastado DESC, id_cliente ASC. Sin SELECT *. v1 con subconsulta en WHERE: WHERE total > (SELECT avg(...))."* | ✅ **Aceptado** — generó **v1 con CTE + CROSS JOIN promedio + WHERE total > (SELECT avg...)** (subconsulta escalar en predicado, variante correlacionada válida). Filtros `activo=TRUE` en ambas CTEs, columnas explícitas, tipos `NUMERIC` coherentes, `ORDER BY` determinístico. `EXCEPT 0`. |
| **Kiro** | **Parte 3 — Spec 2** alternativa JOIN | *"Reescribe la misma consulta (Spec 2) con JOIN a CTE agregada (sin subconsulta en WHERE), usando JOIN ... ON total > promedio_general, y verifica con EXCEPT bidireccional."* | ✅ **Aceptado** — generó **v2 JOIN + CTE promedio** (`JOIN promedio prm ON g.total_gastado > prm.promedio_general`) misma semántica que v1, sin correlación en WHERE. `EXCEPT` bidireccional `0, 0`. Diferencia solo sintáctica. |
| **OpenCode / Kiro** | **Parte 4 — competencia** — estrategia consulta común | *"Dado este plan de la consulta común (4 JOINs, Seq Scan pedido 150k Rows Removed, Hash Join 4MB, Merge Join + Sort 3201kB, Execution 180ms), proponé índice/reescritura justificando nodo join atacado (externa/interna o build/probe) y qué cambio de algoritmo esperás. Gana menor Execution Time."* | ✅ **Aceptado (OpenCode)** — estrategia #1+#2 (dos índices) → `180.5ms → 45.8ms` (3.94×), `cost 8124→4890`, `Buffers 4821→512`. **Descartada (Kiro covering)** — 14MB vs 8MB sin mejora en `actual time`. Registro en `competencia_tp4_parte4.md`. |
| **Propia (manual)** | Verificación y decisión final | Revisión línea por línea de cada SQL/índice, `EXPLAIN (ANALYZE, BUFFERS)` antes/después, `EXCEPT` 0, `ANALYZE`, lectura `loops`/`Batches`/`Buffers` | ✅ **Aceptada** — ningún cambio se aplica "porque lo dijo la IA": se mide antes, se propone con IA, se mide después, se decide con datos (`Execution Time`). Todo SQL explicable oralmente. |

---

## Specs / prompts exactos dados a la IA (copiar textual para trazabilidad)

**Prompt Parte 1 (laboratorio joins — Q1/Q2):**
> "Dado este plan EXPLAIN (ANALYZE, BUFFERS) de una consulta con JOIN de 3+ tablas en FoodStore (tablas categoria/cliente/producto/pedido/detalle_pedido, filtros activo=TRUE, FK ON DELETE RESTRICT), proponé un índice o reescritura justificando qué nodo join atacás (externa/interna con loops, o build/probe con Batches/Memory) y qué cambio de algoritmo esperás (Hash Join → Nested Loop / Merge Join, Seq Scan → Index Scan). Incluí diferencia explícita cost (estimado, unidades seq_page_cost) vs actual time (medido, ms) y Buffers (páginas 8KB)."

**Prompt Parte 2 (lectura crítica — plan Q1 DESPUÉS):**
> "Explica este plan nodo por nodo, sin más contexto que el texto del plan. Diferenciá tabla externa/interna en Nested Loop (loops=1 vs loops=N, tiempo total = actual time × loops) o build/probe en Hash Join (Hash con Batches/Memory vs probe), y necesidad de orden en Merge Join (Sort previo vs índice ordenado). No confundas cost (planificación) con actual time (ejecución medida) ni Buffers hit/read (páginas 8KB) con filas (rows). Señalá Planning Time vs Execution Time."

**Spec Parte 3 — Ranking ventana (Spec 1) — ver `db/consultas_tp4_parte3.sql` header Spec 1:**
> "Para cada cliente VIGENTE (cliente.activo=TRUE) con al menos un pedido, devolver id_cliente, nombre, email, total_gastado=sum(dp.cantidad*dp.precio_unitario) donde producto.activo=TRUE, y puesto=RANK() OVER (ORDER BY total_gastado DESC) con huecos (RANK, no DENSE_RANK ni ROW_NUMBER). Sin colapsar filas. Desempate secundario por id_cliente ASC para orden determinístico. Columnas id_cliente, nombre, email, total_gastado, puesto. No usar SELECT *. GROUP BY id_cliente,nombre,email. 4 JOINs cliente→pedido→detalle_pedido→producto."

**Spec Parte 3 — Subconsulta correlacionada (Spec 2) — ver `db/consultas_tp4_parte3.sql` header Spec 2:**
> "Clientes vigentes (cliente.activo=TRUE) cuyo total_gastado=sum(cantidad*precio_unitario) donde producto.activo=TRUE supera el promedio general avg(total_gastado) por cliente vigente. Columnas id_cliente, nombre, email, total_gastado, promedio_general. Filtros activo=TRUE cliente y producto. Orden total_gastado DESC, id_cliente ASC. No usar SELECT *. v1 con subconsulta en WHERE: WHERE total > (SELECT avg(...)); v2 con JOIN a CTE de promedio: JOIN promedio ON total > promedio_general. Verificación EXCEPT bidireccional 0 filas, mismas columnas y tipos."

**Prompt Parte 4 (competencia — consulta común):**
> "Dado este plan EXPLAIN (ANALYZE, BUFFERS) de la consulta común (4 JOINs categoria→producto→detalle_pedido→pedido, Seq Scan pedido con Filter fecha Rows Removed 150k, Hash Join build detalle 4MB Batches 1, Merge Join + Sort 3201kB, cost 8124 actual 178ms Buffers 4821), proponé índice/reescritura justificando nodo join atacado y qué cambio de algoritmo esperás. Gana menor Execution Time (tiempo real), no menor cost estimado."

---

## Qué se aceptó tal cual (ejemplo sintético)

- Estructura `RANK() OVER (ORDER BY total_gastado DESC)` sin `PARTITION BY` (ranking global) en Spec 1 v1/v2 — correcta, con huecos en empates.
- CTE `gasto_por_cliente` + `CROSS JOIN promedio` + `WHERE total > (SELECT ...)` en Spec 2 v1 — subconsulta escalar válida.
- `JOIN promedio ON total > promedio_general` en Spec 2 v2 — misma semántica, sintaxis distinta, `EXCEPT 0`.
- Índices `idx_pedido_fecha_id (fecha, id_cliente)` y `idx_producto_categoria_activo (id_categoria, activo) INCLUDE(precio)` — atacan `Seq Scan` exacto.
- Índice parcial `idx_cliente_activo_true WHERE activo=TRUE` — evita `Rows Removed 620`.
- Nombres de columnas, `GROUP BY` completo, `ORDER BY total_gastado DESC, id_cliente ASC` determinístico.

## Qué se modificó o descartó, y por qué

| # | Propuesta IA | Corrección hecha a mano | Por qué |
|---|---|---|---|
| 1 | Kiro Q1: `CREATE INDEX ON pedido(fecha) INCLUDE(id_cliente, forma_pago)` covering total (14MB) | Se reemplazó por `ON pedido(fecha, id_cliente)` lean (8MB) | Consigna y `AGENTS.md`: índice debe ser defendible por tamaño/mantenimiento; mejora marginal `Buffers 512→490` no justifica duplicar tamaño sin cambiar algoritmo join. |
| 2 | Kiro Q2: sugerir `DENSE_RANK()` en Spec 1 | Se corrigió a `RANK()` | Spec exige `RANK` con huecos (cátedra); `DENSE_RANK` no deja huecos y `ROW_NUMBER` no comparte puesto — `EXCEPT` daría filas con empates. |
| 3 | IA ficticia Parte 2: confundió `cost=4890` con `4890ms`, invirtió externa/interna, `Buffers→filas`, `HashAggregate→Hash Join` | Se corrigió con evidencia `cost` vs `actual time`, `loops=1` vs `loops=48210`, `Buffers` páginas 8KB vs `rows`, `Batches/Memory` | Regla de oro Parte 2 — decidir con `Execution Time` (45.820ms), no con `cost` (4890). `loops` indica externa/interna; `HashAggregate` ≠ `Hash` de join. |
| 4 | IA ficticia: "No hay Sort porque hay LIMIT" | Se corrigió: sí hay `Sort top-N heapsort 31kB` para `ORDER BY facturación DESC` | `LIMIT` sin índice ordenado sobre expresión agregada igual requiere `Sort`; `top-N heapsort` mantiene heap de 20, no evita ordenar. Solo desapareció el `Sort 3201kB` del `Merge Join`. |
| 5 | Cualquier `SELECT *` sugerido | Se reemplazó por columnas explícitas `id_cliente, nombre, email, total_gastado, puesto/promedio_general` | Convención `AGENTS.md` y consigna Parte 3 — sin `SELECT *`, `snake_case`, tipos idénticos para `EXCEPT`. |

## Verificación (ejemplo sintético — protocolo completo)

- **Parte 1:** `EXPLAIN (ANALYZE, BUFFERS)` antes/después por consulta — planes en `C:\Users\jeron\AppData\Local\Temp\plan_TP4_Q1_antes.txt` / `plan_TP4_Q2_antes.txt` / `plan_TP4_Q1_despues.txt` / `plan_TP4_Q2_despues.txt` — tabla comparativa con algoritmo join antes/después y mejora `×` en `docs/optimizacion_tp4_parte1.md`.
  - Q1: `180.5ms → 45.8ms` (3.94×), `cost 8124→4890`, `Buffers 4821→512`
  - Q2: `250.3ms → 60.1ms` (4.16×), `cost 15420→8920`, `Buffers 6210→1820`
- **Parte 2:** tabla Afirmación IA | ¿Correcta? | Corrección con evidencia `cost` vs `actual time`, `loops`, `Buffers hit/read`, `Batches` en `docs/lectura_critica_tp4_parte2.md` §3 — 6 afirmaciones (1 correcta, 3 erróneas, 1 incompleta, 1 confusión HashAggregate).
- **Parte 3:** `EXCEPT` bidireccional `0, 0` para Spec 1 y Spec 2 — `SELECT * FROM q_a EXCEPT SELECT * FROM q_b` y viceversa, ambas direcciones 0 = equivalentes. Ver `db/consultas_tp4_parte3.sql` §verificación.
  - Spec 1: `A EXCEPT B 0`, `B EXCEPT A 0` (CTE vs subconsulta derivada, ambas `RANK()`)
  - Spec 2: `A EXCEPT B 0`, `B EXCEPT A 0` (subconsulta escalar vs `JOIN` a CTE promedio)
- **Parte 4:** registro competencia con `Execution Time` antes/después y mejora `×` en `docs/competencia_tp4_parte4.md` — gana menor `Execution Time` (Coronel 45.82ms, 3.94×, `Nested Loop` con `Index Scan`).

## Trazabilidad

- **Input:** `db/schema.sql` (5 tablas, `forma_pago_enum`, `IDENTITY`, `RESTRICT`, `CHECK`s, índices Semana 3) + `db/consultas_tp4_parte3.sql` (specs precisas) + planes sintéticos Parte 1
- **Output:** `docs/optimizacion_tp4_parte1.md` (Q1/Q2 con planes antes/después, tabla comparativa) + `docs/lectura_critica_tp4_parte2.md` (plan Q1 DESPUÉS + 6 afirmaciones IA + corrección) + `db/consultas_tp4_parte3.sql` (Spec 1/2 v1/v2 + EXCEPT) + `docs/competencia_tp4_parte4.md` (consulta común + bitácora + registro) + `docs/DUIA_TP4.md` (este archivo)
- **Criterio de aceptación:** todo SQL explicable línea por línea, todo índice justificado por nodo join (`loops`/`Batches`/`Buffers`), toda mejora medida con `EXPLAIN (ANALYZE, BUFFERS)` y decidida por `actual time` / `Execution Time` (no por `cost`), `EXCEPT` 0 en Parte 3, sin `SELECT *`, con `activo=TRUE` donde corresponde.
