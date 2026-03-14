package # hide from PAUSE
    DBIOTest::Schema::OneKey;

use warnings;
use strict;

use base qw/DBIOTest::BaseResult/;

__PACKAGE__->table('onekey');
__PACKAGE__->add_columns(
  'id' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  'artist' => {
    data_type => 'integer',
  },
  'cd' => {
    data_type => 'integer',
  },
);
__PACKAGE__->set_primary_key('id');


1;
