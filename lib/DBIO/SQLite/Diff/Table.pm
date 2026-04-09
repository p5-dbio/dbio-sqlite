package DBIO::SQLite::Diff::Table;
# ABSTRACT: Diff operations for SQLite tables
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Represents a table-level diff operation in SQLite: C<CREATE TABLE> or
C<DROP TABLE>. Unlike PostgreSQL, where the table shell can be created
empty and columns added one at a time, SQLite is much friendlier when
the full table definition is emitted at once -- so for C<create>
operations the SQL is generated directly from the introspected target
columns (and any FKs / PK constraints) inline.

=cut

sub new { my ($class, %args) = @_; bless \%args, $class }

sub action       { $_[0]->{action} }
sub table_name   { $_[0]->{table_name} }
sub table_info   { $_[0]->{table_info} }
sub columns      { $_[0]->{columns} }
sub foreign_keys { $_[0]->{foreign_keys} }

=method diff

    my @ops = DBIO::SQLite::Diff::Table->diff(
        $source_tables, $target_tables,
        $target_columns, $target_fks,
    );

Compares two table hashrefs (keyed by table name) and returns C<create>
ops for tables present only in target and C<drop> ops for tables only in
source. C<create> ops capture the target columns and FKs so C<as_sql>
can render the full inline definition.

=cut

sub diff {
  my ($class, $source, $target, $target_columns, $target_fks) = @_;
  $target_columns //= {};
  $target_fks     //= {};

  my @ops;

  for my $name (sort keys %$target) {
    next if exists $source->{$name};
    push @ops, $class->new(
      action       => 'create',
      table_name   => $name,
      table_info   => $target->{$name},
      columns      => $target_columns->{$name} // [],
      foreign_keys => $target_fks->{$name}     // [],
    );
  }

  for my $name (sort keys %$source) {
    next if exists $target->{$name};
    push @ops, $class->new(
      action     => 'drop',
      table_name => $name,
      table_info => $source->{$name},
    );
  }

  return @ops;
}

=method as_sql

Returns the SQL for this operation. For C<create>, emits a full
C<CREATE TABLE> with columns, primary key, and foreign keys inline. For
C<drop>, emits C<DROP TABLE>.

=cut

sub as_sql {
  my ($self) = @_;

  if ($self->action eq 'drop') {
    return sprintf 'DROP TABLE %s;', _quote_ident($self->table_name);
  }

  my @col_defs;
  my @pk_cols;

  for my $col (@{ $self->columns }) {
    push @pk_cols, $col->{column_name} if $col->{is_pk};

    my $type = $col->{data_type} || 'TEXT';
    my $def = sprintf '  %s %s', _quote_ident($col->{column_name}), $type;
    $def .= ' NOT NULL' if $col->{not_null};
    if (defined $col->{default_value}) {
      $def .= " DEFAULT $col->{default_value}";
    }
    push @col_defs, $def;
  }

  # Multi-column PK becomes a table-level constraint. Single-column INTEGER
  # PRIMARY KEY is left inline (it's already part of the column type
  # roundtrip via introspection -- pk=1 in the column metadata).
  if (@pk_cols > 1) {
    push @col_defs, sprintf '  PRIMARY KEY (%s)',
      join(', ', map { _quote_ident($_) } @pk_cols);
  }

  for my $fk (@{ $self->foreign_keys }) {
    push @col_defs, sprintf '  FOREIGN KEY (%s) REFERENCES %s(%s)',
      join(', ', map { _quote_ident($_) } @{ $fk->{from_columns} }),
      _quote_ident($fk->{to_table}),
      join(', ', map { _quote_ident($_) } @{ $fk->{to_columns} });
  }

  return sprintf "CREATE TABLE %s (\n%s\n);",
    _quote_ident($self->table_name), join(",\n", @col_defs);
}

=method summary

=cut

sub summary {
  my ($self) = @_;
  my $prefix = $self->action eq 'create' ? '+' : '-';
  return sprintf '%s table: %s', $prefix, $self->table_name;
}

sub _quote_ident {
  my ($name) = @_;
  return $name if $name =~ /^[a-z_][a-z0-9_]*$/i;
  $name =~ s/"/""/g;
  return qq{"$name"};
}

1;
