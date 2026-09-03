# AGENTS.md

## Repository Overview
- **Type:** PostgreSQL database schema definition project.
- **Core File:** `db/schema.sql` — contains all DDL statements, custom types, tables, constraints, and indexes.

## Database Design Conventions
- **Dialect:** PostgreSQL (`BIGINT GENERATED ALWAYS AS IDENTITY`, custom `CREATE TYPE ... AS ENUM`, `TIMESTAMPTZ`).
- **Referential Integrity:** Foreign keys use `ON DELETE RESTRICT` to protect historical records (orders, clients, categories, products).
- **Business Rule Enforcement:** Explicit `CHECK` constraints on numerical values (e.g., non-negative prices and stock, positive quantities).
- **Soft Deletes:** Master entities (`categoria`, `cliente`, `producto`) include an `activo BOOLEAN NOT NULL DEFAULT TRUE` flag.
- **Indexing:** Indexes optimized for frequent query patterns (e.g., foreign key lookups and filtered listings).

## Working in this Repo
- When modifying or extending `db/schema.sql`, maintain snake_case naming conventions and explicit constraint prefixing (`chk_`, `fk_`).
- Ensure all foreign keys use `ON DELETE RESTRICT` and check constraints preserve business validity.
