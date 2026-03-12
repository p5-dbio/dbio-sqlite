package # hide from PAUSE
    DBICTest::Taint::Classes::Auto;

use warnings;
use strict;

use base 'DBIO::Core';
__PACKAGE__->table('test');

1;
