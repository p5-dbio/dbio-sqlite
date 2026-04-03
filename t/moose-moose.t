use strict;
use warnings;

use Test::More;
use Test::Exception;

# -----------------------------------------------------------------------
# Schema
# -----------------------------------------------------------------------
{
  package MooseSugar::Schema;
  use base 'DBIO::Schema';
}

# -----------------------------------------------------------------------
# Moose role
# -----------------------------------------------------------------------
{
  package MooseSugar::Role::Displayable;
  use Moose::Role;

  requires 'name';

  has display_name => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_display_name',
  );
  sub _build_display_name { 'Artist: ' . $_[0]->name }
}

# -----------------------------------------------------------------------
# Result class: Moose attributes + Sugar + Cake DDL columns
# -----------------------------------------------------------------------
{
  package MooseSugar::Schema::Result::Artist;
  use DBIO::Moose;
  use DBIO::Cake;

  table 'artist';

  col id   => integer auto_inc;
  col name => varchar(100);

  primary_key 'id';

  with 'MooseSugar::Role::Displayable';

  # Moose attribute with a type constraint
  has score => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => 0,
  );

  __PACKAGE__->meta->make_immutable;
}

# -----------------------------------------------------------------------
# Connect and deploy
# -----------------------------------------------------------------------
MooseSugar::Schema->register_class( Artist => 'MooseSugar::Schema::Result::Artist' );

my $schema = MooseSugar::Schema->connect('dbi:SQLite::memory:', '', '', {
  quote_names => 0,
});
$schema->deploy;

# -----------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------

subtest 'create + columns' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Sugar Rush' });
  is( $artist->name, 'Sugar Rush', 'column works after create' );
  ok( $artist->id,   'auto_increment column populated' );
};

subtest 'lazy Moose attr from created row' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Mooseling' });
  is( $artist->display_name, 'Artist: Mooseling', 'lazy attr built from column' );
};

subtest 'Moose type constraint' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Scorer' });
  is( $artist->score, 0, 'Moose default is 0' );
  $artist->score(99);
  is( $artist->score, 99, 'Moose rw attr updated' );

  throws_ok { $artist->score('not an int') }
    qr/Validation failed|isa check/i,
    'Moose type constraint enforced';
};

subtest 'inflate_result (fetch from DB)' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Fetched' });
  my $id = $artist->id;

  my $fetched = $schema->resultset('Artist')->find($id);
  is( $fetched->name,         'Fetched',         'column works on fetched row' );
  is( $fetched->display_name, 'Artist: Fetched', 'lazy Moose attr on fetched row' );
  is( $fetched->score,        0,                 'Moose default on fetched row' );
};

subtest 'Moose role applied' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Role Player' });
  ok( $artist->DOES('MooseSugar::Role::Displayable'), 'role is applied' );
  is( $artist->display_name, 'Artist: Role Player', 'role method works' );
};

subtest 'Moose attr does NOT leak into DB columns' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Clean' });
  $artist->score(7);

  lives_ok { $artist->update({ name => 'Clean Updated' }) }
    'update with Moose attr set does not crash';
  is( $artist->name,  'Clean Updated', 'column updated correctly' );
  is( $artist->score, 7,               'Moose attr preserved after update' );
};

subtest 'make_immutable is safe' => sub {
  ok( MooseSugar::Schema::Result::Artist->meta->is_immutable,
    'class is immutable after make_immutable' );
};

done_testing;
