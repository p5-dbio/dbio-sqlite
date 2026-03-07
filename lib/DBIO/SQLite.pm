package DBIO::SQLite;
# ABSTRACT: SQLite-specific schema management for DBIO

use strict;
use warnings;

use base 'DBIO';

sub connection {
  my ($self, @info) = @_;
  $self->storage_type('+DBIO::SQLite::Storage');
  return $self->next::method(@info);
}

1;
