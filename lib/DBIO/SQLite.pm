package DBIO::SQLite;
# ABSTRACT: SQLite-specific schema management for DBIO

use strict;
use warnings;

use base 'DBIO';

=head1 SYNOPSIS

  package MyApp::Schema;
  use base 'DBIO::Schema';
  __PACKAGE__->load_components('DBIO::SQLite');

  # storage_type is set to +DBIO::SQLite::Storage by the component
  my $schema = __PACKAGE__->connect('dbi:SQLite:db/app.db');

=head1 DESCRIPTION

L<DBIO::SQLite> is the SQLite driver distribution for DBIO.

When this component is loaded into a schema class, C<connection()> sets
L<DBIO::Schema/storage_type> to C<+DBIO::SQLite::Storage>, enabling
SQLite-specific storage behavior.

=head1 MIGRATION NOTES

SQLite storage and SQLMaker classes were split out of the historical
DBIx::Class monolithic distribution:

=over 4

=item *

Old: C<DBIx::Class::Storage::DBI::SQLite>

=item *

New: C<DBIO::SQLite::Storage>

=item *

Old: C<DBIx::Class::SQLMaker::SQLite>

=item *

New: C<DBIO::SQLite::SQLMaker>

=back

If C<DBIO-SQLite> is installed, core L<DBIO::Storage::DBI> can autodetect
SQLite DSNs and load the new storage class via the driver registry.

=head1 TESTING

SQLite tests in this distribution use in-memory databases and do not require
database credentials.

=head1 METHODS

=method connection

Overrides L<DBIO/connection> to force C<+DBIO::SQLite::Storage> as
C<storage_type>.

=cut

sub connection {
  my ($self, @info) = @_;
  $self->storage_type('+DBIO::SQLite::Storage');
  return $self->next::method(@info);
}

1;
