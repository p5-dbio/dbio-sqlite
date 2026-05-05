package DBIO::SQLite::Diff;
# ABSTRACT: Compare two introspected SQLite models
our $VERSION = '0.900000';

use strict;
use warnings;

use base 'DBIO::Diff::Base';

use DBIO::SQLite::Diff::Table;
use DBIO::SQLite::Diff::Column;
use DBIO::SQLite::Diff::Index;

=head1 DESCRIPTION

C<DBIO::SQLite::Diff> compares two introspected SQLite database models
(as produced by L<DBIO::SQLite::Introspect>) and produces a list of
structured diff operations. These operations can then be rendered to SQL
or a human-readable summary.

    my $diff = DBIO::SQLite::Diff->new(
        source => $current_model,
        target => $desired_model,
    );

    if ($diff->has_changes) {
        print $diff->as_sql;
        print $diff->summary;
    }

Operations are emitted in dependency order: tables first (so new tables
exist before columns/indexes reference them), then columns, then
indexes. Drop ops come last for each layer.

=cut

sub _build_operations {
  my ($self) = @_;
  my @ops;

  push @ops, DBIO::SQLite::Diff::Table->diff(
    $self->source->{tables}, $self->target->{tables},
    $self->target->{columns}, $self->target->{foreign_keys},
  );
  push @ops, DBIO::SQLite::Diff::Column->diff(
    $self->source->{columns}, $self->target->{columns},
    $self->source->{tables},  $self->target->{tables},
  );
  push @ops, DBIO::SQLite::Diff::Index->diff(
    $self->source->{indexes}, $self->target->{indexes},
  );

  return \@ops;
}

1;
