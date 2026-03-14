package # hide from PAUSE
    DBIOTest::Schema::ArtistSubclass;

use warnings;
use strict;

use base 'DBIOTest::Schema::Artist';

__PACKAGE__->table(__PACKAGE__->table);

1;