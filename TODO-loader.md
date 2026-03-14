# DBIO::SQLite::Loader TODO

Ported from DBIx::Class::Schema::Loader::DBI::SQLite. Lives at `DBIO::SQLite::Loader`.

## Integration

- [ ] Test with real SQLite database
- [ ] Merge with existing dbio-sqlite introspection if any

## SQLite-Specific Improvements

- [ ] Handle SQLite type affinity correctly in introspection
- [ ] Introspect STRICT tables (SQLite 3.37+)
- [ ] Handle WITHOUT ROWID tables
- [ ] Introspect JSON columns (json1 extension)
- [ ] Handle generated columns (SQLite 3.31+)

## Testing

- [ ] Port SQLite-specific loader tests from Schema::Loader
- [ ] Test type affinity edge cases
- [ ] Test Cake/Candy output format
