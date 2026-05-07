package DBIO::SQLite::DDL;
# ABSTRACT: Generate SQLite DDL from DBIO Result classes
our $VERSION = '0.900000';

use strict;
use warnings;

use DBIO::SQL::Util qw(_quote_ident);

=head1 DESCRIPTION

C<DBIO::SQLite::DDL> generates a SQLite DDL script from the L<DBIO::Schema>
class hierarchy. It is the desired-state side of the test-deploy-and-compare
strategy used by L<DBIO::SQLite::Deploy>.

    my $ddl = DBIO::SQLite::DDL->install_ddl($schema_class_or_instance);
    # CREATE TABLE ...; CREATE INDEX ...; ...

The output is plain SQL, suitable for executing one statement at a time
against a fresh SQLite database.

SQLite has neither schemas nor sequences nor functions/triggers/RLS, so
the generated DDL is much smaller than the PostgreSQL equivalent. The
only constructs emitted are C<CREATE TABLE> (with inline columns,
primary key, unique constraints, foreign keys) and C<CREATE INDEX>.

=cut

=method install_ddl

    my $ddl = DBIO::SQLite::DDL->install_ddl($schema);

Returns the full installation DDL as a single string. C<$schema> may be
a connected schema instance or a schema class name.

=cut

sub install_ddl {
  my ($class, $schema) = @_;

  my @stmts;

  for my $source_name (sort $schema->sources) {
    my $source = $schema->source($source_name);
    my $result_class = $source->result_class;
    my $table_name = $source->name;

    my @col_defs;
    my %is_pk;
    my @pk_cols = $source->primary_columns;
    @is_pk{@pk_cols} = (1) x @pk_cols;

    for my $col_name ($source->columns) {
      my $info = $source->column_info($col_name);
      my $type = _sqlite_column_type($info);

      my $def = sprintf '  %s %s', _quote_ident($col_name), $type;

      # Single-column INTEGER PRIMARY KEY (with auto-increment) is the
      # only way to opt into SQLite's ROWID alias. We emit it inline so
      # the column becomes a true rowid alias.
      if (
        @pk_cols == 1
        && $is_pk{$col_name}
        && uc($type) eq 'INTEGER'
        && $info->{is_auto_increment}
      ) {
        $def .= ' PRIMARY KEY AUTOINCREMENT';
      }

      $def .= ' NOT NULL' if defined $info->{is_nullable} && !$info->{is_nullable};

      if (defined $info->{default_value}) {
        my $dv = $info->{default_value};
        if (ref $dv eq 'SCALAR') {
          $def .= " DEFAULT $$dv";
        } else {
          $def .= " DEFAULT '$dv'";
        }
      }

      push @col_defs, $def;
    }

    # Multi-column or non-INTEGER primary key: emit as a table-level constraint
    my $had_inline_pk = (@pk_cols == 1)
      && exists $is_pk{ $pk_cols[0] }
      && do {
        my $info = $source->column_info($pk_cols[0]);
        uc(_sqlite_column_type($info)) eq 'INTEGER' && $info->{is_auto_increment};
      };
    if (@pk_cols && !$had_inline_pk) {
      push @col_defs, sprintf '  PRIMARY KEY (%s)',
        join(', ', map { _quote_ident($_) } @pk_cols);
    }

    # Unique constraints declared via add_unique_constraint
    if ($source->can('unique_constraints')) {
      my %uniques = $source->unique_constraints;
      for my $uname (sort keys %uniques) {
        next if $uname eq 'primary';
        my $cols = $uniques{$uname};
        push @col_defs, sprintf '  UNIQUE (%s)',
          join(', ', map { _quote_ident($_) } @$cols);
      }
    }

    # Foreign keys derived from belongs_to relationships
    for my $rel ($source->relationships) {
      my $info = $source->relationship_info($rel);
      next unless $info && $info->{attrs} && $info->{attrs}{is_foreign_key_constraint};

      my $foreign = $info->{class};
      my $foreign_source = eval { $schema->source($foreign) }
        // eval { $schema->source($foreign =~ s/.*:://r) };
      next unless $foreign_source;

      my $cond = $info->{cond};
      next unless ref $cond eq 'HASH';

      my (@from, @to);
      for my $foreign_col (sort keys %$cond) {
        my $fcol = $foreign_col;
        $fcol =~ s/^foreign\.//;
        my $self_col = $cond->{$foreign_col};
        $self_col =~ s/^self\.//;
        push @to,   $fcol;
        push @from, $self_col;
      }

      push @col_defs, sprintf '  FOREIGN KEY (%s) REFERENCES %s(%s)',
        join(', ', map { _quote_ident($_) } @from),
        _quote_ident($foreign_source->name),
        join(', ', map { _quote_ident($_) } @to);
    }

    push @stmts, sprintf "CREATE TABLE %s (\n%s\n);",
      _quote_ident($table_name), join(",\n", @col_defs);

    # Standalone (non-unique-constraint) indexes -- only if the result
    # class declares them via sqlite_indexes (parallel to pg_indexes)
    if ($result_class->can('sqlite_indexes')) {
      my $indexes = $result_class->sqlite_indexes;
      for my $idx_name (sort keys %$indexes) {
        my $idx = $indexes->{$idx_name};
        my $unique = $idx->{unique} ? 'UNIQUE ' : '';
        my $columns = join ', ',
          map { _quote_ident($_) } @{ $idx->{columns} // [] };
        my $sql = sprintf 'CREATE %sINDEX %s ON %s (%s)',
          $unique, _quote_ident($idx_name),
          _quote_ident($table_name), $columns;
        $sql .= " WHERE $idx->{where}" if $idx->{where};
        push @stmts, "$sql;";
      }
    }
  }

  return join "\n\n", @stmts;
}

sub _sqlite_column_type {
  my ($info) = @_;
  my $type = $info->{data_type} // 'TEXT';

  # Pre-parameterized types pass through
  return $type if $type =~ /\(.+\)$/;

  # SQLite type affinity rules: INTEGER, TEXT, BLOB, REAL, NUMERIC.
  # Map common DBIO types onto these. SQLite is permissive about types,
  # so we keep the more specific name (e.g. VARCHAR) when it round-trips
  # cleanly through introspection.
  my %type_map = (
    integer    => 'INTEGER',
    bigint     => 'INTEGER',
    smallint   => 'INTEGER',
    int        => 'INTEGER',
    serial     => 'INTEGER',
    bigserial  => 'INTEGER',

    text       => 'TEXT',
    varchar    => 'VARCHAR',
    char       => 'CHAR',
    string     => 'TEXT',

    real       => 'REAL',
    float      => 'REAL',
    double     => 'REAL',
    'double precision' => 'REAL',

    numeric    => 'NUMERIC',
    decimal    => 'NUMERIC',
    boolean    => 'BOOLEAN',

    blob       => 'BLOB',
    bytea      => 'BLOB',

    date       => 'DATE',
    datetime   => 'DATETIME',
    timestamp  => 'TIMESTAMP',
    time       => 'TIME',
  );

  return $type_map{ lc $type } // uc $type;
}

1;
