package DBICTest::SQLMRebase;

use warnings;
use strict;

our @ISA = qw( DBIO::SQLMaker::ClassicExtensions SQL::Abstract );

__PACKAGE__->mk_group_accessors( simple => '__select_counter' );

sub select {
  $_[0]->{__select_counter}++;
  shift->next::method(@_);
}

1;
