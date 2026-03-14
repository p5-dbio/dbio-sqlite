package DBIOTestAdminInc;

use warnings;
use strict;

use base 'DBIOTest::BaseSchema';

sub connect { exit 70 } # this is what the test will expect to see

1;
