use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
  eval { require Moo; 1 }
    or plan skip_all => 'Moo not installed';
}

use DBIO::Test::Schema::Moo;

# -----------------------------------------------------------------------
# Connect to in-memory SQLite and deploy
# -----------------------------------------------------------------------
my $schema = DBIO::Test::Schema::Moo->connect('dbi:SQLite::memory:', '', '', {
  quote_names => 0,
});
$schema->deploy;

my $artist_rs = $schema->resultset('Result::Artist');
my $cd_rs     = $schema->resultset('Result::CD');

# -----------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------

subtest 'create + columns' => sub {
  my $artist = $artist_rs->create({ name => 'Cake Baker' });
  is( $artist->name, 'Cake Baker', 'column works after create' );
  ok( $artist->id,   'auto_increment column populated' );
};

subtest 'lazy Moo attr from created row' => sub {
  my $artist = $artist_rs->create({ name => 'Lazybird' });
  is( $artist->display_name, 'Artist: Lazybird', 'lazy builder on created row' );
};

subtest 'Moo default attr' => sub {
  my $artist = $artist_rs->create({ name => 'Scorer' });
  is( $artist->score, 0, 'lazy default is 0' );
  $artist->score(42);
  is( $artist->score, 42, 'rw attr updated' );
};

subtest 'inflate_result (fetch from DB)' => sub {
  my $artist = $artist_rs->create({ name => 'Fetched' });
  my $id = $artist->id;

  my $fetched = $artist_rs->find($id);
  is( $fetched->name,         'Fetched',          'column works on fetched row' );
  is( $fetched->display_name, 'Artist: Fetched',  'lazy attr on fetched row' );
  is( $fetched->score,        0,                  'Moo default on fetched row' );
};

subtest 'Moo attr does NOT leak into DB columns' => sub {
  my $artist = $artist_rs->create({ name => 'Clean' });
  $artist->score(99);

  lives_ok { $artist->update({ name => 'Clean Updated' }) }
    'update with Moo attr set does not crash';
  is( $artist->name,  'Clean Updated', 'column updated correctly' );
  is( $artist->score, 99,              'Moo attr preserved after update' );
};

subtest 'search and all()' => sub {
  my @found = $artist_rs->search({ name => 'Cake Baker' })->all;
  is( scalar @found, 1, 'one artist found' );
  is( $found[0]->display_name, 'Artist: Cake Baker', 'lazy attr on searched row' );
};

subtest 'CD: create with has_many relationship' => sub {
  my $artist = $artist_rs->create({ name => 'Band' });
  my $cd = $cd_rs->create({ artist_id => $artist->id, title => 'First Album', year => 2024 });

  is( $cd->title,      'First Album',       'CD column set' );
  is( $cd->full_title, 'First Album (2024)', 'CD lazy builder works' );
  is( $cd->rating,     0,                   'CD lazy default' );

  my @cds = $artist->cds->all;
  is( scalar @cds, 1, 'has_many returns one CD' );
  is( $cds[0]->title, 'First Album', 'CD from relationship correct' );
};

done_testing;
