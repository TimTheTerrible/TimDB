#!/usr/bin/perl

use strict;

use TimUtil;
use TimDB;

# Usage: ./test.pl --debug=all --dbhost=<test database host> --dbuser=<user> --dbpasswd=<user's password>
# Optional args: --dbport=<port> --dbname=<database name> --dbbackend=<mysql|Pg*>
#
# *: Yes, the capital "P" is required: "pg" won't mut the custard.

parse_args();

my $dsn = {
    dbhost	=> "localhost",
    dbname	=> "test",
    dbuser	=> "root",
    dbpass	=> qw/foo/,
    dbbackend	=> "Pg",
    dbport	=> 5432,
};

my $db = TimDB->new($dsn);

if ( $db->dbopen() == E_DB_NO_ERROR ) {

    my $returnval = E_NO_ERROR;
    my $result = 0;

    if ( ($returnval = $db->get_int(\$result,"SELECT size FROM missing_files WHERE asset_id=1969620709001")) == E_DB_NO_ERROR ) {
        debugprint(DEBUG_TRACE, "result = %s", $result);
    }
    elsif ( $returnval == E_DB_NO_ROWS ) {
        debugprint(DEBUG_WARN, "No rows returned");
    }
    else {
        debugprint(DEBUG_ERROR, "get_int() Failed!");
    }    

    $db->dbclose();
}
else {
    debugprint(DEBUG_ERROR, "Connect failed: '%s'", $db->{errstr});
    debugprint(DEBUG_INFO, "FYI: test.pl assumes that the default MySQL test database exists andis world-writable.");
}

