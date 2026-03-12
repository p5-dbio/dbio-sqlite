package DBIO::SQLite::Test;
# ABSTRACT: SQLite-specific test utilities for DBIO

use strict;
use warnings;

use DBIO::Test;
use DBIO::Test::Schema;
use Carp;
use Path::Class::File ();
use File::Spec;

=head1 DESCRIPTION

Extends L<DBIO::Test> with SQLite-specific test helpers for the
L<DBIO::SQLite> driver distribution.

=head1 SYNOPSIS

  use DBIO::SQLite::Test;

  # In-memory schema (most tests)
  my $schema = DBIO::SQLite::Test->init_schema;

  # File-based schema (for reconnect/persistence tests)
  my $schema = DBIO::SQLite::Test->init_schema(sqlite_use_file => 1);

=cut

sub import {
  my $self = shift;

  # Delegate :DiffSQL and other exports to DBIO::Test
  if (@_) {
    my $caller = caller;
    # Manually re-export into caller's namespace
    for my $exp (@_) {
      if ($exp eq ':DiffSQL') {
        require DBIO::SQLMaker;
        require SQL::Abstract::Test;
        for (qw(is_same_sql_bind is_same_sql is_same_bind)) {
          no strict 'refs';
          *{"${caller}::$_"} = \&{"SQL::Abstract::Test::$_"};
        }
      }
      elsif ($exp eq ':GlobalLock') {
        # GlobalLock is a no-op in the DBIO test suite — the original
        # DBICTest locking mechanism is not needed outside of the old
        # concurrent test infrastructure.
      }
      else {
        croak "Unknown export $exp requested from $self";
      }
    }
  }
}

{
  my $dir;
  sub _vardir {
    return $dir if $dir;
    $dir = Path::Class::File->new(__FILE__)->dir->parent->parent->parent
      ->parent->subdir('t', 'var');
    $dir->mkpath unless -d "$dir";
    $dir = "$dir";
    return $dir;
  }
}

=method _sqlite_dbfilename

Returns the path to the file-based test SQLite database.

=cut

sub _sqlite_dbfilename {
  my $self = shift;
  my $holder = $ENV{DBICTEST_LOCK_HOLDER} || $$;
  $holder = $$ if $holder == -1;
  return _vardir() . "/DBIOTest-$holder.db";
}

=method _sqlite_dbname

Returns the database name — either a file path or C<:memory:>.

=cut

sub _sqlite_dbname {
  my $self = shift;
  my %args = @_;
  return $self->_sqlite_dbfilename if (
    defined $args{sqlite_use_file} ? $args{sqlite_use_file} : $ENV{'DBICTEST_SQLITE_USE_FILE'}
  );
  return ":memory:";
}

=method _database

Returns a list of C<($dsn, $user, $pass, \%opts)> suitable for
C<< $schema->connect() >>.

=cut

sub _database {
  my $self = shift;
  my %args = @_;

  if ($ENV{DBICTEST_DSN}) {
    return (
      (map { $ENV{"DBICTEST_${_}"} || '' } qw/DSN DBUSER DBPASS/),
      { AutoCommit => 1, %args },
    );
  }

  my $db_file = $self->_sqlite_dbname(%args);

  for ($db_file, "${db_file}-journal") {
    next unless -e $_;
    unlink ($_) or carp (
      "Unable to unlink existing test database file $_ ($!), "
      . "creation of fresh database / further tests may fail!"
    );
  }

  return ("dbi:SQLite:${db_file}", '', '', {
    AutoCommit => 1,
    on_connect_do => sub {
      my $storage = shift;
      my $dbh = $storage->_get_dbh;
      $dbh->do('PRAGMA synchronous = OFF');

      if (
        $ENV{DBICTEST_SQLITE_REVERSE_DEFAULT_ORDER}
          and
        $storage->_server_info->{normalized_dbms_version} >= 3.007009
      ) {
        $dbh->do('PRAGMA reverse_unordered_selects = ON');
      }
    },
    %args,
  });
}

=method init_schema

  my $schema = DBIO::SQLite::Test->init_schema(%opts);

Wrapper around L<DBIO::Test/init_schema> that defaults to an
in-memory SQLite database.

Supports all L<DBIO::Test/init_schema> options plus:

=over 4

=item sqlite_use_file

Use a file-based SQLite database instead of C<:memory:>.

=back

=cut

sub init_schema {
  my $self = shift;
  my %args = @_;

  my $schema;

  if ($args{compose_connection}) {
    $schema = DBIO::Test::Schema->compose_connection(
      'DBIO::Test', $self->_database(%args)
    );
  } else {
    $schema = DBIO::Test::Schema->compose_namespace('DBIO::Test');
  }

  if ($args{storage_type}) {
    $schema->storage_type($args{storage_type});
  }

  if (!$args{no_connect}) {
    $schema = $schema->connect($self->_database(%args));
  }

  if (!$args{no_deploy}) {
    DBIO::Test->deploy_schema($schema, $args{deploy_args});
    DBIO::Test->populate_schema($schema)
      unless $args{no_populate};
  }

  return $schema;
}

sub _cleanup_dbfile {
  my $self = shift;
  if (
    ! $ENV{DBICTEST_LOCK_HOLDER}
      or
    $ENV{DBICTEST_LOCK_HOLDER} == -1
      or
    $ENV{DBICTEST_LOCK_HOLDER} == $$
  ) {
    my $db_file = $self->_sqlite_dbfilename;
    unlink $_ for ($db_file, "${db_file}-journal");
  }
}

END {
  __PACKAGE__->_cleanup_dbfile;
}

1;
