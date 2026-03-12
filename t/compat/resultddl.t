use strict;
use warnings;
use Test::More;

BEGIN {
  plan skip_all => 'DBIx::Class::ResultDDL not installed'
    unless eval { require DBIx::Class::ResultDDL; 1 };
  plan skip_all => 'DBIO::Compat::DBIxClass not yet available'
    unless eval { require DBIO::Compat::DBIxClass; 1 };
}

use lib 't/lib';
use DBIO::Compat::DBIxClass;

# Test: Compat layer loads and hooks @INC
ok(1, 'DBIO::Compat::DBIxClass loaded');

# Test: require DBIx::Class::Core works via compat
require DBIx::Class::Core;
ok(DBIx::Class::Core->can('table'), 'DBIx::Class::Core->can(table) via compat');
ok(DBIx::Class::Core->can('add_columns'), 'DBIx::Class::Core->can(add_columns) via compat');
ok(DBIx::Class::Core->can('set_primary_key'), 'DBIx::Class::Core->can(set_primary_key) via compat');
ok(DBIx::Class::Core->can('load_components'), 'DBIx::Class::Core->can(load_components) via compat');

# Test: Schema with ResultDDL loads via load_namespaces
use DBIO::Test::Schema::ResultDDL;
my $schema = DBIO::Test::Schema::ResultDDL->connect('dbi:SQLite:dbname=:memory:');
ok($schema, 'Schema connected');

# Test: Sources registered
my @sources = sort $schema->sources;
is_deeply(\@sources, [qw/Artist CD/], 'ResultDDL sources registered');

# Test: Result classes have correct table names
is($schema->source('Artist')->from, 'artist', 'Artist table name correct');
is($schema->source('CD')->from, 'cd', 'CD table name correct');

# Test: Columns are defined
my @artist_cols = sort $schema->source('Artist')->columns;
is_deeply(\@artist_cols, [qw/id name/], 'Artist columns correct');

my @cd_cols = sort $schema->source('CD')->columns;
is_deeply(\@cd_cols, [qw/artist_id id title year/], 'CD columns correct');

# Test: Primary keys set
is_deeply([$schema->source('Artist')->primary_columns], ['id'], 'Artist PK correct');
is_deeply([$schema->source('CD')->primary_columns], ['id'], 'CD PK correct');

# Test: Relationship defined
ok($schema->source('CD')->has_relationship('artist'), 'CD belongs_to artist relationship exists');

# Test: isa checks work both ways
my $artist_class = $schema->source('Artist')->result_class;
ok($artist_class->isa('DBIO::Core'), 'Result isa DBIO::Core');
ok($artist_class->isa('DBIx::Class::Core'), 'Result isa DBIx::Class::Core (via compat)');
ok($artist_class->isa('DBIO'), 'Result isa DBIO');
ok($artist_class->isa('DBIx::Class'), 'Result isa DBIx::Class (via compat)');

# Test: Deploy and do CRUD
my $dbh = $schema->storage->dbh;
$dbh->do('CREATE TABLE artist (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(100))');
$dbh->do('CREATE TABLE cd (id INTEGER PRIMARY KEY AUTOINCREMENT, artist_id INTEGER NOT NULL, title VARCHAR(255), year INTEGER, FOREIGN KEY (artist_id) REFERENCES artist(id))');

my $artist = $schema->resultset('Artist')->create({ name => 'Test Artist' });
ok($artist, 'Created artist via ResultDDL schema');
is($artist->name, 'Test Artist', 'Artist name correct');
ok($artist->id, 'Artist got auto-inc id');

my $cd = $schema->resultset('CD')->create({
  artist_id => $artist->id,
  title     => 'Test Album',
  year      => 2026,
});
ok($cd, 'Created CD via ResultDDL schema');
is($cd->title, 'Test Album', 'CD title correct');

# Test: Search works
my @albums = $schema->resultset('CD')->search({ year => 2026 })->all;
is(scalar @albums, 1, 'Search returns correct count');
is($albums[0]->title, 'Test Album', 'Search result correct');

done_testing;
