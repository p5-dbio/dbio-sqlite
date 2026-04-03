use strict;
use warnings;

use Test::More;
use Test::Exception;

# -----------------------------------------------------------------------
# Schema
# -----------------------------------------------------------------------
{
  package MooCake::Schema;
  use base 'DBIO::Schema';
}

# -----------------------------------------------------------------------
# Result class: Moo attributes + Cake DDL columns
# -----------------------------------------------------------------------
{
  package MooCake::Schema::Result::Artist;
  use DBIO::Moo;
  use DBIO::Cake;

  table 'artist';

  col id   => integer auto_inc;
  col name => varchar(100);

  primary_key 'id';

  # Lazy Moo attribute — computed from column data on first access
  has display_name => ( is => 'lazy' );
  sub _build_display_name { 'Artist: ' . $_[0]->name }

  # Moo attribute with a default value — must be lazy so it works on
  # rows created via inflate_result (which bypasses new())
  has score => ( is => 'rw', lazy => 1, default => sub { 0 } );
}

# -----------------------------------------------------------------------
# Connect and deploy to an in-memory SQLite database
# -----------------------------------------------------------------------
MooCake::Schema->register_class( Artist => 'MooCake::Schema::Result::Artist' );

my $schema = MooCake::Schema->connect('dbi:SQLite::memory:', '', '', {
  quote_names => 0,
});
$schema->deploy;

# -----------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------

subtest 'create + columns' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Cake Baker' });
  is( $artist->name, 'Cake Baker', 'column works after create' );
  ok( $artist->id,   'auto_increment column populated' );
};

subtest 'lazy Moo attr from created row' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Lazybird' });
  is( $artist->display_name, 'Artist: Lazybird', 'lazy attr built from column' );
};

subtest 'Moo default attr' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Scorer' });
  is( $artist->score, 0, 'Moo default is 0' );
  $artist->score(42);
  is( $artist->score, 42, 'Moo rw attr updated' );
};

subtest 'inflate_result (fetch from DB)' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Fetched' });
  my $id = $artist->id;

  my $fetched = $schema->resultset('Artist')->find($id);
  is( $fetched->name,         'Fetched',          'column works on fetched row' );
  is( $fetched->display_name, 'Artist: Fetched',  'lazy attr works on fetched row' );
  is( $fetched->score,        0,                  'Moo default works on fetched row' );
};

subtest 'Moo attr does NOT leak into DB columns' => sub {
  my $artist = $schema->resultset('Artist')->create({ name => 'Clean' });
  $artist->score(99);

  # score is a Moo attr, not a DB column — update should not try to write it
  lives_ok { $artist->update({ name => 'Clean Updated' }) }
    'update with Moo attr set does not crash';
  is( $artist->name,  'Clean Updated', 'column updated correctly' );
  is( $artist->score, 99,              'Moo attr preserved after update' );
};

subtest 'search and all()' => sub {
  my @artists = $schema->resultset('Artist')->search({ name => 'Cake Baker' })->all;
  is( scalar @artists, 1, 'one artist found' );
  is( $artists[0]->display_name, 'Artist: Cake Baker', 'lazy attr on searched row' );
};

done_testing;
