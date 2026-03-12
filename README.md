# DBIO-SQLite

SQLite driver distribution for DBIO.

## Scope

- Provides SQLite storage behavior: `DBIO::SQLite::Storage`
- Provides SQLite SQLMaker: `DBIO::SQLite::SQLMaker`
- Owns SQLite-specific tests from the historical DBIx::Class monolithic test
  layout

## Migration Notes

- `DBIx::Class::Storage::DBI::SQLite` -> `DBIO::SQLite::Storage`
- `DBIx::Class::SQLMaker::SQLite` -> `DBIO::SQLite::SQLMaker`

When installed, DBIO core can autodetect SQLite DSNs and load the storage
class through `DBIO::Storage::DBI` driver registration.

## Testing

SQLite tests in this distribution use in-memory databases and do not need
external database credentials.
