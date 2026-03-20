use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir tempfile);
use File::Spec;
use DBI;

eval { require DBD::SQLite }
    or plan skip_all => 'DBD::SQLite required';

eval { require DBIO::Loader }
    or plan skip_all => 'DBIO::Loader required';

my $tmpdir = tempdir(CLEANUP => 1);
my (undef, $db_file) = tempfile(SUFFIX => '.sqlite', UNLINK => 1, DIR => $tmpdir);
my $dsn = "dbi:SQLite:dbname=$db_file";

# Create a realistic SQLite schema
my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1 });
$dbh->do('PRAGMA foreign_keys = ON');

$dbh->do('CREATE TABLE artist (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(128) NOT NULL,
    bio TEXT
)');
$dbh->do('CREATE UNIQUE INDEX idx_artist_name ON artist(name)');

$dbh->do('CREATE TABLE cd (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    artist_id INTEGER NOT NULL REFERENCES artist(id),
    title VARCHAR(256) NOT NULL,
    year INTEGER,
    rating REAL
)');

$dbh->do('CREATE TABLE track (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cd_id INTEGER NOT NULL REFERENCES cd(id),
    title VARCHAR(256) NOT NULL,
    position INTEGER
)');

# Link table for m2m
$dbh->do('CREATE TABLE tag (id INTEGER PRIMARY KEY, name TEXT NOT NULL)');
$dbh->do('CREATE TABLE cd_tag (
    cd_id INTEGER NOT NULL REFERENCES cd(id),
    tag_id INTEGER NOT NULL REFERENCES tag(id),
    PRIMARY KEY (cd_id, tag_id)
)');

# Table with various column types
$dbh->do('CREATE TABLE type_test (
    id INTEGER PRIMARY KEY,
    bool_col BOOLEAN,
    date_col DATE,
    ts_col TIMESTAMP,
    num_col NUMERIC(10,2),
    blob_col BLOB
)');

$dbh->disconnect;

sub _slurp { open my $fh, '<', $_[0] or die "Cannot read $_[0]: $!"; local $/; <$fh> }

# --- Test 1: Vanilla style introspection ---

my $vanilla_dir = File::Spec->catdir($tmpdir, 'vanilla');
mkdir $vanilla_dir;

my $pid = fork();
die "fork: $!" unless defined $pid;
if (!$pid) {
    DBIO::Loader::make_schema_at('TestSQLite::Vanilla', {
        dump_directory => $vanilla_dir,
        quiet          => 1,
        generate_pod   => 0,
        naming         => 'current',
    }, [$dsn]);
    exit 0;
}
waitpid($pid, 0);
is($? >> 8, 0, 'Vanilla schema generated');

my $rd = "$vanilla_dir/TestSQLite/Vanilla/Result";

# Table detection
ok -f "$rd/Artist.pm",   'artist table found';
ok -f "$rd/Cd.pm",       'cd table found';
ok -f "$rd/Track.pm",    'track table found';
ok -f "$rd/Tag.pm",      'tag table found';
ok -f "$rd/CdTag.pm",    'cd_tag table found';
ok -f "$rd/TypeTest.pm", 'type_test table found';

# Column types
my $artist = _slurp("$rd/Artist.pm");
like $artist, qr/is_auto_increment.*1/s,   'artist.id is auto_increment';
like $artist, qr/data_type.*"varchar"/s,    'artist.name is varchar';
like $artist, qr/size.*128/s,              'artist.name size 128';

# FK detection
my $cd = _slurp("$rd/Cd.pm");
like $cd, qr/is_foreign_key.*1/s,          'cd.artist_id is FK';
like $cd, qr/belongs_to.*artist/s,         'cd belongs_to artist';

# Relationships
like $artist, qr/has_many.*cds/s,          'artist has_many cds';
like $cd, qr/has_many.*tracks/s,           'cd has_many tracks';

# M2M
like $cd, qr/many_to_many.*tags/s,         'cd many_to_many tags';

# Unique constraints
like $artist, qr/add_unique_constraint/s,  'artist has unique constraint';

# Type variety
my $types = _slurp("$rd/TypeTest.pm");
like $types, qr/data_type.*"boolean"/si,   'boolean column detected';
like $types, qr/data_type.*"blob"/si,      'blob column detected';

# --- Test 2: Cake style ---

my $cake_dir = File::Spec->catdir($tmpdir, 'cake');
mkdir $cake_dir;

$pid = fork();
die "fork: $!" unless defined $pid;
if (!$pid) {
    DBIO::Loader::make_schema_at('TestSQLite::Cake', {
        dump_directory => $cake_dir,
        quiet          => 1,
        generate_pod   => 0,
        naming         => 'current',
        loader_style   => 'cake',
    }, [$dsn]);
    exit 0;
}
waitpid($pid, 0);
is($? >> 8, 0, 'Cake schema generated');

my $cake_rd = "$cake_dir/TestSQLite/Cake/Result";
my $cake_artist = _slurp("$cake_rd/Artist.pm");

like $cake_artist, qr/use DBIO::Cake/,     'cake: uses DBIO::Cake';
like $cake_artist, qr/^col id => /m,       'cake: col DSL for id';
like $cake_artist, qr/^col name => /m,     'cake: col DSL for name';

my $cake_cd = _slurp("$cake_rd/Cd.pm");
like $cake_cd, qr/^col artist_id => .*fk/m, 'cake: FK column has fk modifier';
like $cake_cd, qr/^belongs_to\b/m,           'cake: belongs_to DSL';

done_testing;
