package DBIO::SQLite::SQLMaker;
# ABSTRACT: SQLite-specific SQL generation for DBIO
our $VERSION = '0.900000';

use warnings;
use strict;

use base qw( DBIO::SQLMaker );

=head1 DESCRIPTION

SQLite-specific subclass of L<DBIO::SQLMaker>. Disables C<SELECT ... FOR UPDATE>
locking syntax, which SQLite does not support. All other SQL generation is
inherited from L<DBIO::SQLMaker>.

This class is set as the C<sql_maker_class> by L<DBIO::SQLite::Storage> and
is not normally instantiated directly.

=seealso

=over

=item * L<DBIO::SQLMaker> - Base SQL generation class

=item * L<DBIO::SQLite::Storage> - Storage driver that uses this SQL maker

=item * L<DBIO::SQLite> - Top-level SQLite schema component

=back

=cut

#
# SQLite does not understand SELECT ... FOR UPDATE
# Disable it here
sub _lock_select () { '' };

1;
