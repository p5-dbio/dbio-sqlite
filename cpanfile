requires 'perl', '5.020';
requires 'DBIO';
requires 'DBI';
requires 'DBD::SQLite';
requires 'namespace::clean';
requires 'DateTime::Format::SQLite';

on test => sub {
  requires 'Test::More', '0.98';
  requires 'Test::Exception';
  requires 'Test::Warn';
  requires 'Math::BigInt';
  requires 'Time::HiRes';
  requires 'File::Temp';
  requires 'DBIO::Test';
};
