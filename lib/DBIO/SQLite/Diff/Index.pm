package DBIO::SQLite::Diff::Index;
# ABSTRACT: Diff operations for SQLite indexes
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Represents an index-level diff operation: C<CREATE INDEX> or
C<DROP INDEX>. SQLite has no C<ALTER INDEX>, so changed definitions
become a drop-then-create pair.

Auto-generated indexes (origin C<u> for UNIQUE constraints, C<pk> for
primary keys) are skipped -- they belong to the table itself, not to
explicit C<CREATE INDEX> statements.

=cut

sub new { my ($class, %args) = @_; bless \%args, $class }

sub action     { $_[0]->{action} }
sub table_name { $_[0]->{table_name} }
sub index_name { $_[0]->{index_name} }
sub index_info { $_[0]->{index_info} }

=method diff

    my @ops = DBIO::SQLite::Diff::Index->diff($source, $target);

C<$source> and C<$target> are the C<indexes> sub-models from
L<DBIO::SQLite::Introspect>: C<< { $table_name => { $idx_name => $info } } >>.

=cut

sub diff {
  my ($class, $source, $target) = @_;
  my @ops;

  for my $table_name (sort keys %$target) {
    my $src_idxs = $source->{$table_name} // {};
    my $tgt_idxs = $target->{$table_name};

    for my $name (sort keys %$tgt_idxs) {
      my $tgt = $tgt_idxs->{$name};
      next if _is_auto($tgt);

      if (!exists $src_idxs->{$name}) {
        push @ops, $class->new(
          action     => 'create',
          table_name => $table_name,
          index_name => $name,
          index_info => $tgt,
        );
        next;
      }

      my $src = $src_idxs->{$name};
      my $changed = 0;
      $changed = 1 if ($src->{is_unique} // 0) != ($tgt->{is_unique} // 0);
      $changed = 1 if join(',', @{ $src->{columns} // [] })
                   ne join(',', @{ $tgt->{columns} // [] });
      $changed = 1 if ($src->{sql} // '') ne ($tgt->{sql} // '')
                   && ($src->{sql} && $tgt->{sql});

      if ($changed) {
        push @ops, $class->new(
          action => 'drop', table_name => $table_name,
          index_name => $name, index_info => $src,
        );
        push @ops, $class->new(
          action => 'create', table_name => $table_name,
          index_name => $name, index_info => $tgt,
        );
      }
    }
  }

  for my $table_name (sort keys %$source) {
    my $src_idxs = $source->{$table_name};
    my $tgt_idxs = $target->{$table_name} // {};

    for my $name (sort keys %$src_idxs) {
      my $src = $src_idxs->{$name};
      next if _is_auto($src);
      next if exists $tgt_idxs->{$name};
      push @ops, $class->new(
        action     => 'drop',
        table_name => $table_name,
        index_name => $name,
        index_info => $src,
      );
    }
  }

  return @ops;
}

sub _is_auto {
  my ($info) = @_;
  return 0 unless defined $info->{origin};
  return $info->{origin} eq 'u' || $info->{origin} eq 'pk';
}

=method as_sql

Returns C<CREATE INDEX> (preferring the original C<sql> from
C<sqlite_master> if available) or C<DROP INDEX>.

=cut

sub as_sql {
  my ($self) = @_;

  if ($self->action eq 'create') {
    if (my $sql = $self->index_info->{sql}) {
      $sql .= ';' unless $sql =~ /;\s*$/;
      return $sql;
    }
    my $unique = $self->index_info->{is_unique} ? 'UNIQUE ' : '';
    my $cols = join ', ',
      map { _quote_ident($_) } @{ $self->index_info->{columns} // [] };
    return sprintf 'CREATE %sINDEX %s ON %s (%s);',
      $unique,
      _quote_ident($self->index_name),
      _quote_ident($self->table_name),
      $cols;
  }
  return sprintf 'DROP INDEX %s;', _quote_ident($self->index_name);
}

=method summary

=cut

sub summary {
  my ($self) = @_;
  my $prefix = $self->action eq 'create' ? '+' : '-';
  return sprintf '  %sindex: %s on %s', $prefix, $self->index_name, $self->table_name;
}

sub _quote_ident {
  my ($name) = @_;
  return $name if $name =~ /^[a-z_][a-z0-9_]*$/i;
  $name =~ s/"/""/g;
  return qq{"$name"};
}

1;
