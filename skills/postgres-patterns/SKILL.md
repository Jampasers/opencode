---
name: postgres-patterns
description: Use when designing PostgreSQL schemas, writing SQL or Prisma migrations, adding indexes, diagnosing slow queries with EXPLAIN, implementing RLS policies or column privileges, configuring connection pooling/PgBouncer, modeling data (soft delete, auditing, versioning, polymorphic), preventing N+1 queries, or handling transactions, locking, and deadlocks. Covers Postgres best practices on any host plus Prisma ORM optimization workflows.
origin: merged from postgres-patterns, supabase-postgres-best-practices, postgres-prisma-optimization
---

# PostgreSQL Patterns

Design schemas and indexes for the queries you actually run, enforce access in the database, and measure with `EXPLAIN ANALYZE` before optimizing. Covers plain Postgres, Supabase-style RLS, and Prisma ORM.

## When to Use

- Writing SQL queries or migrations
- Designing database schemas, column types, or data models
- Troubleshooting slow queries, high CPU, timeouts, or bloat
- Implementing Row Level Security
- Setting up connection pooling or PgBouncer
- Working with Prisma schema, migrations, and transactions

## Schema Design & Data Types

| Use Case | Correct Type | Avoid |
|----------|-------------|-------|
| IDs | `bigint` (identity) | `int`, random UUID |
| Strings | `text` | `varchar(255)` |
| Timestamps | `timestamptz` | `timestamp` |
| Money | `numeric(10,2)` | `float` |
| Flags | `boolean` | `varchar`, `int` |
| Enums | `text` + check constraint, or enum type | free-form strings |

- Postgres does **not** index foreign keys automatically. Always `create index` / `@@index` the FK column — missing indexes slow JOINs and `ON DELETE CASCADE`.
- Keep identifiers lowercase; use `snake_case` tables. `work_mem * max_connections` should stay under 25% of RAM.
- Partition tables > 100M rows, time-series data with date queries, or when old data must be dropped instantly (`drop table events_2023_01` vs. a multi-hour `DELETE`).

Find unindexed foreign keys:

```sql
SELECT conrelid::regclass AS table_name, a.attname AS fk_column
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid AND a.attnum = ANY(i.indkey)
  );
```

### Data Modeling Patterns (Prisma)

Soft delete — `deletedAt DateTime? @map("deleted_at")`, filter `where: { deletedAt: null }` everywhere, partial index on active rows:

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS "idx_user_active"
ON "users" ("email") WHERE deleted_at IS NULL;
```

Auditing — `AuditLog` model with `entityId`, `entityType`, `action`, `oldValue`/`newValue` JSONB, `actorId`, indexes on `[entityType, entityId]`, `[actorId]`, `[createdAt]`; populate via Prisma `$use` middleware on create/update/delete.

Optimistic locking — add `version Int @default(1)`; update with `updateMany({ where: { id, version: expectedVersion }, data: { ...data, version: { increment: 1 } } })` and treat `count === 0` as a conflict.

Polymorphic relations (no native Prisma support): (1) nullable FK per entity type + indexes, (2) `entityType` + `entityId` columns with composite index, (3) generic `targetType`/`targetId` + JSONB metadata with GIN index on metadata.

Data modeling checklist: 3NF unless denormalization is justified; audit trail for financial/user/settings data; versioning for concurrent updates; JSONB for semi-structured data; `@default(now())` / `@updatedAt` timestamps; indexes on FKs and primary query patterns.

### Prisma Schema Patterns

```prisma
model Profile {
  id     String @id @default(uuid()) @db.Uuid
  userId String @unique @map("user_id") @db.Uuid   // @unique enforces one-to-one
  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)
  @@map("profiles")
}

model Post {
  id       String @id @default(uuid()) @db.Uuid
  authorId String @map("author_id") @db.Uuid
  author   User   @relation(fields: [authorId], references: [id], onDelete: Cascade)
  tags     TagOnPost[]
  @@index([authorId], name: "idx_post_author_id")   // FK on the "many" side
  @@map("posts")
}

model TagOnPost {
  postId String @map("post_id") @db.Uuid
  tagId  String @map("tag_id") @db.Uuid
  @@id([postId, tagId])                              // junction composite PK
  @@index([tagId])                                   // reverse lookup
  @@map("tags_on_posts")
}

model Order {
  userId    String   @map("user_id") @db.Uuid
  status    String?
  createdAt DateTime @default(now()) @map("created_at") @db.Timestamptz(3)
  @@index([userId, status, createdAt], name: "idx_order_user_status_created")
  @@index([status], name: "idx_order_active", where: "status = 'ACTIVE'") // partial, Prisma 5.10+
  @@map("orders")
}
```

- Use `@map()`/`@@map()` for snake_case DB names; always set `onDelete` (`Cascade`, `Restrict`, `SetNull`, `NoAction`).
- Prefer Prisma enums (migration-engine safe); use native PG enums via `@pgEnum` where needed.
- Partial index `where:` needs Prisma 5.10+; GIN and other advanced indexes go in a manual migration (`CREATE INDEX ... USING GIN`).

## Indexing Strategy

| Query Pattern | Index Type | Example |
|--------------|------------|---------|
| `WHERE col = value`, range | B-tree (default) | `CREATE INDEX idx ON t (col)` |
| `WHERE a = x AND b > y` | Composite B-tree | `CREATE INDEX idx ON t (a, b)` |
| `WHERE jsonb @> '{}'` | GIN | `CREATE INDEX idx ON t USING gin (col)` |
| `WHERE tsv @@ query` | GIN | `CREATE INDEX idx ON t USING gin (col)` |
| Time-series ranges | BRIN | `CREATE INDEX idx ON t USING brin (col)` |
| `ILIKE '%term%'` | GIN trigram | `USING GIN (col gin_trgm_ops)` |
| Full-text search | GIN | `USING GIN (to_tsvector('english', col))` |

Index types: **B-tree** for equality/ranges/ORDER BY/LIKE prefix; **GIN** for JSONB, arrays, full-text; **GiST** for geometry/ranges; **BRIN** for large naturally ordered tables; **Hash** rarely (B-tree is better).

```sql
-- Composite: equality columns first, range/ORDER BY column last
CREATE INDEX idx ON orders (status, created_at);

-- Covering: avoids table lookup
CREATE INDEX idx ON users (email) INCLUDE (name, created_at);

-- Partial: smaller index for hot subset
CREATE INDEX idx ON users (email) WHERE deleted_at IS NULL;

-- GIN full-text / JSONB / array
CREATE INDEX idx ON posts USING GIN (to_tsvector('english', content));
CREATE INDEX idx ON products USING GIN (metadata);
```

Composite index rules: leftmost-prefix — `[A,B,C]` serves `A`, `A+B`, `A+B+C`, never `B` alone; high-cardinality columns first; range conditions and ORDER BY columns rightmost.

Indexing anti-patterns: over-indexing (slows writes), indexing boolean/low-cardinality columns, duplicate indexes (`@unique` + `@@index` on the same column), indexes on rarely queried columns, wrong composite column order.

## Query Optimization & EXPLAIN

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.id, u.email, COUNT(p.id) AS post_count
FROM users u LEFT JOIN posts p ON p.author_id = u.id
WHERE u.status = 'ACTIVE'
GROUP BY u.id, u.email
ORDER BY post_count DESC
LIMIT 20;
```

| Indicator | Meaning | Action |
|-----------|---------|--------|
| `Seq Scan` on large table | No usable index | Add index |
| `Est. rows` >> / << `Actual rows` | Bad cardinality estimate | `ANALYZE`, adjust stats |
| `Sort Method: external merge` | Sort spills to disk | Index the sort, raise `work_mem` |
| `Nested Loop` with high `loops` | Bad join strategy | Add index, reconsider join |
| High `Rows Removed by Filter` | Poor selectivity | Partial/composite index |
| `Buffers: read` >> `hit` | Data not cached | More memory / better indexes |

Slow queries:

```sql
SELECT query, calls, total_exec_time / calls AS avg_time_ms, rows
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_%'
ORDER BY total_exec_time DESC
LIMIT 20;

-- Bloat
SELECT relname, n_dead_tup, last_vacuum FROM pg_stat_user_tables
WHERE n_dead_tup > 1000 ORDER BY n_dead_tup DESC;
```

Enable monitoring: `shared_preload_libraries = 'pg_stat_statements'`, then `CREATE EXTENSION IF NOT EXISTS pg_stat_statements;`.

Prisma profiling:

```typescript
const prisma = new PrismaClient({
  log: [{ emit: 'event', level: 'query' }],
});
prisma.$on('query', (e) => {
  console.log('Query:', e.query, 'Duration:', e.duration, 'ms');
});
```

Performance checklist: verify index usage with EXPLAIN ANALYZE; avoid N+1; paginate with `take`; `select` only needed fields; index FKs; monitor pg_stat_statements; use pooling in production; size `connection_limit`; use `@db.Uuid` for UUIDs (binary storage).

### N+1 Prevention (Prisma)

```typescript
// BAD — 1 query for users + N for posts
const users = await prisma.user.findMany();
for (const user of users) {
  const posts = await prisma.post.findMany({ where: { authorId: user.id } });
}

// GOOD — eager load with filters and limits
const usersWithPosts = await prisma.user.findMany({
  include: {
    profile: true,
    posts: { where: { status: 'PUBLISHED' }, orderBy: { createdAt: 'desc' }, take: 10 },
  },
});

// GOOD — projection: only needed fields (lighter than include)
const partial = await prisma.user.findMany({
  select: { id: true, email: true, posts: { select: { id: true, title: true } } },
});

// GOOD — batch instead of loop queries
const usersInBatch = await prisma.user.findMany({
  where: { id: { in: userIds } },
  include: { posts: true },
});

// Raw SQL when Prisma cannot express an efficient aggregate
const counts = await prisma.$queryRaw<Array<{ id: string; post_count: bigint }>>`
  SELECT u.id, COUNT(p.id)::BIGINT AS post_count
  FROM "users" u LEFT JOIN "posts" p ON p.author_id = u.id
  WHERE u.id = ANY(${userIds}::UUID[])
  GROUP BY u.id ORDER BY post_count DESC
`;
```

`include` loads all relation fields (detail views); `select` loads a subset (lists/API responses). Count queries in development with a `$use` middleware or `log: ['query']`.

### Data Access Patterns

```sql
-- UPSERT
INSERT INTO settings (user_id, key, value) VALUES (123, 'theme', 'dark')
ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value;

-- Cursor/keyset pagination: O(1) at any depth (OFFSET is O(n))
SELECT * FROM products WHERE id > $last_id ORDER BY id LIMIT 20;
-- Multi-column: cursor must include all sort columns
SELECT * FROM products WHERE (created_at, id) > ($ts, $id)
ORDER BY created_at, id LIMIT 20;

-- Queue processing: skip rows locked by other workers
UPDATE jobs SET status = 'processing'
WHERE id = (
  SELECT id FROM jobs WHERE status = 'pending'
  ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED
) RETURNING *;

-- Full-text search (100x faster than LIKE '%term%', which cannot use an index)
ALTER TABLE articles ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(content,''))) STORED;
CREATE INDEX articles_search_idx ON articles USING GIN (search_vector);
SELECT *, ts_rank(search_vector, query) AS rank
FROM articles, to_tsquery('english', 'postgresql & performance') query
WHERE search_vector @@ query ORDER BY rank DESC;
```

## RLS & Security

Application-only filtering leaks data on any bypass; enforce in the database:

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders FORCE ROW LEVEL SECURITY;   -- also applies to table owner

CREATE POLICY orders_user_policy ON orders
  FOR ALL TO authenticated
  USING ((SELECT auth.uid()) = user_id);       -- wrap in SELECT: evaluated once, cached

CREATE INDEX orders_user_id_idx ON orders (user_id);  -- always index RLS predicate columns
```

- Unwrapped `auth.uid() = user_id` is called per row; the `SELECT` wrapper is 100x+ faster on large tables.
- `SECURITY DEFINER` helpers bypass RLS: keep them in a non-exposed schema, check `auth.uid()` inside the body, `set search_path = ''`, and `REVOKE EXECUTE` from `PUBLIC`, `anon`, `authenticated`, `service_role`.
- Revoke broad defaults: `REVOKE ALL ON SCHEMA public FROM public;`
- Multi-tenant alternative without Supabase auth: `current_setting('app.current_user_id')::bigint` set per session.

## Connection Management

Connections cost 1–3MB RAM each; without pooling, 500 concurrent users means 500 connections and a crashed database.

- Pool size ≈ `(CPU cores * 2) + spindle_count` (4 cores → ~10).
- `max_connections`: `RAM_MB / 5 - reserved`, then choose a practical 100–200 for query performance.
- Idle cleanup: `idle_in_transaction_session_timeout = '30s'`, `idle_session_timeout = '10min'`, then `SELECT pg_reload_conf();`
- Pool modes: **transaction** (connection returned after each transaction — best for most apps), **session** (needed for prepared statements, temp tables).
- Monitor: `SELECT count(*), state FROM pg_stat_activity GROUP BY state;`

PgBouncer:

```ini
[pgbouncer]
listen_port = 6432
auth_type = scram-sha-256
pool_mode = transaction
max_client_conn = 500
default_pool_size = 25
reserve_pool_size = 5
server_idle_timeout = 600
query_timeout = 30
client_idle_timeout = 300
```

```typescript
// Prisma through PgBouncer (transaction mode)
// DATABASE_URL=postgresql://user:pass@pgbouncer-host:6432/dbname?pgbouncer=true&connection_limit=20
const prisma = new PrismaClient();
process.on('SIGTERM', async () => { await prisma.$disconnect(); });
```

Prisma pool sizing: development 5–10, staging 10–20, production low traffic 20–50, high traffic 50–100+.

## Concurrency, Locking & Transactions

Deadlocks come from inconsistent lock order. Acquire locks in a fixed order first, or update atomically in one statement:

```sql
BEGIN;
SELECT * FROM accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;

-- Detect
SELECT * FROM pg_stat_database WHERE deadlocks > 0;
```

Keep transactions short; avoid holding locks across user/network waits. Use advisory locks (`pg_advisory_lock`) for application-level mutual exclusion. Use `SKIP LOCKED` for queues (above).

Prisma interactive transaction with isolation and timeout:

```typescript
const result = await prisma.$transaction(async (tx) => {
  const order = await tx.order.create({ data: { userId, totalAmount: total, status: 'PENDING' } });
  for (const item of items) {
    const inv = await tx.inventory.update({
      where: { productId: item.productId },
      data: { stock: { decrement: item.quantity } },
    });
    if (inv.stock < 0) throw new Error(`Insufficient stock for ${item.productId}`);
  }
  await tx.orderItem.createMany({
    data: items.map(i => ({ orderId: order.id, ...i })),
  });
  return order;
}, { timeout: 10000, maxWait: 5000, isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
```

Isolation levels: `ReadCommitted` (Postgres default) → `RepeatableRead` → `Serializable` (strictest; financial transactions). Retry serialization failures on Prisma error `P2034`.

Nested write (one query): `prisma.user.create({ data: { email, profile: { create: {...} }, posts: { create: [ ... ] } }, include: { profile: true, posts: true } })`.

Batch operations: `createMany({ data, skipDuplicates: true })`, `updateMany`, `deleteMany` — never loop single creates inside a transaction.

Transaction pitfalls: no timeout (holds a connection forever); sequential `create` in a loop (N queries — use `createMany`); independent reads don't need interactive transactions (`$transaction([...])` array form).

## Migrations

Development:

```bash
npx prisma migrate dev --name add_user_profile   # create + apply + generate
npx prisma migrate reset                          # destructive: reset dev DB
npx prisma generate                               # client only
```

1. Change `schema.prisma`. 2. `migrate dev --name <description>`. 3. Review `prisma/migrations/<timestamp>_<name>/migration.sql`. 4. Add raw SQL for data transformations. 5. `prisma generate`. 6. Test queries.

Production:

```bash
npx prisma migrate deploy    # idempotent; never run migrate dev in production
npx prisma migrate status
```

Back up first; monitor migration logs.

Conflicts / baselines:

```bash
npx prisma migrate resolve --applied "20250101000000_add_user_profile"
npx prisma migrate resolve --rolled-back "20250101000000_bad_migration"
```

Safe-change checklist for generated SQL:

```sql
-- Additive changes are backward compatible
ALTER TABLE "posts" ADD COLUMN "new_column" TEXT;
-- Avoid table-locking defaults on NOT NULL columns (PG 11+): add nullable, set default separately
ALTER TABLE "posts" ADD COLUMN "views" INTEGER;
ALTER TABLE "posts" ALTER COLUMN "views" SET DEFAULT 0;
-- Never block production with a plain CREATE INDEX
CREATE INDEX CONCURRENTLY IF NOT EXISTS "idx_posts_author_id" ON "posts" ("author_id");
```

Expand-contract: add new column + backfill → deploy code writing both → later migration drops the old column. `CREATE INDEX CONCURRENTLY` cannot run inside a transaction block; a failed run leaves an invalid index — monitor and drop it.

Batch data migration (chunked, resumable):

```typescript
async function migrateData(batchSize = 1000) {
  while (true) {
    const n = await prisma.$executeRaw`
      UPDATE "posts" SET "search_vector" = to_tsvector('english', "title" || ' ' || COALESCE("content", ''))
      WHERE "id" IN (
        SELECT "id" FROM "posts" WHERE "search_vector" IS NULL
        ORDER BY "id" LIMIT ${batchSize} FOR UPDATE SKIP LOCKED
      )`;
    if (n === 0) break;
  }
}
```

Rollback: Prisma has no `migrate down`. Keep a `rollback.sql` per migration (forward = ADD, rollback = DROP; restore/convert data first), document data loss and downtime, and test in staging.

Migration safety: additive, backward compatible, rollback script ready, data transformation tested, `CONCURRENTLY` for large production tables, short runtime (batch), backup taken, monitoring in place.

## Quick Reference

```sql
-- Configuration template (adjust for RAM; reload required)
ALTER SYSTEM SET max_connections = 100;
ALTER SYSTEM SET work_mem = '8MB';
ALTER SYSTEM SET idle_in_transaction_session_timeout = '30s';
ALTER SYSTEM SET statement_timeout = '30s';
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
REVOKE ALL ON SCHEMA public FROM public;
SELECT pg_reload_conf();
```

Prisma error codes: `P2002` unique violation → 409; `P2025` record not found → 404; `P2003`/`P2014` FK violation → validate references; `P2034` write conflict → retry transaction; `P1001` connection refused; `P1000` auth failed; `P1017` connection closed (pool exhaustion/idle timeout).

Commands: `npx prisma migrate dev|deploy|status|resolve`, `npx prisma generate`, `npx prisma db push` (dev only), `npx prisma db pull`, `npx prisma studio`; `psql -c "EXPLAIN ANALYZE <query>"`; `SELECT * FROM pg_stat_activity;`; `SELECT * FROM pg_locks WHERE NOT granted;`.

## References

- `references/*.md` — detailed rule files (query, schema, security/RLS, connection, locking, data access, monitoring, advanced) copied from Supabase Agent Skills (MIT License): https://github.com/supabase/agent-skills
- https://www.postgresql.org/docs/current/ · https://supabase.com/docs/guides/database/overview
- Related skills: `clickhouse-io` (analytics), `node-express-prisma` (Express API patterns)
