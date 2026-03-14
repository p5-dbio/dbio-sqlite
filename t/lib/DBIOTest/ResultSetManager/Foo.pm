package # hide from PAUSE
    DBIOTest::ResultSetManager::Foo;

use warnings;
use strict;

use base 'DBIO::Core';

__PACKAGE__->load_components(qw/ ResultSetManager /);
__PACKAGE__->table('foo');

sub bar : ResultSet { 'good' }

1;
