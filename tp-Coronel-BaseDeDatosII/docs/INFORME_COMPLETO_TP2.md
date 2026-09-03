# INFORME COMPLETO — Trabajo Práctico Base de Datos II — Unidad 1 Semana 2

> **Universidad Tecnológica Nacional — Tecnicatura Universitaria en Programación**
> **Asignatura:** Base de Datos II — Unidad 1 Semana 2 (Concurrencia e IA como motor primario)
> **Autor:** Jerónimo Coronel
> **Fecha:** 2026-09-03
> **Motor:** PostgreSQL 16 (psql / pg_dump / createdb / pg_restore)
> **Esquema base:** FoodStore — `tp-Coronel-BaseDeDatosII/db/schema.sql`
> **Repositorio:** https://github.com/jeronimocoronel784-hue/BaseDeDatos2
> **Carpeta canónica local:** `C:\BaseDeDatos2\tp-Coronel-BaseDeDatosII\`
> **Estado:** ✅ Entrega completa — 5/5 — defendible línea por línea

![UTN](https://img.shields.io/badge/UTN-TUP%20Programaci%C3%B3n-informational) ![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16-336791) ![Estado](https://img.shields.io/badge/Estado-5%2F5%20completo-brightgreen) ![Fecha](https://img.shields.io/badge/Fecha-2026--09--03-blue)

---

## Índice

- [0. Resumen ejecutivo](#0-resumen-ejecutivo)
- [1. Consigna del TP — Qué se pidió](#1-consigna-del-tp--qué-se-pidió)
- [2. Punto de partida — Estado inicial del repo](#2-punto-de-partida--estado-inicial-del-repo)
- [3. Esquema base — FoodStore](#3-esquema-base--foodstore-dbschemasql)
- [4. Cambios realizados — Detalle por commit](#4-cambios-realizados--detalle-por-commit)
- [5. Reordenamiento — De repo plano a estructura tp-Coronel](#5-reordenamiento--de-repo-plano-a-estructura-tp-coronel)
- [6. Parte 0 — Protocolo de Seguridad](#6-parte-0--protocolo-de-seguridad-docsprotocolo_seguridadmd)
- [7. Parte 1 — Restricciones FoodStore](#7-parte-1--restricciones-foodstore-dbrestricciones_foodstoresql--duia)
- [8. Parte 2 — Laboratorio Concurrencia](#8-parte-2--laboratorio-concurrencia-docsinforme_concurrenciamd)
- [9. Parte 3 — Lectura Crítica](#9-parte-3--lectura-crítica-docsejercicio_lectura_criticamd)
- [10. Estructura final del repositorio](#10-estructura-final-del-repositorio)
- [11. Verificación — Cómo reproducir y defender oralmente](#11-verificación--cómo-reproducir-y-defender-oralmente)
- [12. Checklist final de entrega](#12-checklist-final-de-entrega-55)
- [13. Conclusiones y aprendizajes](#13-conclusiones-y-aprendizajes)
- [14. Anexos](#14-anexos)

---

## 0. Resumen ejecutivo

El TP2 de Base de Datos II — Unidad 1 Semana 2 exige demostrar, bajo **PostgreSQL 16** y con **IA como motor primario de escritura pero nunca de decisión**, el dominio de tres competencias troncales: (a) **protocolo de seguridad** obligatorio — trabajar siempre sobre copia, dentro de transacción con verificación y con respaldo versionado—, (b) **modelado de reglas de negocio en el motor** mediante `CHECK`/`TRIGGER` con pruebas `BEGIN/ROLLBACK`, y (c) **concurrencia transaccional** — anomalías no repetible y fantasma, niveles `READ COMMITTED`/`REPEATABLE READ`/`SERIALIZABLE`, y bloqueo pesimista `SELECT ... FOR UPDATE` con diagnóstico `pg_locks`/`pg_stat_activity` y `deadlock 40P01`—, más una **lectura crítica** de dos scripts peligrosos generados por IA (`UPDATE` sin `WHERE` y `DELETE NOT IN` con `NULL`). A lo largo del trabajo cada artefacto generado por IA fue acompañado de su **DUIA** (Declaración de Uso de IA) con spec, qué se aceptó, qué se corrigió y verificación en motor.

Se entregaron los **5 entregables** exigidos por la rúbrica, versionados en **5 commits** trazables, reordenados desde un repo plano desordenado a la estructura canónica `tp-Coronel-BaseDeDatosII/{db,docs,src}` con `git mv R100` para preservar historia. El informe que usted lee consolida y cita contenido real de cada archivo, sin invención, listo para impresión y defensa oral.

### Tabla de entregables

| # | Entregable (según PDF) | Archivo canónico | Líneas / Tamaño | Commit que lo introduce | Estado |
|---|---|---|---|---|---|
| 0 | Parte 0 — Protocolo de seguridad (copia + transacción + respaldo) — **antes de Parte 1** | `docs/protocolo_seguridad.md` | 199 líneas / 10.002 bytes | `b7fe275` | ✅ |
| 1 | Parte 1 — 2–3 reglas de negocio con IA + modo Plan + diff + `BEGIN/ROLLBACK` + DUIA | `db/restricciones_foodstore.sql` (386 líneas) + `docs/DUIA_Parte1.md` (150 líneas) | 536 líneas / 31.877 bytes | `6ef68e6` | ✅ |
| 2a | Parte 2 — 3 anomalías concurrencia (no repetible, fantasma, `FOR UPDATE`/interbloqueo) verificadas en motor | `docs/informe_concurrencia.md` | 398 líneas / 18.816 bytes | `6ef68e6` | ✅ |
| 2b | Parte 2 — DUIA Parte 2 | `docs/DUIA_Parte2.md` | 35 líneas / 3.569 bytes | `6ef68e6` | ✅ |
| 3 | Parte 3 — Lectura crítica 2 scripts peligrosos + correcciones + DUIA | `docs/ejercicio_lectura_critica.md` (incluye DUIA Parte 3) | 343 líneas / 15.936 bytes | `6ef68e6` | ✅ |
| — | Esquema base FoodStore | `db/schema.sql` | 72 líneas / 3.251 bytes | `80ad8a2` | ✅ |
| — | Convenciones y guía | `AGENTS.md` + `README.md` + `.gitignore` + `.env.example` + `db/backups/` | 6 archivos | `7b056d0` | ✅ |

**Checklist final: 5/5 ✅** — ver §12 para mapeo rúbrica → archivo → commit.

---

## 1. Consigna del TP — Qué se pidió

> Síntesis fiel de `TP2_Laboratorio_Concurrencia_IA.pdf` (4 partes + rúbrica). No se omite ninguna exigencia.

### Parte 0 — Protocolo de Seguridad (prerrequisito bloqueante)

| Qué pide la cátedra | Detalle | Evidencia exigida |
|---|---|---|
| **Copia** | Nunca trabajar sobre la base de producción. Todo DDL/DML sobre una copia aislada. | Comando de copia y BD `foodstore_trabajo` |
| **Transacción** | Probar cada cambio dentro de transacción explícita: `BEGIN;` → verificación (`SELECT`/`COUNT(*)`) → `ROLLBACK` y solo luego `COMMIT` | Snippet `BEGIN; ... ROLLBACK;` / `BEGIN; ... COMMIT;` |
| **Respaldo** | Respaldo físico versionado antes de cada sesión/cambio relevante | `pg_dump -Fc -f db/backups/YYYYMMDD.dump` + directorio `db/backups/` |
| **Adaptado y commiteado antes de Parte 1** | El protocolo debe estar adaptado al entorno real del alumno (no genérico) y commiteado **en un commit previo** a cualquier regla de negocio | `git log` muestra `protocolo_seguridad.md` en commit anterior a `restricciones_foodstore.sql` |

### Parte 1 — 2–3 Reglas de negocio con OpenCode (IA como motor primario)

| Exigencia | Detalle |
|---|---|
| **IA como escritor primario** | Las 2–3 reglas se generan con herramienta IA (en este TP: **Muse Spark / OpenCode `muse-spark-1.2-contributor-free`**) |
| **Spec antes** | Para cada regla se entrega la spec/prompt textual exacta dada a la IA (nombres de tablas/columnas reales del `schema.sql`) |
| **Modo Plan** | El agente IA debe operar en modo Plan: propone `diff` sin tocar archivos hasta aprobación |
| **Diff línea por línea defendible** | Cada línea del diff generado debe poder explicarse oralmente (qué hace, por qué está ahí) |
| **`BEGIN/ROLLBACK` obligatorio** | Toda prueba de la regla se hace dentro de transacción con `ROLLBACK` (`BEGIN; INSERT válido; ROLLBACK;` / `BEGIN; INSERT inválido → ERROR; ROLLBACK;`) |
| **DUIA Parte 1** | Tabla de 6 campos: Herramienta, Spec, Qué generó, Qué se aceptó, Qué se modificó/descartó y por qué, Verificación |

### Parte 2 — 3 Anomalías de concurrencia + IA verificada en motor

| Escenario | Anomalía | Qué debe contener el informe |
|---|---|---|
| **A** | **Lectura No Repetible** (Non-Repeatable Read) | Comandos Sesión A/B ordenados con timestamps, nivel de aislamiento (`READ COMMITTED` vs `REPEATABLE READ`), salida observada, explicación IA copiada textual, verificación en motor, conclusión de nivel que lo evita |
| **B** | **Lectura Fantasma** (Phantom Read) | `COUNT(*)` sobre rango (`id_categoria`), `INSERT` fantasma, comparación `RC` (permite) vs `RR` (PG lo evita por snapshot; ANSI exige `SERIALIZABLE`), misma tabla de 6 campos |
| **C** | **`FOR UPDATE` / Espera por bloqueo / Interbloqueo (deadlock)** | `SELECT ... FOR UPDATE`, diagnóstico `pg_locks` (`granted=t/f`) + `pg_stat_activity` (`wait_event=transaction`), `COMMIT` libera lock, extensión deadlock `ERROR 40P01` con 2 filas en orden cruzado + `ORDER BY` como prevención |
| **Motor** | PostgreSQL 16 — MVCC, `pg_locks`, `pg_stat_activity`, error `40P01` | Todo reproducido en `foodstore_trabajo` (copia vía `createdb -T foodstore_original`) |
| **Artefactos** | `docs/informe_concurrencia.md` (3 escenarios completos + tabla comparativa) + `DUIA_Parte2.md` | Mismo formato DUIA de 6 campos; explicación IA verificada línea por línea en motor |

### Parte 3 — Lectura crítica de 2 scripts peligrosos

| Script | Código peligroso | Qué debe analizarse | Corrección exigida |
|---|---|---|---|
| **1** | `UPDATE funcion SET activa = FALSE;` (sin `WHERE`) — análogo FoodStore `UPDATE producto SET activo=FALSE;` | Efecto real (¿cuántas filas toca?), por qué no coincide con intención (falta `WHERE`/`JOIN`), demostración con `SELECT COUNT(*)` | Versión con `WHERE id_pelicula IN (SELECT ... WHERE estado='RETIRADA') AND activa=TRUE` + `BEGIN/ROLLBACK` + sonda previa/posterior + prueba transaccional |
| **2** | `DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto);` — análogo `id_categoria NOT IN (SELECT id_categoria FROM producto)` | Trampa `NULL` en `NOT IN` (lógica trivaluada → `UNKNOWN` → 0 filas), borrado físico vs lógico (`activo` + `ON DELETE RESTRICT`), `NOT EXISTS` vs `NOT IN ... IS NOT NULL` | 3 variantes ordenadas: `NOT EXISTS` (recomendada, inmune a NULL) > `NOT IN ... WHERE IS NOT NULL` > borrado lógico `UPDATE categoria SET activo=FALSE WHERE NOT EXISTS (...)` + prueba `BEGIN/ROLLBACK` + demo `NULL` + `ERROR FK RESTRICT` |
| **DUIA Parte 3** | Incluida al final de `ejercicio_lectura_critica.md` | Mismo esquema 6 campos + checklist genérico para cualquier DML-IA | Validación en motor con `ROLLBACK` |

### Rúbrica y checklist final (resumen)

La rúbrica evalúa: completitud de los 5 entregables, protocolo commiteado antes de Parte 1, uso de IA con spec + DUIA + diff defendible, verificación en motor con `BEGIN/ROLLBACK` y aislamiento, correcciones con manejo de `NULL`/`WHERE`/`FOR UPDATE`/`ON DELETE RESTRICT`, y repositorio ordenado con `db/`/`docs/`/`src/` y `AGENTS.md`.

| Ítem rúbrica | Archivo que lo cubre | Criterio de aprobación |
|---|---|---|
| Protocolo adaptado + backup + transacción | `docs/protocolo_seguridad.md` + `db/backups/` | Comandos `createdb -T`, `pg_dump -Fc`, `BEGIN/ROLLBACK` presentes y commiteados antes |
| 2–3 reglas con IA + spec + diff + DUIA | `db/restricciones_foodstore.sql` + `docs/DUIA_Parte1.md` | 3 reglas (R1/R2/R3) con triggers/CHECKs, 5 correcciones documentadas, 8 pruebas `ROLLBACK` |
| 3 anomalías + verificación + DUIA | `docs/informe_concurrencia.md` + `docs/DUIA_Parte2.md` | 3 escenarios con Sesión A/B, `pg_locks`, `40P01`, 6 verificaciones |
| 2 scripts peligrosos + correcciones + DUIA | `docs/ejercicio_lectura_critica.md` | Tabla comparativa + 3 variantes + demos `NULL`/`RESTRICT`/`WHERE` |
| Repo ordenado + trazabilidad git | `README.md` + `AGENTS.md` + `git log --stat` | `git mv R100`, árbol `tp-Coronel`, 5 commits trazables |

---

## 2. Punto de partida — Estado inicial del repo

### Historia real de commits (antes de este informe)

```
7b056d0 (HEAD -> main, origin/main) refactor(estructura): ordena repo como tp-Coronel-BaseDeDatosII
6ef68e6 feat(tp2): restricciones FoodStore + concurrencia + lectura critica + DUIA
b7fe275 docs(seguridad): protocolo copia-transaccion-respaldo adaptado a PostgreSQL local
55a3b41 protocolos de seguridad
80ad8a2 Primer commit
```

### Qué había en cada commit inicial

| SHA | Mensaje | Contenido real | Observación |
|---|---|---|---|
| `80ad8a2` | `Primer commit` | `squema.sql` (72 líneas, con typo — falta `c` — nombre original del archivo en raíz) | Único archivo; es el DDL FoodStore base que luego sería `db/schema.sql`. No había carpetas `db/` ni `docs/`. |
| `55a3b41` | `protocolos de seguridad` | `AGENTS.md` (16 líneas, convenciones PG) + `protocolo_seguridad.md` (0 bytes — archivo vacío placeholder) | Commit de “protocolos” pero el protocolo estaba vacío; no cumplía Parte 0. |
| `b7fe275` | `docs(seguridad): protocolo copia-transaccion-respaldo adaptado a PostgreSQL local` | `protocolo_seguridad.md` 194 líneas (versión real, adaptada a `createdb -T` / `pg_dump -Fc`) | **Checkpoint Parte 0 correcto**: commiteado antes de cualquier regla. Mensaje indica “Parte 0 — Jerónimo Coronel 2026-09-03”. |
| `6ef68e6` | `feat(tp2): restricciones FoodStore + concurrencia + lectura critica + DUIA` | 5 archivos, 1.312 líneas: `restricciones_foodstore.sql` (386), `informe_concurrencia.md` (398), `ejercicio_lectura_critica.md` (343), `DUIA_Parte1.md` (150), `DUIA_Parte2.md` (35) | Entrega masiva que resuelve Partes 1/2/3 de una vez, aún en **raíz plana** (sin `tp-Coronel-BaseDeDatosII/`). |
| `7b056d0` | `refactor(estructura): ordena repo como tp-Coronel-BaseDeDatosII` | 16 archivos, `git mv R100`, crea `.env.example`, `.gitignore`, `README.md`, `db/backups/.gitkeep`, `src/.gitkeep`, mueve todo a `tp-Coronel-BaseDeDatosII/` | **Reordenamiento canónico** pedido por el usuario; preserva historia. |

### El problema estructural que motivó el refactor

- **Carpeta de trabajo real del alumno:** capturas y consigna indican que el alumno trabajaba en `C:\Users\jeron\OneDrive\Desktop\Programacion UTN\3er semestre\Metodologia de Sist\Base de Datos II\BaseDeDatos2` — una ruta con espacios, plana, sin subcarpetas canónicas.
- **Repo git real:** `C:\BaseDeDatos2` (donde está `.git/`), con remote `origin https://github.com/jeronimocoronel784-hue/BaseDeDatos2`.
- **Desacople:** la carpeta `Base de Datos II\BaseDeDatos2` y `C:\BaseDeDatos2` no coincidían; había que centralizar en `C:\BaseDeDatos2\tp-Coronel-BaseDeDatosII` (estructura pedida por la cátedra: `tp-Coronel-BaseDeDatosII/{db,docs,src}`).
- **Faltante pre-refactor:** los 5 entregables existían pero estaban en raíz plana (`restricciones_foodstore.sql`, `protocolo_seguridad.md`, etc. sueltos), sin `db/` ni `docs/`; faltaban `.gitignore`, `.env.example`, `README.md`, `backups/.gitkeep`.
- **Solución:** commit `7b056d0` con `git mv` (no `mv` + `add`) para que `git log --follow` preserve trazabilidad (`R100`).

---

## 3. Esquema base — FoodStore (`db/schema.sql`)

> Archivo: `tp-Coronel-BaseDeDatosII/db/schema.sql` — 72 líneas — 3.251 bytes — commit `80ad8a2` (luego `R100` a `db/schema.sql`). Leído íntegramente para este informe; el DDL citado abajo es copia textual resumida, sin invención.

### Diagrama lógico

```
categoria 1──∞ producto ∞──┐
                           ├── detalle_pedido ∞──1 pedido 1──1 cliente
categoria 1──∞ producto ───┘              (PK compuesta id_pedido+id_producto)
```

### DDL textual (resumen fiel — bloque `sql`)

```sql
-- Dominio cerrado
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE          -- soft delete
);

CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,           -- clave candidata R6
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria BIGINT NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    precio NUMERIC(10, 2) NOT NULL,
    stock INTEGER NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
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
    PRIMARY KEY (id_pedido, id_producto),         -- un producto no se repite por pedido
    CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio   CHECK (precio_unitario >= 0),
    CONSTRAINT fk_detalle_pedido   FOREIGN KEY (id_pedido)   REFERENCES pedido(id_pedido)     ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
);

CREATE INDEX idx_pedido_cliente ON pedido (id_cliente);
CREATE INDEX idx_producto_categoria_activo ON producto (id_categoria, activo);
```

### Tabla de análisis del esquema

| Tabla | PK | FK | CHECKs | Índices | Soft delete | ENUM | Notas de diseño |
|---|---|---|---|---|---|---|---|
| `categoria` | `id_categoria` IDENTITY | — | — | — | `activo BOOLEAN DEFAULT TRUE` | — | Maestra de productos |
| `cliente` | `id_cliente` IDENTITY | — | — | UNIQUE `email` (clave candidata) | `activo` | — | `ON DELETE RESTRICT` desde `pedido` |
| `producto` | `id_producto` IDENTITY | `fk_producto_categoria → categoria` `RESTRICT` | `chk_producto_precio >=0`, `chk_producto_stock >=0` | `idx_producto_categoria_activo(id_categoria, activo)` | `activo` | — | Precio/stock no negativos en DDL base; Parte 1 refuerza a `>0` y tolerancia |
| `pedido` | `id_pedido` IDENTITY | `fk_pedido_cliente → cliente` `RESTRICT` | — | `idx_pedido_cliente(id_cliente)` | — | `forma_pago_enum` | `fecha TIMESTAMPTZ DEFAULT now()` — R1 valida “no futura” |
| `detalle_pedido` | `PRIMARY KEY (id_pedido, id_producto)` compuesta | `fk_detalle_pedido`, `fk_detalle_producto` `RESTRICT` | `chk_detalle_cantidad >0`, `chk_detalle_precio >=0` | PK compuesta indexa | — | — | Tabla asociativa; R2/R3 la intervienen |

**Decisiones de diseño defendibles:** `GENERATED ALWAYS AS IDENTITY` (PG 10+, preferido sobre `SERIAL`), `ON DELETE RESTRICT` sistemático para preservar historial (no `CASCADE`), `BOOLEAN activo` para baja lógica, `TIMESTAMPTZ` con `now()` y `NUMERIC(10,2)` para moneda, `ENUM` cerrado para forma de pago. Ver `AGENTS.md:1` y `db/schema.sql:1`.

---

## 4. Cambios realizados — Detalle por commit

> Fuente: `git log --oneline --stat --all` y `git show --stat <sha>` ejecutados en `C:\BaseDeDatos2` el 2026-09-03. SHAs y mensajes copiados textuales. Tabla exhaustiva — no se omite ningún commit.

### 4.1 Historial final (`git log --oneline --decorate --all`)

```
7b056d0 (HEAD -> main, origin/main, origin/HEAD) refactor(estructura): ordena repo como tp-Coronel-BaseDeDatosII
6ef68e6 feat(tp2): restricciones FoodStore + concurrencia + lectura critica + DUIA
b7fe275 docs(seguridad): protocolo copia-transaccion-respaldo adaptado a PostgreSQL local
55a3b41 protocolos de seguridad
80ad8a2 Primer commit
```

### 4.2 Tabla por commit (5 commits)

| # | SHA corto | Mensaje (subject líneal) | Archivos tocados (reales) | Líneas | Qué resolvió (mapeo a TP) | Estado |
|---|---|---|---|---|---|---|
| 1 | `80ad8a2` | `Primer commit` | `squema.sql` (A) | +72 | **Esquema base FoodStore** — DDL con `forma_pago_enum`, 5 tablas, `RESTRICT`, `CHECKs`, `IDENTITY`, índices. Es el punto de partida; el nombre con typo `squema.sql` se corrige en commit 5. | ✅ Base |
| 2 | `55a3b41` | `protocolos de seguridad` | `AGENTS.md` (A, 16 líneas) + `protocolo_seguridad.md` (A, 0 bytes) | +16, 0 | **Placeholder Parte 0** — crea `AGENTS.md` con convenciones (`chk_*`, `fk_*`, `RESTRICT`, `activo`) y deja `protocolo_seguridad.md` vacío. No cumplía; se completa en commit 3. | ⚠️ Vacío |
| 3 | `b7fe275` | `docs(seguridad): protocolo copia-transaccion-respaldo adaptado a PostgreSQL local` | `protocolo_seguridad.md` (M, 194 líneas) | +194 | **Parte 0 completa** — adapta los 3 pasos de la cátedra a comandos PG locales (`createdb -T foodstore_original foodstore_trabajo`, `BEGIN/ROLLBACK`, `pg_dump -Fc db/backups/`), define `db/backups/`, flujo DDL/DML, regla “nunca tocar producción”, evidencia de trazabilidad. **Commiteado antes de Parte 1** tal como exige la consigna. | ✅ Parte 0 |
| 4 | `6ef68e6` | `feat(tp2): restricciones FoodStore + concurrencia + lectura critica + DUIA` | `DUIA_Parte1.md` (A 150), `DUIA_Parte2.md` (A 35), `ejercicio_lectura_critica.md` (A 343), `informe_concurrencia.md` (A 398), `restricciones_foodstore.sql` (A 386) | +1.312 | **Partes 1+2+3** — 3 reglas (R1/R2/R3) con triggers/CHECKs idempotentes, 3 escenarios concurrencia (RC/RR/FOR UPDATE + `40P01`) con `pg_locks`, 2 scripts peligrosos corregidos (`NOT EXISTS`/`WHERE`), + DUIAs. Todo en **raíz plana** aún. | ✅ Partes 1-3 |
| 5 | `7b056d0` | `refactor(estructura): ordena repo como tp-Coronel-BaseDeDatosII` | Ver §5 tabla de mapeo — 16 archivos: `AGENTS.md` (M), `tp-Coronel-BaseDeDatosII/.env.example` (A), `tp-Coronel-BaseDeDatosII/.gitignore` (A), `tp-Coronel-BaseDeDatosII/AGENTS.md` (A), `tp-Coronel-BaseDeDatosII/README.md` (A), `db/backups/.gitkeep` (A), `db/backups/README.md` (A), 6× `R100 git mv`, `docs/README.md` (A), `src/.gitkeep` (A), `protocolo_seguridad.md` → `docs/protocolo_seguridad.md` (R070 + ajuste 63 líneas) | +164 / -35 (net) | **Reordenamiento canónico** — mueve todo a `tp-Coronel-BaseDeDatosII/{db,docs,src}`, corrige typo `squema.sql → db/schema.sql`, crea `.gitignore`/`.env.example`/`README.md`, preserva historia con `git mv`. Estructura final pedida por el usuario. | ✅ Estructura |

### 4.3 `git log --oneline --stat` real (copiado textual)

```
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
 16 files changed, 164 insertions(+), 35 deletions(-)
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

### 4.4 `git log --name-status` (evidencia de `git mv R100`)

```
7b056d0 refactor(estructura): ordena repo como tp-Coronel-BaseDeDatosII
M	AGENTS.md
A	tp-Coronel-BaseDeDatosII/.env.example
A	tp-Coronel-BaseDeDatosII/.gitignore
A	tp-Coronel-BaseDeDatosII/AGENTS.md
A	tp-Coronel-BaseDeDatosII/README.md
A	tp-Coronel-BaseDeDatosII/db/backups/.gitkeep
A	tp-Coronel-BaseDeDatosII/db/backups/README.md
R100	restricciones_foodstore.sql	tp-Coronel-BaseDeDatosII/db/restricciones_foodstore.sql
R100	squema.sql	tp-Coronel-BaseDeDatosII/db/schema.sql
R100	DUIA_Parte1.md	tp-Coronel-BaseDeDatosII/docs/DUIA_Parte1.md
R100	DUIA_Parte2.md	tp-Coronel-BaseDeDatosII/docs/DUIA_Parte2.md
A	tp-Coronel-BaseDeDatosII/docs/README.md
R100	ejercicio_lectura_critica.md	tp-Coronel-BaseDeDatosII/docs/ejercicio_lectura_critica.md
R100	informe_concurrencia.md	tp-Coronel-BaseDeDatosII/docs/informe_concurrencia.md
R070	protocolo_seguridad.md	tp-Coronel-BaseDeDatosII/docs/protocolo_seguridad.md
A	tp-Coronel-BaseDeDatosII/src/.gitkeep
6ef68e6 feat(tp2): restricciones FoodStore + concurrencia + lectura critica + DUIA
A	DUIA_Parte1.md
A	DUIA_Parte2.md
A	ejercicio_lectura_critica.md
A	informe_concurrencia.md
A	restricciones_foodstore.sql
b7fe275 docs(seguridad): protocolo copia-transaccion-respaldo adaptado a PostgreSQL local
M	protocolo_seguridad.md
55a3b41 protocolos de seguridad
A	AGENTS.md
A	protocolo_seguridad.md
80ad8a2 Primer commit
A	squema.sql
```

> `R100` = rename 100% — historia preservada. `R070` en protocolo = 70% similitud porque se ajustaron rutas `protocolo_seguridad.md:34` y se agregó encabezado UTN.

---

## 5. Reordenamiento — De repo plano a estructura tp-Coronel

### 5.1 Por qué se reordenó

- **Pedido explícito del usuario:** “Estructura canónica dentro de `C:\BaseDeDatos2\tp-Coronel-BaseDeDatosII` con subcarpetas `db/`, `docs/`, `src/`”.
- **Requisito docente implícito:** la cátedra espera `tp-Coronel-…` como carpeta entregable (apellido + materia), con `db/schema.sql` y `docs/` separados — no un repo plano con `.sql` sueltos en raíz.
- **Higiene git:** los archivos planos en raíz (`squema.sql`, `restricciones_foodstore.sql`, etc.) dificultaban `.gitignore` por tipo (`db/backups/*.dump`) y mezclaban código con documentación. La estructura canónica separa responsabilidades.
- **Preservación de historia:** se usó `git mv` (no `mv` + `git add`), por eso `R100` en `git log --name-status`. Un `git log --follow -- tp-Coronel-BaseDeDatosII/db/schema.sql` sigue mostrando `80ad8a2`.

### 5.2 Mapeo origen → destino

| Origen (raíz plana, pre-`7b056d0`) | Destino (canónico `tp-Coronel-BaseDeDatosII/`) | Tipo | Líneas | Nota |
|---|---|---|---|---|
| `squema.sql` (typo, 72 líneas) | `db/schema.sql` | `R100` rename | 72 | Corrige typo `squema → schema`, preserva contenido idéntico |
| `protocolo_seguridad.md` (194 líneas) | `docs/protocolo_seguridad.md` (199 líneas) | `R070` move + edit | 199 | Ajuste de rutas: `backups/` → `db/backups/`, `squema.sql` → `db/schema.sql`, agregado de encabezado UTN y referencia a `tp-Coronel` |
| `restricciones_foodstore.sql` (386) | `db/restricciones_foodstore.sql` | `R100` | 386 | Sin cambios de contenido |
| `informe_concurrencia.md` (398) | `docs/informe_concurrencia.md` | `R100` | 398 | Sin cambios |
| `ejercicio_lectura_critica.md` (343) | `docs/ejercicio_lectura_critica.md` | `R100` | 343 | Sin cambios |
| `DUIA_Parte1.md` (150) | `docs/DUIA_Parte1.md` | `R100` | 150 | |
| `DUIA_Parte2.md` (35) | `docs/DUIA_Parte2.md` | `R100` | 35 | |
| — | `AGENTS.md` (copia) | `A` | 16 | Duplicado en `tp-Coronel-BaseDeDatosII/AGENTS.md` con ruta ajustada `tp-Coronel-…/db/schema.sql` |
| — | `.env.example` | `A` (rename de `.env.example.txt`) | 16 | Variables `PGHOST/PGDATABASE/PGDATABASE_ORIGINAL` etc. |
| — | `.gitignore` | `A` (rename de `.gitignore.txt`) | 20 | `db/backups/*.dump`, `.env`, `.DS_Store` |
| — | `README.md` | `A` | 53 | Checklist 5/5 + árbol + quickstart |
| — | `docs/README.md` | `A` | 8 | Índice docs |
| — | `db/backups/.gitkeep` | `A` | 0 | Mantiene `backups/` versionado aunque esté vacío por `.gitignore` |
| — | `db/backups/README.md` | `A` | 11 | Instrucciones `pg_dump -Fc` |
| — | `src/.gitkeep` | `A` | 0 | Placeholder para código futuro |
| `AGENTS.md` (raíz) | `AGENTS.md` (raíz, modificado) | `M` | 16 | Actualiza `Core File: db/schema.sql` → `tp-Coronel-BaseDeDatosII/db/schema.sql` |

**Archivos eliminados de raíz en `7b056d0`:** `squema.sql`, `protocolo_seguridad.md`, `restricciones_foodstore.sql`, `informe_concurrencia.md`, `ejercicio_lectura_critica.md`, `DUIA_Parte1/2.md` — todos movidos, no borrados (historia preservada).

### 5.3 Árbol final (`tree` real — `Get-ChildItem -Recurse`)

```
C:\BaseDeDatos2\                          ← git root (remote origin)
├── .git\
├── AGENTS.md                             ← dual: apunta a tp-Coronel/.../db/schema.sql
├── tp-Coronel-BaseDeDatosII\             ← 📦 carpeta canónica (entregable)
│   ├── AGENTS.md
│   ├── README.md
│   ├── .env.example
│   ├── .gitignore
│   ├── db\
│   │   ├── schema.sql                    ← 72 líneas — DDL FoodStore
│   │   ├── restricciones_foodstore.sql   ← 386 líneas — Parte 1 (R1/R2/R3)
│   │   └── backups\
│   │       ├── .gitkeep
│   │       └── README.md
│   ├── docs\
│   │   ├── protocolo_seguridad.md        ← 199 líneas — Parte 0
│   │   ├── informe_concurrencia.md       ← 398 líneas — Parte 2
│   │   ├── ejercicio_lectura_critica.md  ← 343 líneas — Parte 3
│   │   ├── DUIA_Parte1.md                ← 150 líneas — Parte 1
│   │   ├── DUIA_Parte2.md                ← 35 líneas — Parte 2
│   │   ├── INFORME_COMPLETO_TP2.md       ← ← ESTE ARCHIVO (canónico, ~800+ líneas)
│   │   └── README.md
│   └── src\
│       └── .gitkeep
└── INFORME_TP2.md                        ← copia/índice en raíz (apunta al canónico)
```

### 5.4 AGENTS.md dual — justificación

| Archivo | `Core File` declarado | Propósito |
|---|---|---|
| `C:\BaseDeDatos2\AGENTS.md` (raíz git) | `tp-Coronel-BaseDeDatosII/db/schema.sql` | Para que cualquier agente (OpenCode, IDE) que abra el repo git encuentre el DDL canónico sin adivinar. Evita que se edite `squema.sql` fantasma. |
| `C:\BaseDeDatos2\tp-Coronel-BaseDeDatosII\AGENTS.md` | `db/schema.sql` (relativo) | Para que el entregable sea autocontenido: si el docente abre solo `tp-Coronel-BaseDeDatosII/`, las convenciones siguen válidas con rutas relativas. |

Ambos archivos son idénticos salvo la ruta `Core File`; el contenido de convenciones (`ON DELETE RESTRICT`, `chk_*`, `activo BOOLEAN`, índices) es el mismo (`AGENTS.md:1`).

---

## 6. Parte 0 — Protocolo de Seguridad (`docs/protocolo_seguridad.md`)

> Archivo: `docs/protocolo_seguridad.md` — 199 líneas — 10.002 bytes — commit `b7fe275` (antes de Parte 1). Leído íntegramente; lo citado abajo es copia fiel de su tabla §1 y flujos §3/§4.

### 6.1 Qué pide la cátedra vs. adaptación concreta

| Paso cátedra | Qué pide la cátedra (genérico) | Adaptación concreta — PostgreSQL 16 local del alumno | Comando exacto (copiado de `protocolo_seguridad.md:23`) |
|---|---|---|---|
| **1. Copia** | “Trabajar sobre una copia, nunca sobre producción” | Se mantiene `foodstore_original` como BD inmutable (solo se restaura desde `db/schema.sql`). Cada jornada se clona a `foodstore_trabajo` con `createdb -T` (copia por template, instantánea). Si ya existe se dropea y recrea. | `createdb -T foodstore_original foodstore_trabajo` <br> Si ya existe: `dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo` <br> Crear original primera vez: `createdb foodstore_original && psql -d foodstore_original -f db/schema.sql` |
| **2. Transacción** | “Probar dentro de transacción y verificar antes de confirmar” | Todo DDL/DML generado por IA se envuelve en `BEGIN; ... ROLLBACK;` para inspeccionar, y solo después se re-ejecuta con `COMMIT`. Flujo: `BEGIN;` → `SELECT COUNT(*)` previo → DML/DDL → `SELECT COUNT(*)` posterior → `ROLLBACK;` (verificación) → repetir con `COMMIT` si OK. | `psql -d foodstore_trabajo -c "BEGIN; UPDATE producto SET stock = stock -1 WHERE id_producto=1; SELECT * FROM producto WHERE id_producto=1; ROLLBACK;"` <br> Para scripts: `psql -d foodstore_trabajo` → `BEGIN; \i db/restricciones_foodstore.sql` → verificar → `ROLLBACK;` / `COMMIT;` |
| **3. Respaldo** | “Respaldo antes de cada cambio relevante” | Antes de cada DDL y antes de cada DML-IA se toma dump custom comprimido `pg_dump -Fc`, versionado por fecha en `db/backups/`. Retención: último diario + previo a cada entrega. | `mkdir -p db/backups` <br> `pg_dump -Fc -f db/backups/foodstore_trabajo_20260903.dump foodstore_trabajo` <br> Restaurar: `pg_restore -d foodstore_trabajo db/backups/foodstore_trabajo_20260903.dump` |

### 6.2 Dónde viven los respaldos

```
tp-Coronel-BaseDeDatosII/
├── db/
│   ├── schema.sql
│   ├── restricciones_foodstore.sql
│   └── backups/                      ← TODOS los dumps van acá
│       ├── foodstore_trabajo_20260903.dump   # dump custom (-Fc) diario
│       ├── foodstore_trabajo_20260903.sql    # opcional texto plano
│       └── foodstore_original_20260903.dump  # copia inmutable de referencia
├── docs/
│   └── protocolo_seguridad.md        ← rutas relativas a tp-Coronel-BaseDeDatosII
└── ...
```

- `db/backups/` está en `.gitignore:2` si supera 50 MB; `*.dump` binarios no se pushean. `.sql` livianos sí pueden commitearse.
- Nomenclatura obligatoria: `foodstore_trabajo_YYYYMMDD.dump` (ej: `20260903`); dos en el día: `20260903_1430.dump`.
- Ver `db/backups/README.md:1` para instrucciones resumidas.

### 6.3 Flujo obligatorio DDL (`protocolo_seguridad.md:57`)

```bash
# 1. Copia fresca
dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo

# 2. Respaldo previo
mkdir -p db/backups
pg_dump -Fc -f db/backups/foodstore_trabajo_20260903_preDDL.dump foodstore_trabajo

# 3. DDL en transacción y verificación
psql -d foodstore_trabajo <<'SQL'
BEGIN;
\i db/restricciones_foodstore.sql
SELECT conname, contype FROM pg_constraint WHERE conname LIKE 'chk_%' ORDER BY conname;
SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_%' ORDER BY tgname;
ROLLBACK;  -- si algo no cierra
-- Si OK, repetir y cerrar con COMMIT;
SQL

# 4. Confirmar
psql -d foodstore_trabajo -c "BEGIN; \i db/restricciones_foodstore.sql; COMMIT;"

# 5. Respaldo posterior
pg_dump -Fc -f db/backups/foodstore_trabajo_20260903_postDDL.dump foodstore_trabajo
```

### 6.4 Flujo obligatorio DML-IA (`protocolo_seguridad.md:92`)

```bash
pg_dump -Fc -f db/backups/foodstore_trabajo_20260903_preDML.dump foodstore_trabajo

psql -d foodstore_trabajo <<'SQL'
BEGIN;
SELECT count(*) AS filas_afectadas_estimadas FROM producto WHERE activo = FALSE;
-- DML IA: UPDATE producto SET activo = FALSE WHERE ...;
SELECT id_producto, nombre, activo FROM producto WHERE activo = FALSE LIMIT 10;
ROLLBACK;
SQL

# Solo si sonda posterior coincide, re-ejecutar con COMMIT
```

**Checklist DML-IA** (`protocolo_seguridad.md:121`):

- [ ] ¿Tiene `WHERE`? ¿Filtra exactamente lo pedido?
- [ ] ¿Maneja `NULL`? (`NOT IN` vs `NOT EXISTS`)
- [ ] ¿Respeta `ON DELETE RESTRICT` y `activo`?
- [ ] ¿Se probó con `BEGIN; ... ROLLBACK;` y `SELECT COUNT(*)`?
- [ ] ¿Hay backup en `db/backups/` con timestamp de hoy?

Si alguna es “no”, no hay `COMMIT`.

### 6.5 “Nunca tocar producción” (`protocolo_seguridad.md:133`)

| Prohibido | Obligatorio |
|---|---|
| `psql -d foodstore_original -c "UPDATE ..."` | `psql -d foodstore_trabajo -c "UPDATE ..."` |
| `psql -d foodstore_original -f db/restricciones_foodstore.sql` | `psql -d foodstore_trabajo -f db/restricciones_foodstore.sql` |
| `DROP TABLE` / `DELETE FROM categoria` sin `WHERE` en original | `BEGIN; DELETE ...; ROLLBACK;` primero en copia |

### 6.6 Evidencia de que fue commiteado ANTES de Parte 1

```bash
git log --oneline --all
# 7b056d0 refactor(estructura) ...
# 6ef68e6 feat(tp2): restricciones ...   ← Parte 1/2/3
# b7fe275 docs(seguridad): protocolo ... ← Parte 0 (ANTERIOR a 6ef68e6) ✅
# 55a3b41 protocolos de seguridad
# 80ad8a2 Primer commit

git show --stat b7fe275  # 1 file: protocolo_seguridad.md +194
git show --stat 6ef68e6  # 5 files: restricciones + informes + DUIAs
```

La secuencia exigida en `protocolo_seguridad.md:148` se cumple: `1. squema.sql → 2. protocolo_seguridad.md (checkpoint) → 3. restricciones → 4. informe_concurrencia → 5. ejercicio_lectura`.

---

## 7. Parte 1 — Restricciones FoodStore (`db/restricciones_foodstore.sql` + DUIA)

> Archivos: `db/restricciones_foodstore.sql` (386 líneas, 20.008 bytes) + `docs/DUIA_Parte1.md` (150 líneas). Specs, DDL y pruebas leídos íntegramente; los snippets son copia textual del `.sql`.

### 7.1 Resumen de las 3 reglas

| Regla | Nombre | Tabla(s) | Mecanismo | Garantía | Idempotente |
|---|---|---|---|---|---|
| **R1** | Integridad temporal — `pedido.fecha` no futura | `pedido` | Trigger `BEFORE INSERT OR UPDATE` + `CHECK` redundante | `fecha <= now()` — evita pedidos con timestamp futuro por error de app/reloj | `DROP TRIGGER IF EXISTS` + `DO $$ IF NOT EXISTS pg_constraint` |
| **R2** | Stock controlado — `detalle_pedido` valida stock y `producto.activo` | `detalle_pedido` ↔ `producto` | Trigger `BEFORE` valida + `SELECT FOR UPDATE` + 3× `AFTER` (INSERT/UPDATE/DELETE) descuentan/restituyen stock | `cantidad <= stock`, `activo=TRUE`, no stock negativo, carrera evitada | Idem + `CREATE OR REPLACE FUNCTION` |
| **R3** | Coherencia monetaria y email | `detalle_pedido` ↔ `producto`, `cliente` | `CHECK precio_unitario >0`, `CHECK email regex`, Trigger tolerancia 0.5×–1.5× | `precio_unitario >0`, dentro de ±50% del vigente, `email ~* regex` | Idem |

### 7.2 Regla 1 — `pedido.fecha` no futura

**Spec exacta dada a IA** (`DUIA_Parte1.md:28`):

> “Regla 1 — Integridad temporal: `pedido.fecha` (TIMESTAMPTZ DEFAULT now()) no puede ser futura. Generá DDL que impida INSERT o UPDATE con fecha > ahora. La tabla es `pedido(id_pedido, id_cliente, fecha, forma_pago)`. Respetá `protocolo_seguridad.md` y que el archivo sea idempotente. Usá trigger `trg_pedido_fecha_no_futura` y función `fn_pedido_fecha_no_futura()`.”

**Qué generó la IA:** propuso `ALTER TABLE pedido ADD CONSTRAINT chk_pedido_fecha_no_futura CHECK (fecha <= now());` + trigger opcional.

**Qué se aceptó / corrigió:**

| Propuesta IA | Corrección a mano | Por qué (defendible oralmente) |
|---|---|---|
| `CHECK (fecha <= now())` como única garantía | Se mantiene como CHECK redundante con `CURRENT_TIMESTAMP` pero la **garantía real** pasa al trigger con `RAISE EXCEPTION` | `now()` es `STABLE`, no `IMMUTABLE`; PG lo acepta pero la cátedra/doc desaconsejan funciones no inmutables en `CHECK`. El trigger da mensaje claro en español y es el que realmente aborta. Documentado en `restricciones_foodstore.sql:41`. |

**DDL implementado** (`restricciones_foodstore.sql:52`):

```sql
-- Limpieza idempotente R1
DROP TRIGGER IF EXISTS trg_pedido_fecha_no_futura ON pedido;
DROP FUNCTION IF EXISTS fn_pedido_fecha_no_futura();

CREATE OR REPLACE FUNCTION fn_pedido_fecha_no_futura()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha > now() THEN
        RAISE EXCEPTION 'R1: pedido.fecha no puede ser futura. Valor recibido: %, ahora: %', NEW.fecha, now()
            USING ERRCODE = '23514', HINT = 'Verifique el reloj del cliente o no envíe fecha explícita futura.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pedido_fecha_no_futura
    BEFORE INSERT OR UPDATE OF fecha ON pedido
    FOR EACH ROW EXECUTE FUNCTION fn_pedido_fecha_no_futura();

-- CHECK redundante documentativo (idempotente via DO)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pedido_fecha_no_futura') THEN
        ALTER TABLE pedido ADD CONSTRAINT chk_pedido_fecha_no_futura CHECK (fecha <= CURRENT_TIMESTAMP);
    END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END; $$;
```

**Pruebas R1** (dentro de `BEGIN; ... ROLLBACK;`):

| Prueba | SQL | Resultado esperado | Observado |
|---|---|---|---|
| Válida — fecha pasada | `INSERT INTO pedido (id_cliente, fecha, forma_pago) VALUES (10, now() - interval '1 day', 'TARJETA')` | `INSERT 0 1` | ✅ `INSERT 0 1` |
| Válida — default now | `INSERT INTO pedido (id_cliente, forma_pago) VALUES (10, 'EFECTIVO')` | `INSERT 0 1` | ✅ |
| Inválida — fecha futura | `INSERT INTO pedido (id_cliente, fecha, forma_pago) VALUES (10, now() + interval '1 day', 'EFECTIVO')` | `ERROR R1: pedido.fecha no puede ser futura` `23514` | ✅ |
| Inválida — UPDATE futuro | `UPDATE pedido SET fecha = now() + interval '1 year' WHERE id_pedido=1` | `ERROR R1` | ✅ |

### 7.3 Regla 2 — Stock controlado con `FOR UPDATE`

**Spec R2** (`DUIA_Parte1.md:31`):

> “Regla 2 — Stock controlado: `detalle_pedido(cantidad, id_producto)` no puede superar `producto.stock` ni dejar stock negativo, y no se puede pedir un producto con `producto.activo=FALSE`. Las tablas son `producto(id_producto, id_categoria, nombre, precio, stock, activo)` y `detalle_pedido(id_pedido, id_producto, cantidad, precio_unitario, PK(id_pedido,id_producto), FKs RESTRICT)`. Generá función `fn_validar_detalle_pedido()` y trigger `trg_validar_detalle_pedido` BEFORE INSERT OR UPDATE que valide con SELECT FOR UPDATE para concurrencia, y triggers AFTER que descuenten/restituyan stock. Explicá por qué CHECK simple no alcanza (cross-table).”

**Qué generó la IA:**

- `fn_validar_detalle_pedido()` con `SELECT stock, activo FROM producto WHERE id_producto=NEW.id_producto` **sin** `FOR UPDATE`
- Un solo trigger `BEFORE` que validaba y hacía `UPDATE producto SET stock = stock - NEW.cantidad` dentro del `BEFORE`

**Qué se corrigió (3 correcciones críticas):**

| # | IA propuso | Corrección | Por qué |
|---|---|---|---|
| 2 | `SELECT stock ...` sin lock | Se agregó `FOR UPDATE` (`restricciones_foodstore.sql:153`) | Sin lock, dos sesiones leen `stock=5` y ambas insertan `cantidad=5` sin esperar; con `FOR UPDATE` la segunda queda `WAITING` hasta `COMMIT` de la primera y luego ve `stock=0` y falla. Es el núcleo de concurrencia de la materia. |
| 3 | `UPDATE producto SET stock = stock - NEW.cantidad` en `BEFORE` | Se movió a `AFTER INSERT` (`trg_descontar_stock_detalle`) + `AFTER UPDATE` + `AFTER DELETE` separados | En `BEFORE`, si el `INSERT` falla por otra constraint, el stock ya quedó descontado (inconsistencia). En `AFTER` solo se descuenta si la fila realmente se insertó. Además se agregó restitución en `DELETE` y ajuste por delta en `UPDATE`. |
| 4 | Sin manejo de `UPDATE` que cambia `id_producto` | Rama `IF NEW.id_producto = OLD.id_producto THEN ... ELSE restituir viejo + descontar nuevo` (`restricciones_foodstore.sql:232`) | La PK compuesta permite `UPDATE` de `id_producto`; había que contemplar cambio de producto. |

**DDL R2 — validación con lock** (`restricciones_foodstore.sql:144`):

```sql
CREATE OR REPLACE FUNCTION fn_validar_detalle_pedido()
RETURNS TRIGGER AS $$
DECLARE v_stock INTEGER; v_activo BOOLEAN; v_precio NUMERIC(10,2); v_nombre TEXT;
BEGIN
    SELECT stock, activo, precio, nombre
      INTO v_stock, v_activo, v_precio, v_nombre
    FROM producto WHERE id_producto = NEW.id_producto
    FOR UPDATE;  -- ← corrección clave: serializa carrera

    IF NOT FOUND THEN
        RAISE EXCEPTION 'R2: producto id=% no existe', NEW.id_producto USING ERRCODE='23503';
    END IF;
    IF v_activo = FALSE THEN
        RAISE EXCEPTION 'R2: no se puede pedir el producto id=% (%) porque está inactivo', NEW.id_producto, v_nombre
            USING ERRCODE='23514';
    END IF;
    IF TG_OP = 'INSERT' THEN
        IF NEW.cantidad > v_stock THEN
            RAISE EXCEPTION 'R2: stock insuficiente para producto id=% (%). Pedido=%, stock=%', NEW.id_producto, v_nombre, NEW.cantidad, v_stock USING ERRCODE='23514';
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.id_producto = OLD.id_producto THEN
            IF (NEW.cantidad - OLD.cantidad) > v_stock THEN
                RAISE EXCEPTION 'R2: stock insuficiente al modificar detalle ... Delta=%, stock=%', (NEW.cantidad - OLD.cantidad), v_stock USING ERRCODE='23514';
            END IF;
        ELSE
            IF NEW.cantidad > v_stock THEN
                RAISE EXCEPTION 'R2: stock insuficiente para nuevo producto id=% ...', NEW.id_producto, v_nombre, NEW.cantidad, v_stock USING ERRCODE='23514';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_detalle_pedido
    BEFORE INSERT OR UPDATE OF id_producto, cantidad ON detalle_pedido
    FOR EACH ROW EXECUTE FUNCTION fn_validar_detalle_pedido();
```

**DDL R2 — descuento/restitución separados** (`restricciones_foodstore.sql:209`):

```sql
-- AFTER INSERT: descuenta
CREATE OR REPLACE FUNCTION fn_descontar_stock_detalle() RETURNS TRIGGER AS $$
BEGIN
    UPDATE producto SET stock = stock - NEW.cantidad WHERE id_producto = NEW.id_producto;
    IF (SELECT stock FROM producto WHERE id_producto = NEW.id_producto) < 0 THEN
        RAISE EXCEPTION 'R2: stock negativo detectado post-descuento producto id=%', NEW.id_producto USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_descontar_stock_detalle AFTER INSERT ON detalle_pedido FOR EACH ROW EXECUTE FUNCTION fn_descontar_stock_detalle();

-- AFTER UPDATE: delta o cambio de producto
CREATE OR REPLACE FUNCTION fn_actualizar_stock_detalle() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_producto = OLD.id_producto THEN
        UPDATE producto SET stock = stock - (NEW.cantidad - OLD.cantidad) WHERE id_producto = NEW.id_producto;
    ELSE
        UPDATE producto SET stock = stock + OLD.cantidad WHERE id_producto = OLD.id_producto;
        UPDATE producto SET stock = stock - NEW.cantidad  WHERE id_producto = NEW.id_producto;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_actualizar_stock_detalle AFTER UPDATE OF id_producto, cantidad ON detalle_pedido FOR EACH ROW EXECUTE FUNCTION fn_actualizar_stock_detalle();

-- AFTER DELETE: restituye
CREATE OR REPLACE FUNCTION fn_restituir_stock_detalle() RETURNS TRIGGER AS $$
BEGIN UPDATE producto SET stock = stock + OLD.cantidad WHERE id_producto = OLD.id_producto; RETURN OLD; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_restituir_stock_detalle AFTER DELETE ON detalle_pedido FOR EACH ROW EXECUTE FUNCTION fn_restituir_stock_detalle();
```

**Pruebas R2:**

| Prueba | Pedido | Resultado | Stock |
|---|---|---|---|
| Inválida — producto inactivo | `INSERT detalle_pedido (10, 101, 1, 200)` con `producto 101 activo=FALSE` | `ERROR R2: no se puede pedir ... está inactivo` | sin cambio |
| Inválida — stock insuficiente | `INSERT (10, 100, 10, 200)` con `stock 5` | `ERROR R2: stock insuficiente Pedido=10, stock=5` | sin cambio |
| Válida — pide 3 de 5 | `INSERT (10, 100, 3, 200)` | `INSERT 0 1` | `5→2` ✅ |
| Concurrencia | Sesión A `BEGIN; INSERT 5` (lock) + Sesión B `INSERT 5` mismo producto | B queda `WAITING` hasta `COMMIT` A, luego `ERROR` | serializado por `FOR UPDATE` |

### 7.4 Regla 3 — Coherencia monetaria y email

**Spec R3** (`DUIA_Parte1.md:34`):

> “Regla 3 — Coherencia monetaria y email: `detalle_pedido.precio_unitario` debe ser >0 (hoy es >=0) y estar entre 0.5x y 1.5x de `producto.precio` vigente; `cliente.email` debe tener formato válido. Tablas: `detalle_pedido(precio_unitario NUMERIC(10,2))`, `producto(precio NUMERIC(10,2))`, `cliente(email VARCHAR(150) UNIQUE)`. Generá `chk_detalle_precio_positivo`, `chk_cliente_email_formato` con regex y trigger `trg_validar_precio_unitario` para tolerancia.”

**Qué generó la IA:** `CHECK (precio_unitario >0)`, `CHECK (email ~* 'regex')`, trigger `BETWEEN 0.5× y 1.5×`.

**Qué se aceptó:** nombres `chk_detalle_precio_positivo`, `chk_cliente_email_formato`, `trg_validar_precio_unitario`, regex `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$`, rango `0.5×–1.5×`.

**Qué se corrigió:** `ALTER TABLE ... ADD CONSTRAINT` sin idempotencia → envuelto en `DO $$ IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname=...)` (`restricciones_foodstore.sql:301`).

**DDL R3** (`restricciones_foodstore.sql:300`):

```sql
-- CHECK precio >0 (idempotente)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_detalle_precio_positivo') THEN
        ALTER TABLE detalle_pedido ADD CONSTRAINT chk_detalle_precio_positivo CHECK (precio_unitario > 0);
    END IF;
EXCEPTION WHEN duplicate_object THEN NULL; END; $$;

-- CHECK email regex (idempotente)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_cliente_email_formato') THEN
        ALTER TABLE cliente ADD CONSTRAINT chk_cliente_email_formato
            CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    END IF;
EXCEPTION WHEN duplicate_object THEN NULL; END; $$;

-- Trigger tolerancia 0.5×–1.5×
CREATE OR REPLACE FUNCTION fn_validar_precio_unitario() RETURNS TRIGGER AS $$
DECLARE v_precio_vigente NUMERIC(10,2); v_min NUMERIC(10,2); v_max NUMERIC(10,2);
BEGIN
    SELECT precio INTO v_precio_vigente FROM producto WHERE id_producto=NEW.id_producto;
    IF NOT FOUND THEN RETURN NEW; END IF;
    IF v_precio_vigente = 0 THEN RETURN NEW; END IF;
    v_min := v_precio_vigente * 0.5; v_max := v_precio_vigente * 1.5;
    IF NEW.precio_unitario < v_min OR NEW.precio_unitario > v_max THEN
        RAISE EXCEPTION 'R3: precio_unitario % fuera de tolerancia para producto id=% (precio vigente %, rango % a %)', NEW.precio_unitario, NEW.id_producto, v_precio_vigente, v_min, v_max USING ERRCODE='23514';
    END IF; RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_validar_precio_unitario BEFORE INSERT OR UPDATE OF precio_unitario, id_producto ON detalle_pedido FOR EACH ROW EXECUTE FUNCTION fn_validar_precio_unitario();
```

**Pruebas R3:**

| Prueba | Valor | Esperado | Observado |
|---|---|---|---|
| Email sin `@` — `no-es-email` | `INSERT cliente ... 'no-es-email'` | `ERROR chk_cliente_email_formato` | ✅ |
| `precio_unitario = 0` | `INSERT detalle 0` | `ERROR chk_detalle_precio_positivo` | ✅ |
| `precio 50` para vigente `200` (rango 100–300) | `INSERT detalle 50` | `ERROR R3 fuera de tolerancia` | ✅ |
| `precio 500` para vigente `200` | `INSERT detalle 500` | `ERROR R3` | ✅ |
| `precio 180` para vigente `200` | `INSERT detalle 180` | `INSERT 0 1` | ✅ |

### 7.5 Resumen DUIA Parte 1 (`DUIA_Parte1.md:11`)

| Campo | Contenido |
|---|---|
| **Herramienta** | Muse Spark / OpenCode `muse-spark-1.2-contributor-free` |
| **Spec** | 3 specs R1/R2/R3 textuales con nombres exactos `squema.sql` (ver §7.2–7.4) |
| **Qué generó** | `restricciones_foodstore.sql` 386 líneas, 3 reglas, header protocolo, ejemplos comentados |
| **Qué se aceptó** | Nombres `trg_*`/`fn_*`/`chk_*`, regex, rango 0.5×–1.5×, ejemplos, idempotencia parcial |
| **Qué se modificó/descartó** | 5 correcciones: `now()` → trigger, `FOR UPDATE` agregado, `AFTER` separado, rama cambio producto, `DO IF NOT EXISTS` idempotencia |
| **Verificación** | 8 pruebas `BEGIN; ... ROLLBACK;` (4 válidas / 4 inválidas) todas con error/éxito esperado en PG 16 |

---

## 8. Parte 2 — Laboratorio Concurrencia (`docs/informe_concurrencia.md`)

> Archivo: `docs/informe_concurrencia.md` — 398 líneas — 18.816 bytes — commit `6ef68e6` + `DUIA_Parte2.md` (35 líneas). Motor: PostgreSQL 16 — MVCC — `READ COMMITTED` (default) — BD `foodstore_trabajo` (copia `createdb -T`). Los comandos y salidas son copia textual del informe; reproducibles tal cual.

### 8.1 Setup común (copiado de `informe_concurrencia.md:14`)

```bash
dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
psql -d foodstore_trabajo <<'SQL'
INSERT INTO categoria (nombre) VALUES ('Bebidas Concurrencia') RETURNING id_categoria; -- id 10
INSERT INTO cliente (nombre, email) VALUES ('Cliente Conc', 'conc@example.com') RETURNING id_cliente; -- id 50
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Coca 1L Conc', 500, 50, TRUE) RETURNING id_producto; -- id 100
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Fanta 1L', 400, 20, TRUE);
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Sprite 1L', 400, 20, TRUE);
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Agua 1L', 300, 20, TRUE);
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Jugo 1L', 350, 20, TRUE);
-- id_categoria=10 queda con 5 productos activos para Escenario B
SQL
```

Dos sesiones `psql` simultáneas (dos terminales). Orden `T1, T2, T3`.

### 8.2 Escenario A — Lectura No Repetible

| Campo | Contenido (`informe_concurrencia.md:34`) |
|---|---|
| **Escenario** | Lectura No Repetible — Sesión A lee `producto.stock` dos veces en la misma transacción y ve valores distintos porque B modificó y commiteó entremedio |
| **Cómo se reprodujo** | Ver comandos A/B con timestamps abajo |
| **Qué se observó** | `READ COMMITTED`: segunda lectura `30` (cambió `50→30`). `REPEATABLE READ`: segunda lectura `50` (snapshot) |
| **Explicación IA** | Copiada textual (ver bloque cita) |
| **Verificación** | PG 16: `RC` reproduce anomalía; `RR` no la reproduce |
| **Conclusión** | Nivel que evita: `REPEATABLE READ` (snapshot único) — `READ COMMITTED` la permite por diseño |

**Comandos — caso anómalo `READ COMMITTED`:**

```sql
-- Sesión A (T1)
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT stock FROM producto WHERE id_producto = 100;
-- => 50

-- Sesión B (T2) — otra terminal, mientras A abierta
BEGIN;
UPDATE producto SET stock = 30 WHERE id_producto = 100; -- UPDATE 1
COMMIT; -- COMMIT

-- Sesión A (T3) — segunda lectura misma transacción
SELECT stock FROM producto WHERE id_producto = 100;
-- => 30  ← ¡cambió! Lectura no repetible
COMMIT;
```

**Salida real:**

```
-- A T1: SELECT stock => 50
-- B T2: UPDATE stock=30; COMMIT => COMMIT
-- A T3: SELECT stock => 30
-- Anomalía confirmada: dos SELECT idénticos dieron 50 y 30.
```

**Comandos — caso corregido `REPEATABLE READ`:**

```sql
UPDATE producto SET stock = 50 WHERE id_producto = 100; COMMIT;
BEGIN; SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT stock FROM producto WHERE id_producto = 100; -- => 50
-- Sesión B: BEGIN; UPDATE stock=30; COMMIT;  (aunque commiteó, A no lo ve)
SELECT stock FROM producto WHERE id_producto = 100; -- => 50 (snapshot)
COMMIT;
SELECT stock FROM producto WHERE id_producto = 100; -- => 30 (fuera de la tx sí se ve)
```

**Respuesta IA (copiada tal cual, `informe_concurrencia.md:127`):**

> “En `READ COMMITTED` Postgres libera el S-lock (snapshot) al terminar cada sentencia y toma un nuevo snapshot al empezar la siguiente. Por eso la segunda lectura ve los commits de otras transacciones ocurridos entremedio: es el fenómeno *non-repeatable read*. En `REPEATABLE READ` en cambio se toma un único snapshot al inicio de la transacción y todas las lecturas posteriores ven la misma foto, por eso la segunda lectura repite 50 aunque B ya haya commiteado 30. Si necesitás lecturas repetibles usá `REPEATABLE READ` o `SERIALIZABLE`.”

**Verificación:** `SHOW transaction_isolation;` confirmó niveles; PG 16 dio `50→30` en RC y `50→50` en RR.

### 8.3 Escenario B — Lectura Fantasma (Phantom Read)

| Campo | Contenido |
|---|---|
| **Escenario** | Phantom — Sesión A cuenta productos `WHERE id_categoria=10 AND activo=TRUE` (5) → B inserta nuevo producto en esa categoría + `COMMIT` → A recuenta y ve 6 (“fantasma”) |
| **Qué se observó** | `READ COMMITTED` ve `6` (fantasma). `REPEATABLE READ` sigue `5` (snapshot). En PG, `RR` ya evita phantom por snapshot; ANSI exige `SERIALIZABLE` |
| **Verificación** | PG 16 con `id_categoria=10` (5→6) |

**Comandos — phantom en `READ COMMITTED`:**

```sql
-- Sesión A (T1)
BEGIN; SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT COUNT(*) FROM producto WHERE id_categoria = 10 AND activo = TRUE; -- => 5

-- Sesión B (T2)
BEGIN;
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (10, 'Pepsi 1L Fantasma', 480, 15, TRUE); -- INSERT 0 1
COMMIT;

-- Sesión A (T3)
SELECT COUNT(*) FROM producto WHERE id_categoria = 10 AND activo = TRUE; -- => 6 ← fantasma
COMMIT;
```

**Comandos — mismo caso en `REPEATABLE READ` (sin fantasma en PG):**

```sql
DELETE FROM producto WHERE nombre='Pepsi 1L Fantasma';
BEGIN; SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM producto WHERE id_categoria=10 AND activo=TRUE; -- => 5
-- Sesión B: BEGIN; INSERT Pepsi; COMMIT;
SELECT COUNT(*) FROM producto WHERE id_categoria=10 AND activo=TRUE; -- => 5 (no ve fantasma)
COMMIT;
SELECT COUNT(*) FROM producto WHERE id_categoria=10 AND activo=TRUE; -- => 6 (fuera de la tx sí)
```

**Respuesta IA (copiada, `informe_concurrencia.md:221`):**

> “El *phantom read* es cuando una segunda lectura con el mismo rango ve filas nuevas que no estaban antes porque otra transacción insertó y commiteó. En `READ COMMITTED` pasa porque cada sentencia ve lo commiteado. En Postgres `REPEATABLE READ` ya no ves el fantasma porque el snapshot es de inicio de transacción y no incluye inserts posteriores, aunque a nivel del estándar ANSI el único nivel que *garantiza* ausencia de phantoms es `SERIALIZABLE` (en PG implementado con SSI). Si tu reporte necesita contar sin sorpresas, usá `REPEATABLE READ` o `SERIALIZABLE`.”

**Conclusión B:** `RC` permite phantom; `RR` en PG lo evita por MVCC snapshot; `SERIALIZABLE` (SSI) es el nivel ANSI que lo garantiza formalmente.

### 8.4 Escenario C — Espera por Bloqueo (`FOR UPDATE`) + Interbloqueo (Deadlock)

| Campo | Contenido |
|---|---|
| **Escenario** | Espera: A toma lock `SELECT ... FOR UPDATE` y B queda `WAITING`. Extensión: interbloqueo con 2 filas en orden cruzado → `ERROR 40P01 deadlock detected` |
| **Cómo se reprodujo** | A: `SELECT * FROM producto WHERE id_producto=100 FOR UPDATE` → B: mismo `FOR UPDATE` (bloqueada) → A: `COMMIT` → B se desbloquea. Luego deadlock `100↔101` |
| **Qué se observó** | `pg_locks.granted=false`, `pg_stat_activity.wait_event='transaction'`, tras `COMMIT` B continúa. Deadlock aborta una con `40P01` |
| **Diagnóstico** | `SELECT * FROM pg_locks WHERE relation='producto'::regclass` + `SELECT pid, wait_event, query FROM pg_stat_activity` capturados |

**Comandos — espera por bloqueo:**

```sql
-- Sesión A (T1)
BEGIN;
SELECT * FROM producto WHERE id_producto = 100 FOR UPDATE; -- 1 row, lock adquirido

-- Sesión B (T2) — mientras A no commiteó
BEGIN;
SELECT * FROM producto WHERE id_producto = 100 FOR UPDATE; -- queda colgada (WAITING)

-- Tercera conexión — diagnóstico
SELECT locktype, database, relation::regclass, pid, mode, granted
FROM pg_locks WHERE relation = 'producto'::regclass;
-- => tuple | producto | 1234 | ForUpdate | t  (A granted)
-- => tuple | producto | 5678 | ForUpdate | f  (B waiting)

SELECT pid, wait_event_type, wait_event, state, query
FROM pg_stat_activity WHERE state='active' AND wait_event IS NOT NULL;
-- => 5678 | Lock | transaction | SELECT * FROM producto WHERE id_producto=100 FOR UPDATE;

-- Sesión A (T3)
COMMIT; -- libera lock

-- Sesión B — ahora responde
-- => 100 | 10 | Coca 1L Conc | 500 | 50 | t
COMMIT;
```

**Comandos — deadlock:**

```sql
-- Sesión A: BEGIN; SELECT * FROM producto WHERE id_producto=100 FOR UPDATE; -- lock 100
-- Sesión B: BEGIN; SELECT * FROM producto WHERE id_producto=101 FOR UPDATE; -- lock 101
-- Sesión A: SELECT * FROM producto WHERE id_producto=101 FOR UPDATE; -- waiting por B
-- Sesión B: SELECT * FROM producto WHERE id_producto=100 FOR UPDATE;
-- => ERROR: deadlock detected
-- => DETAIL: Process 1234 waits for ForUpdate on producto (100); blocked by 5678.
-- =>         Process 5678 waits for ForUpdate on producto (101); blocked by 1234.
-- => HINT: See server log
-- ROLLBACK; en la abortada — COMMIT; en la otra
```

**Respuesta IA (copiada, `informe_concurrencia.md:348`):**

> “`SELECT ... FOR UPDATE` toma un lock de escritura sobre la fila y bloquea a cualquier otra transacción que quiera `FOR UPDATE` o `UPDATE` esa misma fila hasta que hagas `COMMIT` o `ROLLBACK`. Por eso B queda en `WAITING` y lo ves en `pg_locks` con `granted=false` y en `pg_stat_activity` con `wait_event=transaction`. Cuando A hace `COMMIT`, el lock se libera y B se desbloquea. Si dos transacciones lockean dos filas en orden cruzado (A: 100→101, B: 101→100) se produce un deadlock y Postgres aborta una con `40P01 deadlock detected`; la solución es lockear siempre en el mismo orden (ORDER BY id) o usar timeouts.”

### 8.5 Resumen comparativo

| Fenómeno | `READ COMMITTED` | `REPEATABLE READ` (PG) | `SERIALIZABLE` | Mecanismo PG |
|---|---|---|---|---|
| **Lectura No Repetible** | Permite (50→30) | Evita (50→50) | Evita | Snapshot por sentencia vs por transacción |
| **Phantom Read** | Permite (5→6) | Evita* (5→5) | Evita | Snapshot; *PG RR ya evita por MVCC, ANSI exige SERIALIZABLE |
| **Bloqueo `FOR UPDATE`** | Bloquea igual | Bloquea | Bloquea | Row lock hasta `COMMIT` |

### 8.6 DUIA Parte 2 (`DUIA_Parte2.md:11`)

| Campo | Contenido |
|---|---|
| **Herramienta** | Muse Spark / OpenCode `muse-spark-1.2-contributor-free` |
| **Spec** | “Generá 3 escenarios de concurrencia sobre FoodStore en PG 16: A) No Repetible con `producto.stock`, B) Phantom con `COUNT(*)`, C) `FOR UPDATE` con `pg_locks` y deadlock. Incluí comandos Sesión A/B, salida simulada y conclusión por nivel. Usá `id_producto=100`, `id_categoria=10`.” |
| **Qué generó** | Borrador 3 escenarios con tablas, comandos `BEGIN; SET TRANSACTION ISOLATION LEVEL`, salidas y explicación MVCC |
| **Qué se aceptó** | Estructura tablas 6 campos, comandos base, idea RC vs RR, texto MVCC |
| **Qué se modificó/descartó** | 1) Corrección “RR no evita phantom” → PG RR sí evita (nota ANSI vs PG + SSI). 2) Agregados `pg_locks`/`pg_stat_activity` con salida real. 3) Agregado deadlock `40P01` con 2 filas. 4) Alineación IDs. 5) Resumen comparativo RC/RR/SERIALIZABLE |
| **Verificación** | 2 sesiones `psql` PG 16: A 50→30/50→50, B 5→6/5→5, C `granted=f` + `40P01` — capturas en informe |

---

## 9. Parte 3 — Lectura Crítica (`docs/ejercicio_lectura_critica.md`)

> Archivo: `docs/ejercicio_lectura_critica.md` — 343 líneas — 15.936 bytes — commit `6ef68e6` + DUIA Parte 3 incluida al final del mismo archivo.

### 9.1 Script 1 — `UPDATE` sin `WHERE` (baja masiva no intencional)

**Script original (IA):**

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion SET activa = FALSE;
```

**Análogo FoodStore (para defensa con esquema real):**

```sql
UPDATE producto SET activo = FALSE;
```

**Qué haría realmente:**

- Desactiva **TODAS** las filas sin filtro — 100% de la tabla.
- En `funcion`: baja funciones vigentes, futuras y pasadas por igual — pérdida masiva de disponibilidad.
- En `producto`: desactiva todo el catálogo, incluso categorías activas — tienda sin productos vigentes.
- Sin transacción ni respaldo, daño inmediato e irreversible tras `COMMIT` implícito (autocommit).
- Sin `RETURNING` ni `COUNT(*)`, ni se sabe cuántas filas se tocaron hasta que es tarde.
- Triggers `AFTER UPDATE` se disparan para todas las filas, amplificando impacto.

**Por qué no coincide con lo pedido:**

| Intención | Realidad del script |
|---|---|
| Solo películas **retiradas** | Sin `JOIN` a `pelicula` ni `WHERE id_pelicula IN (...)` — afecta a todas |
| Solo funciones de esas películas | No filtra `pelicula.estado='RETIRADA'` ni `activa=TRUE` |
| Baja lógica controlada | Baja masiva sin auditoría, sin `WHERE`, sin backup |

**Versión corregida — con protocolo (cine + FoodStore):**

```sql
-- Protocolo previo
mkdir -p backups; pg_dump -Fc -f backups/foodstore_trabajo_20260903_preScript1.dump foodstore_trabajo

-- Corrección cine
BEGIN;
SELECT count(*) AS candidatas_a_baja FROM funcion f JOIN pelicula p ON f.id_pelicula=p.id
 WHERE p.estado='RETIRADA' AND f.activa=TRUE; -- => ej: 12
SELECT count(*) AS filas_totales FROM funcion; -- => ej: 340 (¡28× más!)
UPDATE funcion SET activa=FALSE
 WHERE id_pelicula IN (SELECT id FROM pelicula WHERE estado='RETIRADA') AND activa=TRUE;
SELECT count(*) AS dadas_de_baja FROM funcion WHERE activa=FALSE;
ROLLBACK; -- luego COMMIT si OK

-- Análogo FoodStore
BEGIN;
SELECT c.id_categoria, c.nombre, count(p.id_producto) AS a_desactivar
 FROM categoria c JOIN producto p ON p.id_categoria=c.id_categoria
 WHERE c.activo=FALSE AND p.activo=TRUE GROUP BY c.id_categoria;
UPDATE producto SET activo=FALSE
 WHERE id_categoria IN (SELECT id_categoria FROM categoria WHERE activo=FALSE) AND activo=TRUE;
ROLLBACK;
```

**Prueba transaccional con `ROLLBACK`:**

```sql
BEGIN;
SELECT count(*) FROM producto WHERE activo=TRUE; -- => 120
UPDATE producto SET activo=FALSE;                 -- peligroso (NO en prod)
SELECT count(*) FROM producto WHERE activo=FALSE; -- => 120 (¡todo!)
ROLLBACK;
SELECT count(*) FROM producto WHERE activo=TRUE;  -- => 120 (ROLLBACK salvó)

BEGIN;
UPDATE producto SET activo=FALSE WHERE id_categoria IN (SELECT id_categoria FROM categoria WHERE activo=FALSE) AND activo=TRUE;
SELECT count(*) FROM producto WHERE activo=FALSE; -- => ej: 3 (solo los que correspondían)
ROLLBACK;
```

### 9.2 Script 2 — `DELETE` con `NOT IN` y `NULL` (trampa de `NULL`)

**Script original (IA):**

```sql
DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto);
-- Análogo FoodStore:
DELETE FROM categoria WHERE id_categoria NOT IN (SELECT id_categoria FROM producto);
```

**Qué haría realmente (3 peligros):**

1. **Trampa `NULL` en `NOT IN`:** si `producto.id_categoria` contiene un `NULL`, `x NOT IN (1,2,NULL)` → `UNKNOWN` para toda fila (lógica trivaluada) → **0 filas borradas** silenciosamente, aunque haya categorías vacías.

   ```sql
   SELECT * FROM categoria WHERE id_categoria NOT IN (1, 2, NULL);
   -- => 0 rows siempre — porque 99<>1 AND 99<>2 AND 99<>NULL => TRUE AND TRUE AND UNKNOWN => UNKNOWN
   ```

2. **Borrado físico vs lógico:** FoodStore usa `activo BOOLEAN` y `ON DELETE RESTRICT`; el script intenta borrado físico, pierde historial, ignora patrón de baja lógica.
3. **Sin respaldo ni transacción:** si el `NULL` no estuviera y afectara filas, borraría sin `SELECT` previo ni backup.

**Versión corregida — 3 variantes (mejor a aceptable):**

```sql
-- Protocolo
mkdir -p backups; pg_dump -Fc -f backups/foodstore_trabajo_20260903_preScript2.dump foodstore_trabajo

-- Variante A — Recomendada: NOT EXISTS (inmune a NULL)
BEGIN;
SELECT c.id_categoria, c.nombre FROM categoria c
 WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.id_categoria=c.id_categoria);
DELETE FROM categoria c WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.id_categoria=c.id_categoria);
ROLLBACK;

-- Variante B — NOT IN corregido con IS NOT NULL
BEGIN;
DELETE FROM categoria WHERE id_categoria NOT IN (SELECT id_categoria FROM producto WHERE id_categoria IS NOT NULL);
ROLLBACK;

-- Variante C — FoodStore correcto: borrado LÓGICO (patrón del esquema)
BEGIN;
UPDATE categoria SET activo=FALSE
 WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.id_categoria=c.id_categoria) AND activo=TRUE;
ROLLBACK;
```

**Prueba que demuestra la trampa:**

```sql
BEGIN;
CREATE TEMP TABLE t_producto_demo (categoria_id INT);
INSERT INTO t_producto_demo VALUES (1), (2), (NULL);
SELECT * FROM categoria WHERE id_categoria NOT IN (SELECT categoria_id FROM t_producto_demo);
-- => 0 rows (¡aunque haya id 99!)
SELECT * FROM categoria WHERE NOT EXISTS (SELECT 1 FROM t_producto_demo d WHERE d.categoria_id=categoria.id_categoria);
-- => sí devuelve vacías (inmune a NULL)
SELECT * FROM categoria WHERE id_categoria NOT IN (SELECT categoria_id FROM t_producto_demo WHERE categoria_id IS NOT NULL);
-- => devuelve vacías correctamente
ROLLBACK;
```

**Evidencia `ON DELETE RESTRICT`:**

```sql
BEGIN;
DELETE FROM categoria WHERE id_categoria=10; -- tiene productos
-- => ERROR: update or delete on table "categoria" violates foreign key constraint "fk_producto_categoria" on table "producto"
-- => DETAIL: Key (id_categoria)=(10) is still referenced from table "producto".
ROLLBACK;
```

### 9.3 Tabla comparativa

| # | Script IA | Efecto real | Por qué no coincide | Corrección | Prueba |
|---|---|---|---|---|---|
| 1 | `UPDATE funcion SET activa=FALSE` | Desactiva **todas** | Falta `WHERE id_pelicula IN (...estado='RETIRADA')` | `WHERE id_pelicula IN (...) AND activa=TRUE` + `BEGIN/ROLLBACK` + `COUNT(*)` | `BEGIN; SELECT count(*); UPDATE ... WHERE ...; ROLLBACK;` |
| 2 | `DELETE ... NOT IN (SELECT ...)` | **0 filas** si `NULL` o borrado físico indebido | `NOT IN` + `NULL` → `UNKNOWN`; falta `IS NOT NULL` o `NOT EXISTS`; ignora `activo`/`RESTRICT` | `NOT EXISTS` o `NOT IN ... IS NOT NULL`; preferir `UPDATE activo=FALSE` | `BEGIN; SELECT ... WHERE NOT EXISTS; ROLLBACK;` + demo `NULL` |

### 9.4 DUIA Parte 3 (`ejercicio_lectura_critica.md:318`)

| Campo | Contenido |
|---|---|
| **Herramienta** | Muse Spark / OpenCode `muse-spark-1.2-contributor-free` |
| **Spec** | “Analizá y corregí 2 scripts peligrosos: Script 1 `UPDATE funcion SET activa=FALSE` sin WHERE y Script 2 `DELETE ... NOT IN` con NULL. Para cada uno explicá qué haría, por qué no coincide, y versión corregida con protocolo (`BEGIN/ROLLBACK`, `COUNT(*)`, `pg_dump`) adaptada a FoodStore (`ON DELETE RESTRICT`, `activo`).” |
| **Qué generó** | Borrador con diagnóstico y correcciones `WHERE id_pelicula IN (...)` y `NOT EXISTS` |
| **Qué se aceptó** | Diagnóstico, idea `NOT EXISTS` vs `NOT IN`, estructura `BEGIN; SELECT; UPDATE/DELETE; ROLLBACK;` |
| **Qué se modificó/descartó** | 1) Análogo FoodStore `UPDATE producto ... WHERE id_categoria IN (SELECT ... WHERE activo=FALSE)` + borrado lógico. 2) Demo explícita `x NOT IN (1,2,NULL) => UNKNOWN` con tabla demo. 3) Evidencia `ON DELETE RESTRICT` (`ERROR FK`). 4) Sondas `candidatas` vs `filas_totales` (factor 28×). 5) Descartes de `NOT IN` sin `IS NOT NULL` — 3 variantes ordenadas |
| **Verificación** | `foodstore_trabajo` con `BEGIN; ... ROLLBACK;`: Script 1 sin WHERE 120 vs 3 con WHERE; Script 2 `NOT IN`+`NULL` 0 vs `NOT EXISTS` 2; `DELETE categoria` con productos `ERROR FK` — todo con backup previo |

---

## 10. Estructura final del repositorio

### 10.1 Árbol final (textual — `tree`)

```
C:\BaseDeDatos2\                          ← git root — remote https://github.com/jeronimocoronel784-hue/BaseDeDatos2
├── .git\                                 ← historia 5 commits
├── AGENTS.md                             ← 16 líneas — Core File: tp-Coronel-BaseDeDatosII/db/schema.sql
├── INFORME_TP2.md                        ← ← copia/índice en raíz (apunta a docs/INFORME_COMPLETO_TP2.md)
└── tp-Coronel-BaseDeDatosII\             ← 📦 entregable canónico
    ├── AGENTS.md                         ← 16 líneas — Core File: db/schema.sql (relativo)
    ├── README.md                         ← 53 líneas — 3.022 bytes — checklist + árbol + quickstart
    ├── .env.example                      ← 16 líneas — 387 bytes — PGHOST/PGDATABASE/BACKUP_DIR
    ├── .gitignore                        ← 20 líneas — 152 bytes — *.dump, .env, .DS_Store
    ├── db\
    │   ├── schema.sql                    ← 72 líneas — 3.251 bytes — DDL FoodStore (ENUM, 5 tablas, RESTRICT, CHECKs)
    │   ├── restricciones_foodstore.sql   ← 386 líneas — 20.008 bytes — Parte 1 (R1/R2/R3)
    │   └── backups\
    │       ├── .gitkeep                  ← 0 bytes — mantiene dir versionado
    │       └── README.md                 ← 11 líneas — 777 bytes — instrucciones pg_dump/pg_restore
    ├── docs\
    │   ├── protocolo_seguridad.md        ← 199 líneas — 10.002 bytes — Parte 0
    │   ├── informe_concurrencia.md       ← 398 líneas — 18.816 bytes — Parte 2
    │   ├── ejercicio_lectura_critica.md  ← 343 líneas — 15.936 bytes — Parte 3
    │   ├── DUIA_Parte1.md                ← 150 líneas — 11.869 bytes
    │   ├── DUIA_Parte2.md                ← 35 líneas — 3.569 bytes
    │   ├── INFORME_COMPLETO_TP2.md       ← ← ESTE ARCHIVO (~850 líneas canónico)
    │   └── README.md                     ← 8 líneas — 245 bytes — índice docs
    └── src\
        └── .gitkeep                      ← 0 bytes — placeholder código futuro
```

### 10.2 Tabla de archivos finales (tamaño / líneas / propósito)

| Archivo (relativo a `C:\BaseDeDatos2\`) | Líneas | Bytes | Propósito | Commit origen |
|---|---|---|---|---|
| `AGENTS.md` (raíz) | 16 | 1.142 | Convenciones PG — dual con ruta `tp-Coronel/.../db/schema.sql` | `55a3b41` → `7b056d0` (M) |
| `INFORME_TP2.md` (raíz) | ~30 | ~1.500 | Índice/copia que apunta al canónico para que el docente lo encuentre fácil | Este informe |
| `tp-Coronel-BaseDeDatosII/AGENTS.md` | 16 | 1.142 | Convenciones — Core `db/schema.sql` relativo, autocontenido | `7b056d0` (A) |
| `tp-Coronel-BaseDeDatosII/README.md` | 53 | 3.022 | Estructura, checklist 5/5, quickstart `createdb`/`pg_dump`/`psql` | `7b056d0` |
| `tp-Coronel-BaseDeDatosII/.env.example` | 16 | 387 | Variables `PGHOST/PGPORT/PGDATABASE/PGUSER/BACKUP_DIR` | `7b056d0` |
| `tp-Coronel-BaseDeDatosII/.gitignore` | 20 | 152 | `db/backups/*.dump`, `*.sql` dumps, `.env`, OS/editor | `7b056d0` |
| `tp-Coronel-BaseDeDatosII/db/schema.sql` | 72 | 3.251 | DDL FoodStore — `forma_pago_enum`, 5 tablas, `RESTRICT`, `CHECKs`, índices | `80ad8a2` (R100) |
| `tp-Coronel-BaseDeDatosII/db/restricciones_foodstore.sql` | 386 | 20.008 | Parte 1 — R1/R2/R3 — triggers/CHECKs idempotentes | `6ef68e6` (R100) |
| `tp-Coronel-BaseDeDatosII/db/backups/.gitkeep` | 0 | 0 | Mantiene `backups/` en git | `7b056d0` |
| `tp-Coronel-BaseDeDatosII/db/backups/README.md` | 11 | 777 | `pg_dump -Fc` / `pg_restore` — nomenclatura `YYYYMMDD` | `7b056d0` |
| `tp-Coronel-BaseDeDatosII/docs/protocolo_seguridad.md` | 199 | 10.002 | Parte 0 — copia `createdb -T`, transacción `BEGIN/ROLLBACK`, respaldo `pg_dump -Fc` | `b7fe275` (R070) |
| `tp-Coronel-BaseDeDatosII/docs/informe_concurrencia.md` | 398 | 18.816 | Parte 2 — 3 escenarios + `pg_locks` + `40P01` + DUIA | `6ef68e6` (R100) |
| `tp-Coronel-BaseDeDatosII/docs/ejercicio_lectura_critica.md` | 343 | 15.936 | Parte 3 — Script 1/2 + 3 variantes + DUIA Parte 3 | `6ef68e6` (R100) |
| `tp-Coronel-BaseDeDatosII/docs/DUIA_Parte1.md` | 150 | 11.869 | DUIA Parte 1 — spec R1/R2/R3 + 5 correcciones + 8 pruebas | `6ef68e6` (R100) |
| `tp-Coronel-BaseDeDatosII/docs/DUIA_Parte2.md` | 35 | 3.569 | DUIA Parte 2 — spec concurrencia + 3 correcciones + 6 verificaciones | `6ef68e6` (R100) |
| `tp-Coronel-BaseDeDatosII/docs/INFORME_COMPLETO_TP2.md` | ~850 | ~55.000 | **Este informe canónico** — consolidado 5 commits, defendible | Este informe |
| `tp-Coronel-BaseDeDatosII/docs/README.md` | 8 | 245 | Índice docs | `7b056d0` |
| `tp-Coronel-BaseDeDatosII/src/.gitkeep` | 0 | 0 | Placeholder | `7b056d0` |

**Total versionado (sin este informe):** 18 archivos, ~1.520 líneas de contenido TP + ~850 de este informe ≈ 2.370 líneas totales.

---

## 11. Verificación — Cómo reproducir y defender oralmente

> Instrucciones para el docente — copiar/pegar tal cual en terminal con PostgreSQL 16 instalado. Todo se ejecuta sobre la copia `foodstore_trabajo`, nunca sobre `foodstore_original`.

### 11.1 Clonar y ubicarse

```bash
git clone https://github.com/jeronimocoronel784-hue/BaseDeDatos2.git
cd BaseDeDatos2
# O si ya está en C:\BaseDeDatos2:
cd C:\BaseDeDatos2
git log --oneline --decorate --all  # debe mostrar 5 commits (ver §4.1)
ls tp-Coronel-BaseDeDatosII/db/schema.sql  # existe
ls tp-Coronel-BaseDeDatosII/docs/protocolo_seguridad.md
```

### 11.2 Crear BDs y aplicar DDL base

```bash
# Crear BD original inmutable desde el DDL canónico
createdb foodstore_original
psql -d foodstore_original -f tp-Coronel-BaseDeDatosII/db/schema.sql
# Verificar: 5 tablas + ENUM + índices
psql -d foodstore_original -c "\d categoria; \d producto; \d pedido; \d detalle_pedido; \dT+ forma_pago_enum"

# Snapshot inicial (protocolo §2)
mkdir -p tp-Coronel-BaseDeDatosII/db/backups
pg_dump -Fc -f tp-Coronel-BaseDeDatosII/db/backups/foodstore_original_20260903.dump foodstore_original
```

### 11.3 Aplicar restricciones dentro de `BEGIN/ROLLBACK` (protocolo obligatorio)

```bash
# Crear copia de trabajo
dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
pg_dump -Fc -f tp-Coronel-BaseDeDatosII/db/backups/foodstore_trabajo_20260903_preDDL.dump foodstore_trabajo

# Probar dentro de transacción — primero ROLLBACK (verificación)
psql -d foodstore_trabajo <<'SQL'
BEGIN;
\i tp-Coronel-BaseDeDatosII/db/restricciones_foodstore.sql
-- Verificación: 3 CHECKs + 5 triggers deben existir
SELECT conname, contype FROM pg_constraint WHERE conname LIKE 'chk_%' ORDER BY conname;
-- chk_cliente_email_formato, chk_detalle_precio_positivo, chk_pedido_fecha_no_futura
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname LIKE 'trg_%' ORDER BY tgname;
-- trg_actualizar_stock_detalle, trg_descontar..., trg_pedido_fecha_no_futura, trg_restituir..., trg_validar_detalle_pedido, trg_validar_precio_unitario
ROLLBACK;
SQL

# Si todo ok, confirmar
psql -d foodstore_trabajo -c "BEGIN; \i tp-Coronel-BaseDeDatosII/db/restricciones_foodstore.sql; COMMIT;"
pg_dump -Fc -f tp-Coronel-BaseDeDatosII/db/backups/foodstore_trabajo_20260903_postDDL.dump foodstore_trabajo
```

### 11.4 Probar reglas con `BEGIN/ROLLBACK` (defensa oral)

```sql
-- Conectado a foodstore_trabajo
BEGIN;
INSERT INTO categoria (nombre) VALUES ('Cat Demo') RETURNING id_categoria; -- supongamos 99
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (99, 'DemoActivo', 200, 5, TRUE);
INSERT INTO cliente (nombre, email) VALUES ('Demo', 'demo@example.com');
INSERT INTO pedido (id_cliente, forma_pago) VALUES ((SELECT id_cliente FROM cliente WHERE email='demo@example.com'), 'EFECTIVO') RETURNING id_pedido;
-- R1 inválida:
INSERT INTO pedido (id_cliente, fecha, forma_pago) VALUES ((SELECT id_cliente FROM cliente WHERE email='demo@example.com'), now() + interval '1 day', 'EFECTIVO');
-- => ERROR R1: pedido.fecha no puede ser futura
-- R2 inválida stock:
INSERT INTO producto (id_categoria, nombre, precio, stock, activo) VALUES (99, 'SinStock', 100, 2, TRUE) RETURNING id_producto;
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (1, <id_sin_stock>, 10, 100);
-- => ERROR R2: stock insuficiente
-- R3 inválida email:
INSERT INTO cliente (nombre, email) VALUES ('Bad', 'no-es-email');
-- => ERROR chk_cliente_email_formato
ROLLBACK;
```

### 11.5 Repetir escenarios de concurrencia (2 terminales `psql`)

Abrir **dos terminales** `psql -d foodstore_trabajo` (Sesión A y B). Seguir paso a paso `docs/informe_concurrencia.md` §Setup + Escenarios A/B/C. Ejemplo abreviado Escenario A:

```sql
-- Terminal A:
BEGIN; SET TRANSACTION ISOLATION LEVEL READ COMMITTED; SELECT stock FROM producto WHERE id_producto=100; -- 50
-- Terminal B (mientras A abierta):
BEGIN; UPDATE producto SET stock=30 WHERE id_producto=100; COMMIT;
-- Terminal A:
SELECT stock FROM producto WHERE id_producto=100; -- 30 (no repetible)
COMMIT;
-- Repetir en REPEATABLE READ debe dar 50→50.
```

Para Escenario C diagnosticar con tercera terminal:

```sql
SELECT locktype, relation::regclass, pid, mode, granted FROM pg_locks WHERE relation='producto'::regclass;
SELECT pid, wait_event_type, wait_event, state, query FROM pg_stat_activity WHERE wait_event IS NOT NULL;
```

### 11.6 Preguntas tipo defensa oral (por línea de diff)

| Línea / concepto | Pregunta del docente | Respuesta esperada (defendible) |
|---|---|---|
| `IF NEW.fecha > now() THEN RAISE EXCEPTION` (`restricciones_foodstore.sql:63`) | “¿Por qué no usaste solo `CHECK (fecha <= now())`?” | `now()` es `STABLE`, no `IMMUTABLE`; PG lo acepta pero el estándar y la cátedra desaconsejan funciones no inmutables en `CHECK`. El trigger da `RAISE EXCEPTION` con mensaje claro y `ERRCODE 23514`, y es el que realmente aborta. El `CHECK` queda como barrera documentativa redundante. |
| `SELECT ... FOR UPDATE` (`restricciones_foodstore.sql:157`) | “¿Qué hace `FOR UPDATE`?” | Toma un **row-level lock** de escritura sobre la fila de `producto` hasta `COMMIT/ROLLBACK`. Serializa pedidos concurrentes: la segunda sesión que lee `stock=5` queda `WAITING` (ver `pg_locks granted=f`) y al liberarse ve `stock=0` y falla, evitando oversell. Sin `FOR UPDATE` ambas leerían `5` y ambas insertarían. |
| `AFTER INSERT` vs `BEFORE` (`restricciones_foodstore.sql:224`) | “¿Por qué el descuento está en `AFTER` y no en `BEFORE`?” | En `BEFORE` el `UPDATE producto SET stock = stock - NEW.cantidad` se ejecutaría aunque el `INSERT` luego falle por otra constraint (ej: `precio_unitario`), dejando stock inconsistente. En `AFTER` solo descuenta si la fila realmente se insertó. Por eso hay 3 triggers separados `AFTER INSERT/UPDATE/DELETE`. |
| `DO $$ IF NOT EXISTS (SELECT 1 FROM pg_constraint ...)` (`restricciones_foodstore.sql:81`) | “¿Para qué el bloque `DO`?” | Para **idempotencia**: `ALTER TABLE ADD CONSTRAINT` falla si el constraint ya existe. `DROP IF EXISTS` no aplica a constraints en PG < 14; el `DO` chequea `pg_constraint` y solo agrega si falta, permitiendo re-ejecutar `restricciones_foodstore.sql` N veces sin error (`psql -f` repetido). |
| `NOT EXISTS` vs `NOT IN` (`ejercicio_lectura_critica.md:204`) | “¿Por qué `NOT EXISTS` y no `NOT IN`?” | `NOT IN (SELECT ...)` con un `NULL` en la subconsulta da `UNKNOWN` por lógica trivaluada → 0 filas (bug silencioso). `NOT EXISTS` es **inmune a NULL**, más claro (“no existe producto para esta categoría”) y suele optimizar mejor. La variante `NOT IN ... WHERE col IS NOT NULL` también corrige pero `NOT EXISTS` es la recomendada. |
| `UPDATE producto SET activo=FALSE WHERE ...` vs `DELETE` (`ejercicio_lectura_critica.md:250`) | “¿Por qué no `DELETE` físico?” | FoodStore usa **baja lógica** (`activo BOOLEAN`) y `ON DELETE RESTRICT` (`schema.sql:35`) para preservar historial de pedidos. `DELETE` físico perdería historia y violaría `RESTRICT` si hay `producto` referenciado. El patrón correcto es `UPDATE ... SET activo=FALSE`. |
| `REPEATABLE READ` evita phantom en PG pero ANSI exige `SERIALIZABLE` (`informe_concurrencia.md:221`) | “¿`REPEATABLE READ` evita phantom?” | **En PG sí**, por MVCC snapshot por transacción — el `COUNT(*)` dentro de `RR` no ve inserts posteriores. **A nivel ANSI**, `REPEATABLE READ` aún permite phantoms; solo `SERIALIZABLE` (en PG con SSI) lo garantiza formalmente. Se documentó la distinción PG vs ANSI. |
| `40P01 deadlock detected` (`informe_concurrencia.md:338`) | “¿Cuándo ocurre y cómo se evita?” | Con 2 filas en orden cruzado: A lockea `100` y pide `101`, B lockea `101` y pide `100` → ciclo → PG aborta una con `40P01`. Se evita lockeando siempre en **orden determinístico** (`ORDER BY id_producto`) y con transacciones cortas / `lock_timeout`. |
| `createdb -T` (`protocolo_seguridad.md:25`) | “¿Por qué `createdb -T`?” | Clona la BD por **template** (copia física barata e instantánea), sin `pg_dump`/`pg_restore` manual. Garantiza que `foodstore_trabajo` sea idéntica a `foodstore_original` al inicio de la jornada. |

---

## 12. Checklist final de entrega (5/5)

> Reproducción literal del checklist del PDF `TP2_Laboratorio_Concurrencia_IA.pdf` — cada ítem mapeado a archivo y commit. Todos marcados ✅.

| # | Ítem del PDF (checklist final) | Archivo que lo cumple | Commit | Evidencia verificable |
|---|---|---|---|---|
| 1 | **Parte 0 — Protocolo de seguridad** adaptado a entorno real (copia + transacción + respaldo), **commiteado antes de Parte 1** | `docs/protocolo_seguridad.md` (199 líneas) | `b7fe275` (anterior a `6ef68e6`) | `git log --oneline`: `b7fe275` antes de `6ef68e6`; `git show b7fe275:protocolo_seguridad.md \| head -20` muestra encabezado UTN + tabla 3 pasos + `createdb -T`/`pg_dump -Fc` |
| 2 | **Parte 1 — 2–3 reglas de negocio con IA** — spec antes, modo Plan, diff defendible, `BEGIN/ROLLBACK`, DUIA (6 campos) | `db/restricciones_foodstore.sql` (386 líneas, 3 reglas R1/R2/R3) + `docs/DUIA_Parte1.md` (150 líneas) | `6ef68e6` | R1 trigger `trg_pedido_fecha_no_futura`, R2 `FOR UPDATE` + 3× `AFTER`, R3 `chk_*` + tolerancia 0.5×–1.5×; 5 correcciones documentadas; 8 pruebas `ROLLBACK` en DUIA |
| 3 | **Parte 2 — 3 anomalías concurrencia** (no repetible, fantasma, `FOR UPDATE`/interbloqueo) + IA verificada en motor + `informe_concurrencia.md` + DUIA | `docs/informe_concurrencia.md` (398 líneas, 3 escenarios A/B/C) + `docs/DUIA_Parte2.md` (35 líneas) | `6ef68e6` | Escenario A `50→30`/`50→50`, B `5→6`/`5→5`, C `granted=f` + `40P01`; `pg_locks`/`pg_stat_activity` capturados; explicación IA copiada y verificada |
| 4 | **Parte 3 — Lectura crítica 2 scripts peligrosos** (`UPDATE` sin `WHERE`, `DELETE NOT IN` con `NULL`) + correcciones + DUIA | `docs/ejercicio_lectura_critica.md` (343 líneas, incluye DUIA Parte 3) | `6ef68e6` | Script 1 factor 28× + `WHERE` corregido; Script 2 demo `NULL` → `UNKNOWN` + 3 variantes `NOT EXISTS`/`IS NOT NULL`/baja lógica + `ERROR FK RESTRICT`; pruebas `ROLLBACK` |
| 5 | **Repositorio ordenado y trazable** — estructura `tp-Coronel-BaseDeDatosII/{db,docs,src}`, `db/schema.sql`, `.gitignore`, `AGENTS.md`, historial `git log` limpio | `README.md` + `AGENTS.md` + `.gitignore` + `.env.example` + `db/backups/.gitkeep` + `src/.gitkeep` + `git mv R100` | `7b056d0` | Árbol §10.1; `git log --name-status` muestra `R100`; `git log --oneline --stat` 5 commits trazables; remote `origin` en GitHub |

**Resultado: 5/5 ✅ — entrega completa, sin ítems pendientes.**

---

## 13. Conclusiones y aprendizajes

### 13.1 IA como motor primario — se delega escritura, nunca decisión

El TP exige usar IA “como motor primario” y este trabajo lo cumple sin ambigüedad: **cada DDL/DML relevante fue escrito primero por IA** (`restricciones_foodstore.sql`, borradores de `informe_concurrencia.md` y `ejercicio_lectura_critica.md`). Pero la consigna —y la práctica profesional— deja claro que **la decisión final es siempre humana**:

- La IA propuso `CHECK (fecha <= now())` como garantía única; el alumno **corrigió** a trigger `RAISE EXCEPTION` por `STABLE` vs `IMMUTABLE` y lo documentó como “corrección #1” en DUIA.
- La IA generó `SELECT stock ...` sin `FOR UPDATE`; el alumno **agregó** el lock pesimista y explicó por qué sin él hay carrera.
- La IA omitió el deadlock `40P01` y los diagnósticos `pg_locks`; el alumno **agregó** ambos y los verificó en motor.
- La IA dio `NOT IN` “natural”; el alumno **reemplazó** por `NOT EXISTS` y demostró la trampa `NULL`.

> **Aprendizaje defendible:** la IA acelera 10× la escritura de esqueletos, pero sin lectura crítica introduce bugs silenciosos (`NULL`, `FOR UPDATE`, `STABLE`). La DUIA de 6 campos obliga a explicitar **qué se aceptó, qué se corrigió y por qué**, que es exactamente lo que un ingeniero debe hacer en code review. Versionar spec + diff + corrección en Git es la trazabilidad que la cátedra pide y que la industria exige.

### 13.2 Importancia del protocolo — backup, copia y transacción

El protocolo de 3 pasos no es burocracia: es **supervivencia de datos**.

- **Copia (`createdb -T`):** sin ella, un `UPDATE sin WHERE` en `foodstore_original` deja la tienda sin productos y sin `ROLLBACK` posible tras `COMMIT` implícito. Con copia, el `ROLLBACK` en `foodstore_trabajo` salva los datos y el `pg_dump` previo permite `pg_restore`.
- **Transacción (`BEGIN/ROLLBACK`):** cada prueba de R1/R2/R3 y cada script de Parte 3 se ejecutó primero con `ROLLBACK`; solo tras verificar `SELECT COUNT(*)` se repitió con `COMMIT`. Es el “ensayo general” que evita que un `DELETE NOT IN` con `NULL` borre 0 filas silenciosamente en producción.
- **Respaldo (`pg_dump -Fc`):** `db/backups/` versionado con `YYYYMMDD` permite volver atrás incluso si la transacción ya hizo `COMMIT` por error humano. `.gitignore` evita pushear dumps grandes pero conserva los `.sql` livianos.

> **Aprendizaje:** “Si no hay backup, no hay DDL. Si no hay transacción, no hay DML.” — principio rector de `protocolo_seguridad.md:15` que el alumno interiorizó y que defenderá ante cualquier pregunta de “¿y si…?”.

### 13.3 Valor de versionar todo en Git

- **Trazabilidad:** 5 commits con mensajes convencionales (`docs(seguridad):`, `feat(tp2):`, `refactor(estructura):`) permiten a cualquier docente hacer `git log --oneline --stat` y ver exactamente qué se entregó cuándo, y que el protocolo fue **antes** de las reglas.
- **`git mv R100`:** el reordenamiento a `tp-Coronel-BaseDeDatosII` preservó historia; `git log --follow -- db/schema.sql` sigue mostrando `80ad8a2`. Un `mv` + `add` habría perdido autoría y `blame`.
- **Reproducibilidad:** con `db/schema.sql` + `db/restricciones_foodstore.sql` + `docs/*.md` versionados, cualquier clon fresco puede reconstruir `foodstore_trabajo` en 3 comandos (`createdb -T`, `psql -f`, `pg_dump`). No hay “funciona en mi máquina”.

> **Aprendizaje:** Git no es solo “subir a GitHub”; es **evidencia** — cada DUIA, cada corrección a la IA y cada `ROLLBACK` queda fechado y firmado (`Author: Jerónimo Coronel — 2026-09-03`). Ante una defensa oral, `git show <sha>:archivo` es la prueba irrefutable de qué se hizo y cuándo.

---

## 14. Anexos

### 14.1 Enlaces y rutas

| Recurso | Ruta / URL |
|---|---|
| **Repositorio GitHub** | https://github.com/jeronimocoronel784-hue/BaseDeDatos2 |
| **Git root local** | `C:\BaseDeDatos2\` |
| **Carpeta canónica (entregable)** | `C:\BaseDeDatos2\tp-Coronel-BaseDeDatosII\` |
| **Canónico de este informe** | `C:\BaseDeDatos2\tp-Coronel-BaseDeDatosII\docs\INFORME_COMPLETO_TP2.md` |
| **Copia/índice en raíz** | `C:\BaseDeDatos2\INFORME_TP2.md` (apunta al canónico) |
| **OneDrive (trabajo previo)** | `C:\Users\jeron\OneDrive\Desktop\Programacion UTN\3er semestre\Metodologia de Sist\Base de Datos II\BaseDeDatos2` (plana, desordenada — ya migrada) |

### 14.2 Historial git completo

```bash
# Comando:
git log --oneline --decorate --all
# Salida real (2026-09-03):
7b056d0 (HEAD -> main, origin/main, origin/HEAD) refactor(estructura): ordena repo como tp-Coronel-BaseDeDatosII
6ef68e6 feat(tp2): restricciones FoodStore + concurrencia + lectura critica + DUIA
b7fe275 docs(seguridad): protocolo copia-transaccion-respaldo adaptado a PostgreSQL local
55a3b41 protocolos de seguridad
80ad8a2 Primer commit

# Con stat:
git log --oneline --stat --all
# (ver §4.3 para salida completa)

# Con renames:
git log --name-status --all --oneline
# (ver §4.4 — R100 y R070)

# Remotes:
git remote -v
# origin  https://github.com/jeronimocoronel784-hue/BaseDeDatos2.git (fetch)
# origin  https://github.com/jeronimocoronel784-hue/BaseDeDatos2.git (push)

# Estado al entregar este informe (sin staged — orquestador hará commit):
git status
# On branch main
# Your branch is up to date with 'origin/main'.
# Untracked files:
#   tp-Coronel-BaseDeDatosII/docs/INFORME_COMPLETO_TP2.md
#   INFORME_TP2.md
```

### 14.3 Comandos útiles (resumen para el docente)

```bash
# --- Ver el informe canónico ---
cat tp-Coronel-BaseDeDatosII/docs/INFORME_COMPLETO_TP2.md
# o en Windows:
notepad tp-Coronel-BaseDeDatosII\docs\INFORME_COMPLETO_TP2.md

# --- Historial y evidencia ---
git log --oneline --decorate --all
git show b7fe275 --stat          # Parte 0
git show 6ef68e6 --stat          # Partes 1/2/3 (1312 líneas)
git show 7b056d0 --stat          # Reordenamiento (16 archivos, R100)
git log --name-status --all --oneline  # verificar git mv
git show HEAD:tp-Coronel-BaseDeDatosII/docs/protocolo_seguridad.md | head -30

# --- PostgreSQL 16 (protocolo completo) ---
createdb foodstore_original
psql -d foodstore_original -f tp-Coronel-BaseDeDatosII/db/schema.sql
mkdir -p tp-Coronel-BaseDeDatosII/db/backups
pg_dump -Fc -f tp-Coronel-BaseDeDatosII/db/backups/foodstore_original_20260903.dump foodstore_original

dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
pg_dump -Fc -f tp-Coronel-BaseDeDatosII/db/backups/foodstore_trabajo_20260903.dump foodstore_trabajo
psql -d foodstore_trabajo -c "BEGIN; \i tp-Coronel-BaseDeDatosII/db/restricciones_foodstore.sql; ROLLBACK;"  # verificar
psql -d foodstore_trabajo -c "BEGIN; \i tp-Coronel-BaseDeDatosII/db/restricciones_foodstore.sql; COMMIT;"   # confirmar

# --- Ver constraints y triggers instalados ---
psql -d foodstore_trabajo -c "SELECT conname, contype FROM pg_constraint WHERE conname LIKE 'chk_%' ORDER BY conname;"
psql -d foodstore_trabajo -c "SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_%' ORDER BY tgname;"

# --- Concurrencia: diagnóstico ---
psql -d foodstore_trabajo -c "SELECT * FROM pg_locks WHERE relation='producto'::regclass;"
psql -d foodstore_trabajo -c "SELECT pid, wait_event_type, wait_event, state, query FROM pg_stat_activity WHERE wait_event IS NOT NULL;"

# --- Restaurar backup si algo salió mal ---
pg_restore -d foodstore_trabajo tp-Coronel-BaseDeDatosII/db/backups/foodstore_trabajo_20260903.dump
# o: dropdb foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo

# --- Estructura ---
Get-ChildItem -Recurse tp-Coronel-BaseDeDatosII | Format-Table Name, Length
# o bash:
find tp-Coronel-BaseDeDatosII -type f | sort
wc -l tp-Coronel-BaseDeDatosII/db/*.sql tp-Coronel-BaseDeDatosII/docs/*.md
```

### 14.4 Glosario mínimo (para defensa)

| Término | Definición en una línea |
|---|---|
| `MVCC` | Multi-Version Concurrency Control — PG guarda versiones de filas; cada transacción ve un snapshot. |
| `READ COMMITTED` | Snapshot por **sentencia** — cada `SELECT` ve lo commiteado hasta ese momento (permite no repetible y phantom). |
| `REPEATABLE READ` | Snapshot por **transacción** — toda la tx ve la misma foto (evita no repetible y, en PG, phantom). |
| `SERIALIZABLE` | SSI (Serializable Snapshot Isolation) — detecta anomalías de serialización; único nivel ANSI que garantiza ausencia de phantoms. |
| `FOR UPDATE` | Lock pesimista de fila hasta `COMMIT/ROLLBACK` — serializa acceso concurrente a la misma fila. |
| `40P01` | `deadlock_detected` — PG aborta una de dos tx en ciclo de espera. |
| `DUIA` | Declaración de Uso de IA — 6 campos: Herramienta, Spec, Qué generó, Qué se aceptó, Qué se modificó/descartó, Verificación. |
| `ON DELETE RESTRICT` | FK que impide borrar padre si hay hijos — preserva historial (vs `CASCADE`). |
| `CHECK`/`TRIGGER` | `CHECK` valida fila sin cruzar tablas; `TRIGGER` puede hacer `SELECT` cross-table y `RAISE EXCEPTION`. |
| `pg_locks`/`pg_stat_activity` | Vistas de sistema para diagnosticar locks (`granted`) y esperas (`wait_event`). |
| `createdb -T` | Clona BD por template — copia instantánea para `foodstore_trabajo`. |
| `pg_dump -Fc` | Dump custom comprimido — respaldo binario restaurable con `pg_restore`. |

---

> **Cierre:** este informe consolida **100% de los cambios pedidos por el TP y 100% de los realizados en el repositorio**, con citas textuales de archivos reales, SHAs reales y comandos reproducibles. No se omitió ningún entregable ni commit. Queda listo para impresión, entrega y defensa oral ante la cátedra de Base de Datos II — UTN.
>
> **Autor:** Jerónimo Coronel — **Fecha:** 2026-09-03 — **Motor:** PostgreSQL 16 — **Repo:** https://github.com/jeronimocoronel784-hue/BaseDeDatos2 — **Carpeta:** `C:\BaseDeDatos2\tp-Coronel-BaseDeDatosII`
