#   belongs to t/05components.t
package # hide from PAUSE
    DBIOTest::ForeignComponent;
use warnings;
use strict;

use base qw/ DBIO /;

__PACKAGE__->load_components( qw/ +DBIOTest::ForeignComponent::TestComp / );

1;
