package #hide from pause
  DBIOTest::Base;

use strict;
use warnings;

# must load before any DBIO* namespaces
use DBIOTest::RunMode;

sub _skip_namespace_frames { '^DBIOTest' }

1;
