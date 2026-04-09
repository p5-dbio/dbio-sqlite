package DBIO::SQLite::Introspect;
# ABSTRACT: Introspect a SQLite database via sqlite_master and PRAGMAs
our $VERSION = '0.900000';

use strict;
use warnings;

use DBIO::SQLite::Introspect::Tables;
use DBIO::SQLite::Introspect::Columns;
use DBIO::SQLite::Introspect::Indexes;
use DBIO::SQLite::Introspect::ForeignKeys;

=head1 DESCRIPTION

C<DBIO::SQLite::Introspect> reads the live state of a SQLite database
via C<sqlite_master> and the relevant C<PRAGMA> statements and returns a
unified model hashref. It is the source side of the test-deploy-and-
compare strategy used by L<DBIO::SQLite::Deploy>.

    my $intro = DBIO::SQLite::Introspect->new(dbh => $dbh);
    my $model = $intro->model;
    # $model->{tables}, $model->{columns}, $model->{indexes}, $model->{foreign_keys}

The model shape mirrors L<DBIO::PostgreSQL::Introspect> so the same
diff/deploy patterns apply, but only covers what SQLite actually has
(no schemas, types, functions, RLS).

=cut

sub new { my ($class, %args) = @_; bless \%args, $class }

sub dbh { $_[0]->{dbh} }

=attr dbh

A connected C<DBI> handle for SQLite. Required.

=cut

sub model { $_[0]->{model} //= $_[0]->_build_model }

=method model

Returns the full introspected model hashref. Built lazily.

=cut

sub _build_model {
  my ($self) = @_;

  my $tables  = DBIO::SQLite::Introspect::Tables->fetch($self->dbh);
  my $columns = DBIO::SQLite::Introspect::Columns->fetch($self->dbh, $tables);
  my $indexes = DBIO::SQLite::Introspect::Indexes->fetch($self->dbh, $tables);
  my $fks     = DBIO::SQLite::Introspect::ForeignKeys->fetch($self->dbh, $tables);

  return {
    tables       => $tables,
    columns      => $columns,
    indexes      => $indexes,
    foreign_keys => $fks,
  };
}

1;
