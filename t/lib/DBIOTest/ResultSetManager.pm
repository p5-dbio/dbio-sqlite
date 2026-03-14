package # hide from PAUSE
    DBIOTest::ResultSetManager;

use warnings;
use strict;

use base 'DBIOTest::BaseSchema';

__PACKAGE__->load_classes("Foo");

1;
