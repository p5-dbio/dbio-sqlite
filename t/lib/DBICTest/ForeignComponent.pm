#   belongs to t/05components.t
package # hide from PAUSE
    DBICTest::ForeignComponent;
use warnings;
use strict;

use base qw/ DBIO /;

__PACKAGE__->load_components( qw/ +DBICTest::ForeignComponent::TestComp / );

1;
