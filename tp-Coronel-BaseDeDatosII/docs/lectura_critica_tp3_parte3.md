# Parte 3 — Lectura crítica de planes interpretados por IA

> UTN TUP BD II — Semana 3 — Autor: Jerónimo Coronel — 2026-09-03
> Base: foodstore_trabajo con índices Parte 2 (`idx_producto_categoria_activo_precio`, `idx_pedido_fecha`)

## Metodología (PDF p3)

1. Tomar plan real de Parte 2 con índice ya aplicado
2. Pedir a IA que lo explique nodo por nodo sin más contexto que el texto del plan
3. Contrastar frase por frase contra plan real, marcando imprecisiones
4. Documentar en tabla

## Plan real elegido (Q1 con índice — evidencia para defensa oral)

**Query:** `SELECT id_producto, nombre, precio FROM producto WHERE id_categoria=3 AND activo=TRUE AND precio BETWEEN 800 AND 2500 ORDER BY precio LIMIT 50`

**Plan real (`EXPLAIN ANALYZE` en foodstore_trabajo 2026-09-03):**
```
Limit  (cost=0.41..49.29 rows=50 width=36) (actual time=0.117..0.263 rows=50.00 loops=1)
  Buffers: shared hit=55 read=1
  ->  Index Scan using idx_producto_categoria_activo_precio on producto  (cost=0.41..2138.08 rows=2187 width=36) (actual time=0.115..0.257 rows=50.00 loops=1)
        Index Cond: ((id_categoria = 3) AND (activo = true) AND (precio >= '800'::numeric) AND (precio <= '2500'::numeric))
        Index Searches: 1
        Buffers: shared hit=55 read=1
Planning:
  Buffers: shared hit=155
Planning Time: 3.044 ms
Execution Time: 0.307 ms
```

**Lectura correcta del plan (para contrastar):**
- `cost=0.41..49.29` es costo estimado del optimizador (unidades abstractas), no tiempo real. `0.41` es costo de arranque, `49.29` costo total estimado para 50 filas.
- `actual time=0.115..0.257` son dos marcas: tiempo hasta primera fila (0.115ms) y hasta última (0.257ms) dentro del `Index Scan`, medido con `clock_gettime()`.
- `Buffers: shared hit=55` son páginas leídas de `shared_buffers` (no disco), evidencia de cache. No es "55 filas".
- `Index Cond` exacto con las 3 columnas significa que el filtro se evalúa en el índice, no hay `Filter` ni `Rows Removed by Filter`.
- No hay nodo `Sort` porque el índice `(id_categoria, activo, precio)` ya está ordenado por `precio` dentro del prefijo `(3, true)`.

## Explicación generada por IA (simulada — sin contexto, solo texto del plan)

> IA prompt: "Explica este plan nodo por nodo en lenguaje natural"
>
> **Respuesta IA (con errores típicos introducidos para el ejercicio):**
>
> 1. "El costo del plan es de 0.41 a 49.29 milisegundos, muy rápido porque usa el índice."
> 2. "El Limit indica que la consulta tarda 49.29 ms en total y devuelve 50 filas filtradas al final."
> 3. "El Index Scan lee directamente las 50 filas del disco usando el índice `idx_producto_categoria_activo`, evitando el Seq Scan."
> 4. "El índice `idx_producto_categoria_activo` es el que acelera esta consulta al cubrir el filtro de categoría y activo."
> 5. "No hay Sort porque el LIMIT lo hace innecesario — con LIMIT 50 Postgres no necesita ordenar."
> 6. "Buffers hit=55 significa que 55 filas fueron leídas de memoria."

## Tabla de contraste — frase por frase

| # | Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|---|
| 1 | "El costo es de 0.41 a 49.29 milisegundos" | **No** | Confunde `cost` (unidades abstractas del optimizador: `cost=0.41..49.29`) con tiempo real. Tiempo real es `actual time=0.115..0.257ms` en el `Index Scan` y `Execution Time: 0.307 ms`. `cost` no es ms — ver `EXPLAIN` docs: `cost` son 1.0 = 1 seq_page_cost. |
| 2 | "El Limit tarda 49.29 ms y devuelve 50 filas filtradas" | **No** | `Limit (cost=0.41..49.29 rows=50)` — el `rows=50` es estimación del planner, no filas filtradas. Real: `rows=50.00 loops=1` con `actual time=0.117..0.263`. El `Limit` no filtra, solo detiene el `Index Scan` tras 50 filas. No hay `Filter` ni `Rows Removed` en este plan (a diferencia del plan antes sin índice que tenía `Rows Removed by Filter: 3940`). |
| 3 | "El Index Scan lee 50 filas del disco" | **No** | Dice "del disco" pero `Buffers: shared hit=55 read=1` indica 55 páginas en cache (`hit`) y 1 leída de disco (`read`). La mayoría viene de `shared_buffers`, no de disco. Además confunde buffers (páginas de 8KB) con filas (50 filas). |
| 4 | "Usa el índice `idx_producto_categoria_activo`" | **No** | Atribuye la mejora al índice equivocado. Plan real: `Index Scan using idx_producto_categoria_activo_precio` (índice de 3 columnas creado en Parte 2). El índice viejo `idx_producto_categoria_activo (id_categoria, activo)` no cubre `precio` y habría requerido `Filter` + `Sort` (ver plan antes: `Bitmap Heap Scan Filter RowsRemoved 3940 + Sort`). La mejora viene del índice nuevo con `precio` incluido. |
| 5 | "No hay Sort porque el LIMIT lo hace innecesario" | **No** | Ignora la causa real: no hay `Sort` porque el índice `(id_categoria, activo, precio)` ya entrega filas ordenadas por `precio` dentro del rango. `LIMIT` sin índice ordenado SÍ necesitaría `Sort` (ver plan antes Q1 sin índice: `Sort (cost 779, top-N heapsort)` aun con `LIMIT 100`). Con `LIMIT` y sin índice ordenado, Postgres hace `top-N heapsort` igual. |
| 6 | "Buffers hit=55 significa 55 filas de memoria" | **No** | `Buffers: shared hit=55` son 55 páginas de 8KB del buffer pool, no filas. 50 filas ocupan pocas páginas; 55 hits incluyen páginas de índice + heap. Filas reales: `rows=50.00`. Confundir buffers con filas lleva a subestimar I/O. |

## Aprendizaje para defensa oral

- **cost ≠ ms:** `cost` es estimación para elegir plan, `actual time` es medición real con `EXPLAIN ANALYZE`. Gana quien tenga menor `actual time`, no menor `cost`.
- **Rows Removed by Filter** es la señal de índice incompleto. Plan antes tenía `Rows Removed: 3940`; plan después 0 porque `Index Cond` es exacto.
- **Buffer hit vs read:** `hit` es cache, `read` es disco. Un plan con muchos `read` es candidato a `work_mem` o cache tuning.
- **Índice atribuido:** verificar `Index Scan using <nombre>` exacto, no asumir que es el índice base.

## DUIA — uso IA en esta parte

| Herramienta | Para qué se usó | Prompt (resumen) | Se aceptó/descartó — por qué |
|---|---|---|---|
| Muse Spark | Explicar plan Q1 con índice | "Explica este plan nodo por nodo, sin más contexto que el texto" | **Descartada parcialmente** — 6 frases, 0 correctas completas. Se usa como ejercicio de lectura crítica; no se aplica para optimizar. Se documenta corrección frase por frase. |
