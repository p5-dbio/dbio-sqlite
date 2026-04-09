package DBIO::SQLite::Diff::Column;
# ABSTRACT: Diff operations for SQLite columns
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Represents a column-level diff operation in SQLite. Only ADD COLUMN is
supported as a true ALTER -- SQLite has very limited C<ALTER TABLE>:
since 3.25 it can rename columns and since 3.35 it can drop columns,
but type changes still require the create-new-table-and-copy dance.

For now this module emits:

=over 4

=item * C<ALTER TABLE ... ADD COLUMN ...> for added columns

=item * C<ALTER TABLE ... DROP COLUMN ...> for dropped columns (3.35+)

=item * A descriptive comment for type / nullability changes (manual
        rewrite required)

=back

Brand-new tables get their columns inline via L<DBIO::SQLite::Diff::Table>
-- this module only sees columns of tables that exist in both source
and target.

=cut

sub new { my ($class, %args) = @_; bless \%args, $class }

sub action      { $_[0]->{action} }
sub table_name  { $_[0]->{table_name} }
sub column_name { $_[0]->{column_name} }
sub old_info    { $_[0]->{old_info} }
sub new_info    { $_[0]->{new_info} }

=method diff

    my @ops = DBIO::SQLite::Diff::Column->diff(
        $source_columns, $target_columns,
        $source_tables,  $target_tables,
    );

Compares column lists for tables that exist in both source and target.

=cut

sub diff {
  my ($class, $source_cols, $target_cols, $source_tables, $target_tables) = @_;
  my @ops;

  for my $table_name (sort keys %$target_cols) {
    next unless exists $source_tables->{$table_name}
             && exists $target_tables->{$table_name};

    my %source_by_name = map { $_->{column_name} => $_ } @{ $source_cols->{$table_name} // [] };
    my %target_by_name = map { $_->{column_name} => $_ } @{ $target_cols->{$table_name} // [] };

    for my $col_name (sort keys %target_by_name) {
      my $tgt = $target_by_name{$col_name};

      if (!exists $source_by_name{$col_name}) {
        push @ops, $class->new(
          action      => 'add',
          table_name  => $table_name,
          column_name => $col_name,
          new_info    => $tgt,
        );
        next;
      }

      my $src = $source_by_name{$col_name};
      my $changed = 0;
      $changed = 1 if uc($src->{data_type} // '') ne uc($tgt->{data_type} // '');
      $changed = 1 if ($src->{not_null} // 0) != ($tgt->{not_null} // 0);
      $changed = 1 if (defined $src->{default_value} ? $src->{default_value} : '')
                   ne (defined $tgt->{default_value} ? $tgt->{default_value} : '');

      if ($changed) {
        push @ops, $class->new(
          action      => 'alter',
          table_name  => $table_name,
          column_name => $col_name,
          old_info    => $src,
          new_info    => $tgt,
        );
      }
    }

    for my $col_name (sort keys %source_by_name) {
      next if exists $target_by_name{$col_name};
      push @ops, $class->new(
        action      => 'drop',
        table_name  => $table_name,
        column_name => $col_name,
        old_info    => $source_by_name{$col_name},
      );
    }
  }

  return @ops;
}

=method as_sql

Returns the C<ALTER TABLE> statement for this operation, or a comment
for unsupported alterations.

=cut

sub as_sql {
  my ($self) = @_;

  if ($self->action eq 'add') {
    my $info = $self->new_info;
    my $type = $info->{data_type} || 'TEXT';
    my $sql  = sprintf 'ALTER TABLE %s ADD COLUMN %s %s',
      _quote_ident($self->table_name),
      _quote_ident($self->column_name),
      $type;
    $sql .= ' NOT NULL' if $info->{not_null};
    if (defined $info->{default_value}) {
      $sql .= " DEFAULT $info->{default_value}";
    }
    return "$sql;";
  }
  if ($self->action eq 'drop') {
    return sprintf 'ALTER TABLE %s DROP COLUMN %s;',
      _quote_ident($self->table_name),
      _quote_ident($self->column_name);
  }
  if ($self->action eq 'alter') {
    return sprintf
      "-- ALTER COLUMN not supported by SQLite ALTER TABLE; rebuild required for %s.%s\n"
      . "-- old: %s%s\n-- new: %s%s",
      $self->table_name, $self->column_name,
      ($self->old_info->{data_type} // ''),
      ($self->old_info->{not_null}  ? ' NOT NULL' : ''),
      ($self->new_info->{data_type} // ''),
      ($self->new_info->{not_null}  ? ' NOT NULL' : '');
  }
}

=method summary

=cut

sub summary {
  my ($self) = @_;
  my $prefix = $self->action eq 'add' ? '+' : $self->action eq 'drop' ? '-' : '~';
  my $type = $self->new_info ? " ($self->{new_info}{data_type})" : '';
  return sprintf '  %scolumn: %s.%s%s', $prefix, $self->table_name, $self->column_name, $type;
}

sub _quote_ident {
  my ($name) = @_;
  return $name if $name =~ /^[a-z_][a-z0-9_]*$/i;
  $name =~ s/"/""/g;
  return qq{"$name"};
}

1;
