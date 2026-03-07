use strict;
use warnings;
use Test::More;

my @modules = qw(
  DBIO::SQLite
  DBIO::SQLite::Storage
  DBIO::SQLite::SQLMaker
);

plan tests => scalar @modules;

for my $mod (@modules) {
  use_ok($mod);
}
