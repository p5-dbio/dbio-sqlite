---
name: dbio-core
description: "DBIO ORM architecture, API, component system, and coding conventions (DBIx::Class fork)"
user-invocable: false
allowed-tools: Read, Grep, Glob
model: sonnet
---

DBIO = fork of DBIx::Class. Apply when working in DBIO core or any driver.

## Diffs vs DBIx::Class

- Namespace `DBIO::` (not `DBIx::Class::`); `DBIO::Core`, `DBIO::Schema`
- Uses `SQL::Abstract` (not `::Classic`)
- Integrated: `DBIx::Class::TimeStamp` → `DBIO::Timestamp`; `DBIx::Class::Helpers` → core
- `SQL::Translator` optional (legacy deploy only) — being replaced by per-DB modules

## Architecture

```
DBIO::Schema → DBIO::ResultSource → DBIO::ResultSet → DBIO::Row
DBIO::Storage → DBIO::Storage::DBI
DBIO::SQLMaker
```

## Components

`load_components('Foo')` resolves under `DBIO::`. Prefix `+` = absolute.

```perl
__PACKAGE__->load_components('PostgreSQL');           # DBIO::PostgreSQL
__PACKAGE__->load_components('+My::Custom');          # absolute
```

Driver components override `connection()` to set storage_type.

## Drivers (separate dists)

| Dist | Component | Storage |
|---|---|---|
| DBIO-PostgreSQL | `DBIO::PostgreSQL` | `DBIO::PostgreSQL::Storage` |
| DBIO-MySQL | `DBIO::MySQL` | `DBIO::MySQL::Storage` |
| DBIO-SQLite | `DBIO::SQLite` | `DBIO::SQLite::Storage` |
| DBIO-Replicated | — | `DBIO::Storage::DBI::Replicated` |

## Result class

```perl
package MyApp::DB::Result::User;
use base 'DBIO::Core';
__PACKAGE__->table('users');
__PACKAGE__->add_columns(
  id   => { data_type => 'integer', is_auto_increment => 1 },
  name => { data_type => 'varchar', size => 255 },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(posts => 'MyApp::DB::Result::Post', 'user_id');
```

## Relationships

`belongs_to` · `has_many` · `has_one` · `might_have` (optional has_one) · `many_to_many` (bridge)

## ResultSet chaining

```perl
$schema->resultset('User')->search({active=>1})->search({role=>'admin'})->order_by('name');
```

## Testing rules

- Core tests MUST use `DBIO::Test::Storage` (fake). Never `dbi:SQLite` or real DB in core
- Driver integration: env vars `DBIO_TEST_PG_DSN`, `DBIO_TEST_MYSQL_DSN`, etc.
- `t/` = tests; `xt/` = author tests
- Shared test schemas → `DBIO::Test::Schema::*` in `dbio/lib/`. Do NOT redefine result classes inline in driver tests
- Optional dep skip pattern:
  ```perl
  BEGIN { eval { require Moo; 1 } or plan skip_all => 'Moo not installed' }
  ```
  List in cpanfile as `suggests`, never `requires`

### Shared schemas

| Schema | Layer | DDL |
|---|---|---|
| `DBIO::Test::Schema::Moo` | Moo | `add_columns` |
| `DBIO::Test::Schema::Moose` | Moose | `add_columns` |
| `DBIO::Test::Schema::MooCake` | Moo + Cake | Cake DDL |
| `DBIO::Test::Schema::MooseSugar` | Moose + Cake | Cake DDL |

Each: Artist + CD, has_many/belongs_to, one custom + one default ResultSet.

## OOP

- Core: `Class::Accessor::Grouped` + `Class::C3::Componentised`
- Drivers: Moo (PostgreSQL) or Moose (Replicated) — match existing driver
- `DBIO::Moo`/`DBIO::Moose` = optional bridges (`suggests`). See `dbio-moo` / `dbio-moose` skills for FOREIGNBUILDARGS, lazy rules, Cake/Candy combos, `make_immutable`
