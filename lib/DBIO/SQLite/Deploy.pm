package DBIO::SQLite::Deploy;
# ABSTRACT: Deploy and upgrade SQLite schemas via test-deploy-and-compare
our $VERSION = '0.900000';

use strict;
use warnings;

use DBI;
use DBIO::SQLite::DDL;
use DBIO::SQLite::Introspect;
use DBIO::SQLite::Diff;

=head1 DESCRIPTION

C<DBIO::SQLite::Deploy> orchestrates the deployment and upgrade of
SQLite schemas using a test-deploy-and-compare strategy parallel to
L<DBIO::PostgreSQL::Deploy>.

For upgrades, instead of computing diffs from abstract class
representations, it:

=over 4

=item 1. Introspects the live database via C<sqlite_master> and PRAGMAs

=item 2. Connects to a fresh in-memory SQLite database

=item 3. Deploys the desired schema (from DBIO classes) into the in-memory DB

=item 4. Introspects the in-memory database the same way

=item 5. Computes the diff between the two models using L<DBIO::SQLite::Diff>

=back

The temp DB is in-memory and goes away when the connection drops -- much
simpler than the temp-database approach used for PostgreSQL.

    my $deploy = DBIO::SQLite::Deploy->new(
        schema => MyApp::DB->connect("dbi:SQLite:dbname=app.db"),
    );

    # Fresh install
    $deploy->install;

    # Upgrade
    $deploy->upgrade;

    # Or in steps:
    my $diff = $deploy->diff;
    print $diff->summary;
    $deploy->apply($diff) if $diff->has_changes;

=cut

sub new {
  my ($class, %args) = @_;
  bless \%args, $class;
}

sub schema { $_[0]->{schema} }

=attr schema

A connected L<DBIO::Schema> instance using the L<DBIO::SQLite> component.
Required.

=cut

=method install

    $deploy->install;

Generates DDL via L<DBIO::SQLite::DDL/install_ddl> and executes it
against the connected database. Suitable for fresh installs on an empty
database.

=cut

sub install {
  my ($self) = @_;
  my $ddl = DBIO::SQLite::DDL->install_ddl($self->schema);
  my $dbh = $self->_dbh;
  for my $stmt (_split_statements($ddl)) {
    $dbh->do($stmt);
  }
  return 1;
}

=method diff

    my $diff = $deploy->diff;

Computes the difference between the live database and the desired state
defined by the DBIO schema classes. Spins up a throwaway in-memory
SQLite to deploy the desired schema and introspect it. Returns a
L<DBIO::SQLite::Diff> object.

=cut

sub diff {
  my ($self) = @_;

  my $source_model = $self->_new_introspect($self->_dbh)->model;

  my $temp_dbh = DBI->connect('dbi:SQLite::memory:', '', '', {
    RaiseError => 1, PrintError => 0, AutoCommit => 1,
  });
  $temp_dbh->do('PRAGMA foreign_keys = ON');

  my $ddl = DBIO::SQLite::DDL->install_ddl($self->schema);
  for my $stmt (_split_statements($ddl)) {
    $temp_dbh->do($stmt);
  }

  my $target_model = $self->_new_introspect($temp_dbh)->model;
  $temp_dbh->disconnect;

  return DBIO::SQLite::Diff->new(
    source => $source_model,
    target => $target_model,
  );
}

=method apply

    $deploy->apply($diff);

Applies a L<DBIO::SQLite::Diff> object to the connected database by
executing each SQL statement from C<< $diff->as_sql >> in order. Does
nothing if the diff has no changes.

=cut

sub apply {
  my ($self, $diff) = @_;
  return unless $diff->has_changes;

  my $dbh = $self->_dbh;
  for my $stmt (_split_statements($diff->as_sql)) {
    next if $stmt =~ /^\s*--/;
    $dbh->do($stmt);
  }
  return 1;
}

=method upgrade

    my $diff = $deploy->upgrade;

Convenience: calls L</diff> then L</apply>. Returns the diff object if
changes were applied, or C<undef> if the database was already up to date.

=cut

sub upgrade {
  my ($self) = @_;
  my $diff = $self->diff;
  return unless $diff->has_changes;
  $self->apply($diff);
  return $diff;
}

# --- Internal ---

sub _dbh { $_[0]->schema->storage->dbh }

sub _new_introspect {
  my ($self, $dbh) = @_;
  return DBIO::SQLite::Introspect->new(dbh => $dbh);
}

=method _new_introspect

Factory for the introspector. Override in a subclass to use a custom
L<DBIO::SQLite::Introspect> subclass.

=cut

sub _split_statements {
  my ($sql) = @_;
  my @stmts;
  my $current = '';

  for my $line (split /\n/, $sql) {
    $current .= "$line\n";
    if ($line =~ /;\s*$/) {
      $current =~ s/^\s+|\s+$//g;
      push @stmts, $current if $current =~ /\S/;
      $current = '';
    }
  }
  $current =~ s/^\s+|\s+$//g;
  push @stmts, $current if $current =~ /\S/;

  return @stmts;
}

=seealso

=over 4

=item * L<DBIO::SQLite> - schema component

=item * L<DBIO::SQLite::DDL> - generates DDL used by C<install> and C<diff>

=item * L<DBIO::SQLite::Introspect> - reads live database state

=item * L<DBIO::SQLite::Diff> - compares two introspected models

=item * L<DBIO::PostgreSQL::Deploy> - the PostgreSQL counterpart

=back

=cut

1;
