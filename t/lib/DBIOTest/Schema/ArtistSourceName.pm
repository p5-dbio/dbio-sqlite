package # hide from PAUSE
    DBIOTest::Schema::ArtistSourceName;

use warnings;
use strict;

use base 'DBIOTest::Schema::Artist';
__PACKAGE__->table(__PACKAGE__->table);
__PACKAGE__->source_name('SourceNameArtists');

1;
