package # hide from PAUSE
    DBIOTest::Schema::Bookmark;

use strict;
use warnings;

use base qw/DBIOTest::BaseResult/;

__PACKAGE__->table('bookmark');
__PACKAGE__->add_columns(
    'id' => {
        data_type => 'integer',
        is_auto_increment => 1
    },
    'link' => {
        data_type => 'integer',
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key('id');

require DBIOTest::Schema::Link; # so we can get a columnlist
__PACKAGE__->belongs_to(
    link => 'DBIOTest::Schema::Link', 'link', {
    on_delete => 'SET NULL',
    join_type => 'LEFT',
    proxy => { map { join('_', 'link', $_) => $_ } DBIOTest::Schema::Link->columns },
});

1;
