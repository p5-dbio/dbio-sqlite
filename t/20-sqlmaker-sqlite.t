use strict;
use warnings;

use Test::More;
use DBIO::Test ':DiffSQL';

my $schema = DBIO::Test->init_schema;

is_same_sql_bind(
  $schema->resultset('Artist')->search ({}, {for => 'update'})->as_query,
  '(SELECT me.artistid, me.name, me.rank, me.charfield FROM artist me)', [],
);

done_testing;
