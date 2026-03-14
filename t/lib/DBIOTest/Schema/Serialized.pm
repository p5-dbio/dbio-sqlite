package # hide from PAUSE
    DBIOTest::Schema::Serialized;

use warnings;
use strict;

use base qw/DBIOTest::BaseResult/;

__PACKAGE__->table('serialized');
__PACKAGE__->add_columns(
  'id' => { data_type => 'integer', is_auto_increment => 1 },
  'serialized' => { data_type => 'text' },
);
__PACKAGE__->set_primary_key('id');

1;
