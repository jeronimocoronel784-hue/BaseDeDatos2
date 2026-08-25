# AGENTS.md

## Repository Overview
- **Type:** PostgreSQL database schema definition project.
- **Core File:** `squema.sql` — contains all DDL statements, custom types, tables, constraints, and indexes.

## Database Design Conventions
- **Dialect:** PostgreSQL (uses `BIGINT GENERATED ALWAYS AS IDENTITY`, custom `CREATE TYPE ... AS ENUM`, and `TIMESTAMPTZ`).
- **Referential Integrity:** Foreign keys use `ON DELETE RESTRICT` to protect historical records (orders, clients, categories, products).
- **Business Rule Enforcement:** Explicit `CHECK` constraints on numerical values (e.g., non-negative prices and stock, positive quantities).
- **Soft Deletes:** Master entities (`categoria`, `cliente`, `producto`) include an `activo BOOLEAN NOT NULL DEFAULT TRUE` flag to preserve historical relationships.
- **Indexing:** Indexes are created for frequent query patterns (e.g., foreign key lookups and filtered listings).

## Working in this Repo
- When modifying or extending `squema.sql`, maintain existing naming conventions (snake_case for tables/columns/constraints, clear prefixing like `chk_` and `fk_`).
- Ensure all foreign keys maintain appropriate delete behavior and check constraints preserve business validity.
