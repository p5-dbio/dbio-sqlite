package # hide from PAUSE
    DBIOTest::Schema::CollectionObject;

use warnings;
use strict;

use base qw/DBIOTest::BaseResult/;

__PACKAGE__->table('collection_object');
__PACKAGE__->add_columns(
  'collection' => {
    data_type => 'integer',
  },
  'object' => {
    data_type => 'integer',
  },
);
__PACKAGE__->set_primary_key(qw/collection object/);

__PACKAGE__->belongs_to( collection => "DBIOTest::Schema::Collection",
                         { "foreign.collectionid" => "self.collection" }
                       );
__PACKAGE__->belongs_to( object => "DBIOTest::Schema::TypedObject",
                         { "foreign.objectid" => "self.object" }
                       );

1;
