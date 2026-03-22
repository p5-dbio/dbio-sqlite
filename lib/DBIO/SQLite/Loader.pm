package DBIO::SQLite::Loader;
# ABSTRACT: SQLite introspection for DBIO::Loader
our $VERSION = '0.900000';

use strict;
use warnings;
use base 'DBIO::Loader::DBI::Component::QuotedDefault';
use mro 'c3';
use DBIO::Loader::Table ();

=head1 DESCRIPTION

This is the SQLite-specific Loader implementation used by L<DBIO::Loader>. It
extends the generic DBI loader with SQLite-specific introspection for PRAGMA
metadata, foreign keys, and the reconnect-heavy C<rescan> workflow.

For the public loader interface, see L<DBIO::Loader> and
L<DBIO::Loader::Base>.

=head1 METHODS

=head2 rescan

SQLite rejects further commands on a connection once the underlying schema has
changed. That means any runtime change requiring C<rescan> also requires a
fresh connection. This method performs that reconnect for the current schema,
but any other open SQLite connections must be refreshed separately as well.

=cut

sub _setup {
    my $self = shift;

    $self->next::method(@_);

    if (not defined $self->preserve_case) {
        $self->preserve_case(0);
    }

    if ($self->db_schema) {
        warn <<'EOF';
db_schema is not supported on SQLite, the option is implemented only for qualify_objects testing.
EOF
        if ($self->db_schema->[0] eq '%') {
            $self->db_schema(undef);
        }
    }
}

sub rescan {
    my ($self, $schema) = @_;

    $schema->storage->disconnect if $schema->storage;
    $self->next::method($schema);
}

sub _columns_info_for {
    my $self = shift;
    my ($table) = @_;

    my $result = $self->next::method(@_);

    local $self->dbh->{FetchHashKeyName} = 'NAME_lc';

    my $sth = $self->dbh->prepare(
        "pragma table_info(" . $self->dbh->quote_identifier($table) . ")"
    );
    $sth->execute;
    my $cols = $sth->fetchall_hashref('name');

    # copy and case according to preserve_case mode
    # no need to check for collisions, SQLite does not allow them
    my %cols;
    while (my ($col, $info) = each %$cols) {
        $cols{ $self->_lc($col) } = $info;
    }

    # Try table_xinfo for generated column detection (SQLite 3.31+)
    my %xinfo;
    eval {
        my $xsth = $self->dbh->prepare(
            "pragma table_xinfo(" . $self->dbh->quote_identifier($table) . ")"
        );
        $xsth->execute;
        while (my $row = $xsth->fetchrow_hashref) {
            $xinfo{ $self->_lc($row->{name}) } = $row;
        }
        $xsth->finish;
    };

    my $is_strict      = $self->_table_is_strict($table);
    my $is_without_rowid = $self->_table_is_without_rowid($table);

    my ($num_pk, $pk_col) = (0);
    # SQLite doesn't give us the info we need to do this nicely :(
    # If there is exactly one column marked PK, and its type is integer,
    # set it is_auto_increment. This isn't 100%, but it's better than the
    # alternatives.
    while (my ($col_name, $info) = each %$result) {
        if ($cols{$col_name}{pk}) {
            $num_pk++;
            if (lc($cols{$col_name}{type}) eq 'integer') {
                $pk_col = $col_name;
            }
        }
    }

    while (my ($col, $info) = each %$result) {
        if ((eval { ${ $info->{default_value} } }||'') eq 'CURRENT_TIMESTAMP') {
            ${ $info->{default_value} } = 'current_timestamp';
        }
        if ($num_pk == 1 and defined $pk_col and $pk_col eq $col) {
            $info->{is_auto_increment} = 1;
        }

        # Type affinity (SQLite storage class mapping)
        my $declared_type = uc($cols{$col}{type} || '');
        $info->{extra}{sqlite_type_affinity} = $self->_sqlite_type_affinity($declared_type);

        # JSON column awareness
        if ($declared_type =~ /JSON/) {
            $info->{extra}{sqlite_json} = 1;
        }

        # STRICT table flag
        if ($is_strict) {
            $info->{extra}{sqlite_strict} = 1;
        }

        # WITHOUT ROWID flag
        if ($is_without_rowid) {
            $info->{extra}{sqlite_without_rowid} = 1;
        }

        # Generated column detection via table_xinfo
        if (%xinfo && exists $xinfo{$col}) {
            my $hidden = $xinfo{$col}{hidden};
            if (defined $hidden && $hidden == 2) {
                $info->{extra}{generated} = 'virtual';
            }
            elsif (defined $hidden && $hidden == 3) {
                $info->{extra}{generated} = 'stored';
            }
        }
    }

    return $result;
}

sub _sqlite_type_affinity {
    my ($self, $declared_type) = @_;

    # Rules from https://www.sqlite.org/datatype3.html section 3.1
    return 'INTEGER' if $declared_type =~ /INT/;
    return 'TEXT'    if $declared_type =~ /(?:CHAR|CLOB|TEXT)/;
    return 'BLOB'   if $declared_type =~ /BLOB/ || $declared_type eq '';
    return 'REAL'    if $declared_type =~ /(?:REAL|FLOA|DOUB)/;
    return 'NUMERIC';
}

sub _table_is_strict {
    my ($self, $table) = @_;

    my $ddl = $self->_table_ddl($table);
    return 0 unless defined $ddl;
    return $ddl =~ /\)\s*STRICT\s*$/si || $ddl =~ /,\s*STRICT\s*\)/si ? 1 : 0;
}

sub _table_is_without_rowid {
    my ($self, $table) = @_;

    my $ddl = $self->_table_ddl($table);
    return 0 unless defined $ddl;
    return $ddl =~ /WITHOUT\s+ROWID\s*$/si ? 1 : 0;
}

sub _table_ddl {
    my ($self, $table) = @_;

    my $tbl_name = ref $table ? $table->name : $table;
    my $ddl = $self->dbh->selectcol_arrayref(
        "SELECT sql FROM sqlite_master WHERE tbl_name = ? AND type = 'table'",
        undef, $tbl_name,
    );
    return $ddl && $ddl->[0] ? $ddl->[0] : undef;
}

sub _table_fk_info {
    my ($self, $table) = @_;

    my $sth = $self->dbh->prepare(
        "pragma foreign_key_list(" . $self->dbh->quote_identifier($table) . ")"
    );
    $sth->execute;

    my @rels;
    while (my $fk = $sth->fetchrow_hashref) {
        my $rel = $rels[ $fk->{id} ] ||= {
            local_columns => [],
            remote_columns => undef,
            remote_table => DBIO::Loader::Table->new(
                loader => $self,
                name   => $fk->{table},
                ($self->db_schema ? (
                    schema        => $self->db_schema->[0],
                    ignore_schema => 1,
                ) : ()),
            ),
        };

        push @{ $rel->{local_columns} }, $self->_lc($fk->{from});
        push @{ $rel->{remote_columns} }, $self->_lc($fk->{to}) if defined $fk->{to};

        $rel->{attrs} ||= {
            on_delete => uc $fk->{on_delete},
            on_update => uc $fk->{on_update},
        };

        warn "This is supposed to be the same rel but remote_table changed from ",
            $rel->{remote_table}->name, " to ", $fk->{table}
            if $rel->{remote_table}->name ne $fk->{table};
    }
    $sth->finish;

    # now we need to determine whether each FK is DEFERRABLE, this can only be
    # done by parsing the DDL from sqlite_master

    my $ddl = $self->dbh->selectcol_arrayref(<<"EOF", undef, $table->name, $table->name)->[0];
select sql from sqlite_master
where name = ? and tbl_name = ?
EOF

    foreach my $fk (@rels) {
        my $local_cols  = '"?' . (join '"? \s* , \s* "?', map quotemeta, @{ $fk->{local_columns} })        . '"?';
        my $remote_cols = '"?' . (join '"? \s* , \s* "?', map quotemeta, @{ $fk->{remote_columns} || [] }) . '"?';
        my ($deferrable_clause) = $ddl =~ /
                foreign \s+ key \s* \( \s* $local_cols \s* \) \s* references \s* (?:\S+|".+?(?<!")") \s*
                (?:\( \s* $remote_cols \s* \) \s*)?
                (?:(?:
                    on \s+ (?:delete|update) \s+ (?:set \s+ null|set \s+ default|cascade|restrict|no \s+ action)
                |
                    match \s* (?:\S+|".+?(?<!")")
                ) \s*)*
                ((?:not)? \s* deferrable)?
        /sxi;

        if ($deferrable_clause) {
            $fk->{attrs}{is_deferrable} = $deferrable_clause =~ /not/i ? 0 : 1;
        }
        else {
            # check for inline constraint if 1 local column
            if (@{ $fk->{local_columns} } == 1) {
                my ($local_col)  = @{ $fk->{local_columns} };
                my ($remote_col) = @{ $fk->{remote_columns} || [] };
                $remote_col ||= '';

                my ($deferrable_clause) = $ddl =~ /
                    "?\Q$local_col\E"? \s* (?:\w+\s*)* (?: \( \s* \d\+ (?:\s*,\s*\d+)* \s* \) )? \s*
                    references \s+ (?:\S+|".+?(?<!")") (?:\s* \( \s* "?\Q$remote_col\E"? \s* \))? \s*
                    (?:(?:
                      on \s+ (?:delete|update) \s+ (?:set \s+ null|set \s+ default|cascade|restrict|no \s+ action)
                    |
                      match \s* (?:\S+|".+?(?<!")")
                    ) \s*)*
                    ((?:not)? \s* deferrable)?
                /sxi;

                if ($deferrable_clause) {
                    $fk->{attrs}{is_deferrable} = $deferrable_clause =~ /not/i ? 0 : 1;
                }
                else {
                    $fk->{attrs}{is_deferrable} = 0;
                }
            }
            else {
                $fk->{attrs}{is_deferrable} = 0;
            }
        }
    }

    return \@rels;
}

sub _table_uniq_info {
    my ($self, $table) = @_;

    my $sth = $self->dbh->prepare(
        "pragma index_list(" . $self->dbh->quote($table) . ")"
    );
    $sth->execute;

    my @uniqs;
    while (my $idx = $sth->fetchrow_hashref) {
        next unless $idx->{unique};

        my $name = $idx->{name};

        my $get_idx_sth = $self->dbh->prepare("pragma index_info(" . $self->dbh->quote($name) . ")");
        $get_idx_sth->execute;
        my @cols;
        while (my $idx_row = $get_idx_sth->fetchrow_hashref) {
            push @cols, $self->_lc($idx_row->{name});
        }
        $get_idx_sth->finish;

        # Rename because SQLite complains about sqlite_ prefixes on identifiers
        # and ignores constraint names in DDL.
        $name = (join '_', @cols) . '_unique';

        push @uniqs, [ $name => \@cols ];
    }
    $sth->finish;
    return [ sort { $a->[0] cmp $b->[0] } @uniqs ];
}

sub _tables_list {
    my ($self) = @_;

    my $sth = $self->dbh->prepare("SELECT * FROM sqlite_master");
    $sth->execute;
    my @tables;
    while ( my $row = $sth->fetchrow_hashref ) {
        next unless $row->{type} =~ /^(?:table|view)\z/i;
        next if $row->{tbl_name} =~ /^sqlite_/;
        push @tables, DBIO::Loader::Table->new(
            loader => $self,
            name   => $row->{tbl_name},
            ($self->db_schema ? (
                schema        => $self->db_schema->[0],
                ignore_schema => 1, # for qualify_objects tests
            ) : ()),
        );
    }
    $sth->finish;
    return $self->_filter_tables(\@tables);
}

sub _table_info_matches {
    my ($self, $table, $info) = @_;

    my $table_schema = $table->schema;
    $table_schema = 'main' if !defined $table_schema;
    return $info->{TABLE_SCHEM} eq $table_schema
        && $info->{TABLE_NAME}  eq $table->name;
}

=head2 _sqlite_type_affinity

Returns the SQLite type affinity class (INTEGER, TEXT, BLOB, REAL, or NUMERIC)
for a declared column type, following the rules in
L<https://www.sqlite.org/datatype3.html>.

=head2 _table_is_strict

Returns true if the table DDL ends with C<STRICT> (SQLite 3.37+).

=head2 _table_is_without_rowid

Returns true if the table DDL ends with C<WITHOUT ROWID>.

=head2 _table_ddl

Returns the raw SQL DDL string for a table from C<sqlite_master>, or C<undef>
if the table is not found.

=head1 SEE ALSO

L<DBIO::Loader>, L<DBIO::Loader::Base>,
L<DBIO::Loader::DBI>

=cut

1;
# vim:et sts=4 sw=4 tw=0:
