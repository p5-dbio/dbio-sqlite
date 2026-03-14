package DBIOTest::Schema::ResultDDL::Result::Artist;
use DBIx::Class::ResultDDL qw/ -V2 /;
table 'artist';
col id   => integer, unsigned, auto_inc;
col name => varchar(100), null;
primary_key 'id';
1;
