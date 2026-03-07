package DBIO::SQLite::SQLMaker;
# ABSTRACT: SQLite-specific SQL generation for DBIO

use warnings;
use strict;

use base qw( DBIO::SQLMaker );

#
# SQLite does not understand SELECT ... FOR UPDATE
# Disable it here
sub _lock_select () { '' };

1;
