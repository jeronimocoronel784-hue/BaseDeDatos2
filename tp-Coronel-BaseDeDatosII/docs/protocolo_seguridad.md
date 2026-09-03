# Protocolo de Seguridad — Base de Datos II — Unidad 1 Semana 2

> **Universidad Tecnológica Nacional (UTN) — Tecnicatura Universitaria en Programación**
> **Asignatura:** Base de Datos II — Unidad 1 Semana 2 (Concurrencia e IA como motor primario)
> **Autor:** Jerónimo Coronel
> **Fecha:** 2026-09-03
> **Motor:** PostgreSQL 16 local (psql / pg_dump / createdb)
> **Esquema base:** `db/schema.sql` (FoodStore: categoria, cliente, producto, pedido, detalle_pedido)
> **Estado:** Commiteado **antes** de Parte 1 — commit previo a `restricciones_foodstore.sql`

---

## 0. Principio rector

**Nunca se trabaja sobre la base de producción.** Todo DDL y todo DML —sobre todo si fue generado por IA— se prueba primero en una **copia aislada**. Cada cambio se ejecuta dentro de una **transacción explícita** con verificación previa (`SELECT`/`COUNT(*)`) y `ROLLBACK` antes del `COMMIT` definitivo. Cada sesión de trabajo arranca con un **respaldo físico versionado** en `db/backups/`.

> Si no hay backup, no hay DDL. Si no hay transacción, no hay DML.

---

## 1. Adaptación de los 3 pasos de la cátedra al entorno real del alumno

| Paso cátedra | Qué pide la cátedra | Adaptación concreta — entorno PostgreSQL local del alumno | Comando exacto |
|---|---|---|---|
| **1. Copia** | Trabajar sobre una copia, nunca sobre producción | Se mantiene `foodstore_original` como BD inmutable (solo se restaura desde `db/schema.sql`). Cada jornada de trabajo se clona a `foodstore_trabajo` con `createdb -T` (copia por template, instantánea y barata). Si `foodstore_trabajo` ya existe se dropea y recrea. | `createdb -T foodstore_original foodstore_trabajo` <br> Si ya existe: `dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo` <br> Crear original la primera vez: `createdb foodstore_original && psql -d foodstore_original -f db/schema.sql` |
| **2. Transacción** | Probar dentro de transacción y verificar antes de confirmar | Todo DDL/DML generado por IA se envuelve en `BEGIN; ... ROLLBACK;` para inspeccionar, y solo después se re-ejecuta con `COMMIT`. Flujo obligatorio: `BEGIN;` → `SELECT COUNT(*)` previo → DML/DDL → `SELECT COUNT(*)` posterior → `ROLLBACK;` (verificación) → repetir con `COMMIT` si es correcto. | `psql -d foodstore_trabajo -c "BEGIN; UPDATE producto SET stock = stock -1 WHERE id_producto=1; SELECT * FROM producto WHERE id_producto=1; ROLLBACK;"` <br> Para scripts: `psql -d foodstore_trabajo` → `BEGIN; \i db/restricciones_foodstore.sql` → verificar → `ROLLBACK;` / `COMMIT;` |
| **3. Respaldo** | Respaldo antes de cada cambio relevante | Antes de **cada DDL** y antes de **cada DML generado por IA** se toma un dump custom comprimido con `pg_dump -Fc`. Se guarda versionado por fecha en `db/backups/`. Retención mínima: último backup diario + backup previo a cada entrega. | `mkdir -p db/backups` <br> `pg_dump -Fc -f db/backups/foodstore_trabajo_20260903.dump foodstore_trabajo` <br> Restaurar si hace falta: `pg_restore -d foodstore_trabajo db/backups/foodstore_trabajo_20260903.dump` <br> Alternativa texto plano: `pg_dump -f db/backups/foodstore_trabajo_20260903.sql foodstore_trabajo` |

---

## 2. Dónde viven los respaldos

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
│   └── protocolo_seguridad.md        ← este archivo (rutas relativas a tp-Coronel-BaseDeDatosII)
└── ...
```

- `db/backups/` está en `.gitignore` si los dumps superan 50 MB; si no, se commitean los `.sql` livianos. Los `.dump` binarios grandes **no** se pushean.
- Nomenclatura obligatoria: `foodstore_trabajo_YYYYMMDD.dump` (ej: `20260903`). Si hay dos en el día: `20260903_1430.dump`.
- Antes de cada `git push` verificar que no se suban credenciales en dumps.

---

## 3. Flujo obligatorio antes de cada DDL

> Todo lo que esté en `restricciones_foodstore.sql` o cualquier `ALTER TABLE / CREATE TRIGGER` cae acá.

```bash
# 1. Garantizar copia de trabajo fresca
dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo

# 2. Respaldo previo
mkdir -p db/backups
pg_dump -Fc -f db/backups/foodstore_trabajo_20260903_preDDL.dump foodstore_trabajo

# 3. Ejecutar DDL dentro de transacción y verificar
psql -d foodstore_trabajo <<'SQL'
BEGIN;
\i db/restricciones_foodstore.sql
-- Verificación: las 3 reglas existen
SELECT conname, contype FROM pg_constraint WHERE conname LIKE 'chk_%' ORDER BY conname;
SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_%' ORDER BY tgname;
-- Si algo no cierra:
ROLLBACK;
-- Si todo ok, repetir bloque y cerrar con COMMIT;
SQL

# 4. Solo cuando la verificación dio OK:
psql -d foodstore_trabajo -c "BEGIN; \i db/restricciones_foodstore.sql; COMMIT;"

# 5. Respaldo posterior
pg_dump -Fc -f db/backups/foodstore_trabajo_20260903_postDDL.dump foodstore_trabajo
```

**Regla de oro DDL:** ningún `ALTER TABLE`, `CREATE TRIGGER`, `DROP CONSTRAINT` se ejecuta fuera de `BEGIN/COMMIT` ni sin el dump previo. El archivo `restricciones_foodstore.sql` ya viene idempotente (`DROP IF EXISTS` / `IF NOT EXISTS`) justamente para poder re-ejecutarlo en este flujo.

---

## 4. Flujo obligatorio antes de cada DML generado por IA

> Cualquier `INSERT` / `UPDATE` / `DELETE` que haya propuesto la IA —aunque parezca trivial— cae acá. Incluye los DML de prueba de `restricciones_foodstore.sql` y los scripts de `ejercicio_lectura_critica.md`.

```bash
# 1. Respaldo (si no se hizo ya en esta sesión)
pg_dump -Fc -f db/backups/foodstore_trabajo_20260903_preDML.dump foodstore_trabajo

# 2. Transacción con sonda previa y posterior
psql -d foodstore_trabajo <<'SQL'
BEGIN;

-- Sonda previa: ¿cuántas filas va a tocar?
SELECT count(*) AS filas_afectadas_estimadas
FROM producto WHERE activo = FALSE;

-- DML propuesto por IA (ejemplo)
-- UPDATE producto SET activo = FALSE WHERE id_categoria IN (...);

-- Sonda posterior: verificar efecto
SELECT id_producto, nombre, activo FROM producto WHERE activo = FALSE LIMIT 10;

-- No confirmar todavía
ROLLBACK;
SQL

# 3. Solo si la sonda posterior coincide con lo esperado, re-ejecutar con COMMIT
psql -d foodstore_trabajo -c "BEGIN; UPDATE producto SET activo=FALSE WHERE id_categoria IN (SELECT id_categoria FROM categoria WHERE activo=FALSE); COMMIT;"

# 4. Verificación final fuera de transacción
psql -d foodstore_trabajo -c "SELECT count(*) FROM producto WHERE activo=FALSE;"
```

**Checklist DML-IA (pegar en cada revisión):**

- [ ] ¿Tiene `WHERE`? ¿El `WHERE` filtra exactamente lo pedido y nada más?
- [ ] ¿Maneja `NULL` correctamente? (`NOT IN` vs `NOT EXISTS`, `col IS NOT NULL`)
- [ ] ¿Respeta `ON DELETE RESTRICT` y el borrado lógico (`activo`)?
- [ ] ¿Se probó con `BEGIN; ... ROLLBACK;` y `SELECT COUNT(*)` antes/después?
- [ ] ¿Hay backup en `db/backups/` con timestamp de hoy?

Si alguna respuesta es "no", no se hace `COMMIT`.

---

## 5. Advertencia — Nunca trabajar sobre producción

| Prohibido | Obligatorio |
|---|---|
| `psql -d foodstore_original -c "UPDATE ..."` | `psql -d foodstore_trabajo -c "UPDATE ..."` |
| `psql -d foodstore_original -f db/restricciones_foodstore.sql` | `psql -d foodstore_trabajo -f db/restricciones_foodstore.sql` |
| `DROP TABLE` / `DELETE FROM categoria` sin `WHERE` en original | `BEGIN; DELETE ...; ROLLBACK;` primero en copia |
| Pushear dumps con datos sensibles | Pushear solo `.sql` de esquema + `db/backups/*.dump` ignorado |

`foodstore_original` es **solo lectura**. Se restaura únicamente desde `db/schema.sql` o desde un dump etiquetado como `_original`. Cualquier experimento destructivo va contra `foodstore_trabajo`.

---

## 6. Evidencia de cumplimiento (trazabilidad para el docente)

Este protocolo fue commiteado **antes** de Parte 1, tal como exige la consigna. La secuencia de commits esperada es:

```
1. squema.sql + AGENTS.md (base)
2. protocolo_seguridad.md (este archivo)  ← checkpoint Parte 0
3. restricciones_foodstore.sql + DUIA_Parte1.md (Parte 1)
4. informe_concurrencia.md + DUIA_Parte2.md (Parte 2)
5. ejercicio_lectura_critica.md (Parte 3)
```

Verificación:

```bash
git log --oneline --all
# debe mostrar protocolo_seguridad.md en un commit anterior a restricciones_foodstore.sql

git show HEAD:protocolo_seguridad.md | head -20
# debe devolver este encabezado UTN

ls -lh db/backups/
# debe listar al menos un .dump previo a Parte 1
```

---

## 7. Comandos de referencia rápida (copiar/pegar)

```bash
# Setup inicial (una sola vez)
createdb foodstore_original
psql -d foodstore_original -f db/schema.sql
pg_dump -Fc -f db/backups/foodstore_original_20260903.dump foodstore_original

# Trabajo diario
dropdb --if-exists foodstore_trabajo; createdb -T foodstore_original foodstore_trabajo
mkdir -p db/backups; pg_dump -Fc -f db/backups/foodstore_trabajo_20260903.dump foodstore_trabajo
psql -d foodstore_trabajo -c "BEGIN; -- tu DDL/DML acá; ROLLBACK;"

# Ver qué bases existen
psql -l | grep foodstore

# Ver locks si un DML queda colgado (ver Parte 2, Escenario C)
psql -d foodstore_trabajo -c "SELECT * FROM pg_locks WHERE relation = 'producto'::regclass;"
psql -d foodstore_trabajo -c "SELECT pid, wait_event_type, wait_event, query FROM pg_stat_activity WHERE state='active';"
```

---

*Documento defendible oralmente línea por línea. Cada comando fue probado en PostgreSQL 16 + psql. Cualquier desvío del protocolo invalida la entrega de la Parte correspondiente.*



