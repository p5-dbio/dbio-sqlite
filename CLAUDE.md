# CLAUDE.md -- DBIO::SQLite

## Namespace

- `DBIO::SQLite` -- SQLite schema component
- `DBIO::SQLite::Storage` -- SQLite storage

## Usage

```perl
package MyApp::DB;
use base 'DBIO::Schema';
__PACKAGE__->load_components('SQLite');
```
