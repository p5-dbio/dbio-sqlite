package DBIO::SQLite::Introspect::ForeignKeys;
# ABSTRACT: Introspect SQLite foreign keys
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Fetches foreign key metadata via C<PRAGMA foreign_key_list()>. Composite
FKs are grouped by their C<id>.

=cut

=method fetch

    my $fks = DBIO::SQLite::Introspect::ForeignKeys->fetch($dbh, $tables);

Returns a hashref keyed by table name. Each value is an arrayref of
FK hashrefs with keys: C<fk_id>, C<from_columns> (arrayref),
C<to_table>, C<to_columns> (arrayref), C<on_update>, C<on_delete>,
C<match>.

=cut

sub fetch {
  my ($class, $dbh, $tables) = @_;
  my %fks;

  for my $table_name (sort keys %$tables) {
    my $list = $dbh->selectall_arrayref(
      qq{PRAGMA foreign_key_list("$table_name")}, { Slice => {} }
    );
    next unless @$list;

    my %by_id;
    for my $row (@$list) {
      my $id = $row->{id};
      $by_id{$id} //= {
        fk_id        => $id,
        from_columns => [],
        to_table     => $row->{table},
        to_columns   => [],
        on_update    => $row->{on_update},
        on_delete    => $row->{on_delete},
        match        => $row->{match},
      };
      $by_id{$id}{from_columns}[ $row->{seq} ] = $row->{from};
      $by_id{$id}{to_columns}[   $row->{seq} ] = $row->{to};
    }

    $fks{$table_name} = [ map { $by_id{$_} } sort { $a <=> $b } keys %by_id ];
  }

  return \%fks;
}

1;
