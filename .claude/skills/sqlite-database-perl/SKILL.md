---
name: sqlite-database-perl
description: "SQLite database knowledge for Perl driver development (DBD::SQLite, type affinity, SQLite-specific features)"
user-invocable: false
allowed-tools: Read, Grep, Glob
model: sonnet
---

SQLite knowledge relevant for Perl database driver development.

## DBD::SQLite (Perl DBI Driver)

- `DBD::SQLite` bundles SQLite itself — no external dependency
- Connection: `DBI->connect("dbi:SQLite:dbname=mydb.db")`
- In-memory: `DBI->connect("dbi:SQLite:dbname=:memory:")`
- Thread-safe but connections are NOT shared between threads
- `sqlite_unicode => 1` — enable UTF-8 handling

## Type Affinity System

SQLite does NOT enforce types. It uses type affinity:

| Affinity | Rule | Examples |
|----------|------|---------|
| INTEGER | Contains "INT" | `INTEGER`, `BIGINT`, `SMALLINT` |
| TEXT | Contains "CHAR", "CLOB", "TEXT" | `VARCHAR(255)`, `TEXT` |
| BLOB | Contains "BLOB" or no type | `BLOB`, (empty) |
| REAL | Contains "REAL", "FLOA", "DOUB" | `REAL`, `DOUBLE`, `FLOAT` |
| NUMERIC | Everything else | `NUMERIC`, `DECIMAL`, `BOOLEAN`, `DATE` |

Any column can store any type. The affinity is a preference, not a constraint.

## SQLite-Specific Features

### WAL Mode (Write-Ahead Logging)

```sql
PRAGMA journal_mode=WAL;
```
- Allows concurrent readers + one writer
- Much better performance for read-heavy workloads
- Default is DELETE (rollback journal)

### Foreign Keys (OFF by default!)

```sql
PRAGMA foreign_keys = ON;
```

Must be enabled per-connection. DBD::SQLite callback:

```perl
$dbh->do("PRAGMA foreign_keys = ON");
# or via connect attribute:
DBI->connect($dsn, "", "", { sqlite_use_immediate_transaction => 1 });
```

### Common PRAGMAs

| PRAGMA | Purpose |
|--------|---------|
| `journal_mode` | WAL, DELETE, MEMORY, OFF |
| `foreign_keys` | Enable FK enforcement |
| `synchronous` | FULL, NORMAL, OFF |
| `temp_store` | DEFAULT, FILE, MEMORY |
| `cache_size` | Page cache size |
| `busy_timeout` | Lock wait time (ms) |

## Limitations (Important for Driver)

- No `ALTER TABLE DROP COLUMN` (before SQLite 3.35.0)
- No `ALTER TABLE ALTER COLUMN` — must recreate table
- No right/full outer joins (before 3.39.0)
- No `GRANT`/`REVOKE` — file-system permissions only
- No stored procedures or triggers with complex logic
- Single writer at a time (even in WAL mode)
- No native `BOOLEAN`, `DATE`, `DATETIME` types — use affinity
- Max database size: 281 TB (theoretical)

## Date/Time Handling

SQLite has no native date/time type. Three storage strategies:

| Strategy | Format | Functions |
|----------|--------|-----------|
| TEXT | `'2024-01-15 10:30:00'` | `datetime()`, `date()`, `time()` |
| REAL | Julian day number | `julianday()` |
| INTEGER | Unix epoch | `unixepoch()` (3.38+) |

```sql
SELECT datetime('now');
SELECT strftime('%Y-%m-%d', timestamp_col);
```

## SQLite Functions

Built-in aggregate/scalar functions relevant for ORM:

- `last_insert_rowid()` — auto-increment value (important for DBIO!)
- `changes()` — rows affected by last statement
- `total_changes()` — total rows affected in connection
- `typeof(x)` — runtime type detection
- `json()`, `json_extract()`, `json_array()` — JSON support (3.9+)

## Testing with SQLite

- In-memory databases are ideal for testing: fast, no cleanup
- `DBD::SQLite` is a test dependency in most DBIO distributions
- `DBIO::Test` uses SQLite for offline tests
- No env vars needed — SQLite just works
- Use `File::Temp` for file-based test databases

```perl
use DBI;
my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:");
# test away, database disappears when $dbh goes out of scope
```

## SQLite in DBIO Context

- `DBIO::SQLite::Storage` handles SQLite-specific DBI behavior
- `DBIO::SQLite::SQLMaker` handles SQL dialect differences
- `last_insert_rowid()` maps to `last_insert_id()` in DBI
- SQLite's flexible typing means column `data_type` is advisory
- `AUTOINCREMENT` vs implicit rowid — DBIO should use explicit `INTEGER PRIMARY KEY`
