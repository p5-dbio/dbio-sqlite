# CLAUDE.md -- DBIO::SQLite

## Project Vision

SQLite-specific schema management for DBIO (the DBIx::Class fork, see ../dbio/).

**Status**: Active development.

## Namespace

- `DBIO::SQLite` -- SQLite schema component
- `DBIO::SQLite::Storage` -- SQLite storage (replaces DBIO::Storage::DBI::SQLite)

## Usage

```perl
package MyApp::DB;
use base 'DBIO::Schema';
__PACKAGE__->load_components('SQLite');
```

## Build System

Uses Dist::Zilla with `[@Author::GETTY]` plugin bundle.
