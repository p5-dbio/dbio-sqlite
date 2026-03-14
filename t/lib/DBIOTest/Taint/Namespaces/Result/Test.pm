package # hide from PAUSE
    DBIOTest::Taint::Namespaces::Result::Test;

use warnings;
use strict;

use base 'DBIO::Core';
__PACKAGE__->table('test');

1;
