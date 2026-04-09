package DBIO::SQLite::Introspect::Indexes;
# ABSTRACT: Introspect SQLite indexes
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Fetches index metadata via C<PRAGMA index_list()> and C<PRAGMA
index_info()>, plus the original C<CREATE INDEX> statement from
C<sqlite_master> for partial / expression indexes. Skips
auto-generated indexes (PRIMARY KEY, UNIQUE constraint indexes).

=cut

=method fetch

    my $indexes = DBIO::SQLite::Introspect::Indexes->fetch($dbh, $tables);

Returns a hashref keyed by table name. Each value is a hashref keyed by
index name. Each index entry has: C<index_name>, C<is_unique>,
C<columns> (arrayref), C<sql> (CREATE statement, may be undef for
auto-generated UNIQUE indexes), C<origin> (C<c>=CREATE, C<u>=UNIQUE,
C<pk>=PRIMARY KEY), C<partial> (1 if WHERE clause present).

=cut

sub fetch {
  my ($class, $dbh, $tables) = @_;
  my %indexes;

  # Lookup of CREATE INDEX statements from sqlite_master so we can detect
  # partial indexes and recover the original column expressions.
  my $sql_lookup = $dbh->selectall_hashref(
    q{SELECT name, sql FROM sqlite_master WHERE type = 'index'},
    'name',
  );

  for my $table_name (sort keys %$tables) {
    my $list = $dbh->selectall_arrayref(
      qq{PRAGMA index_list("$table_name")}, { Slice => {} }
    );

    my %t_idx;
    for my $idx (@$list) {
      my $info = $dbh->selectall_arrayref(
        qq{PRAGMA index_info("$idx->{name}")}, { Slice => {} }
      );
      my @cols = map { $_->{name} // '' } sort { $a->{seqno} <=> $b->{seqno} } @$info;

      my $sql = $sql_lookup->{ $idx->{name} }
        ? $sql_lookup->{ $idx->{name} }{sql}
        : undef;

      my $partial = ($sql && $sql =~ /\bWHERE\b/i) ? 1 : 0;

      $t_idx{ $idx->{name} } = {
        index_name => $idx->{name},
        is_unique  => $idx->{unique} ? 1 : 0,
        columns    => \@cols,
        sql        => $sql,
        origin     => $idx->{origin},
        partial    => $partial,
      };
    }
    $indexes{$table_name} = \%t_idx if %t_idx;
  }

  return \%indexes;
}

1;
