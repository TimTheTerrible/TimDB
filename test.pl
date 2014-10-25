#!/usr/bin/perl

use strict;

use TimUtil;
use TimDB;

# Usage: ./test.pl --debug=all --dbhost=<test database host> --dbuser=<user> --dbpasswd=<user's password>
# Optional args: --dbport=<port> --dbname=<database name> --dbbackend=<mysql|Pg*>
#
# *: Yes, the capital "P" is required: "pg" won't mut the custard.

parse_args();

my $a = { foo => 1 };
my $b = { bar => 1 };
my $c = { %$a, %$b };

debugdump(DEBUG_ALL, "c", $c);

exit;

my $db = TimDB->new();

if ( $db->dbopen() == E_DB_NO_ERROR ) {

    my $result = [];

    if ( $db->get_hashref_array($result,"SELECT User,Host FROM user") == E_DB_NO_ERROR ) {
        debugdump(DEBUG_TRACE, "result", $result);
    }
    else {
        debugprint(DEBUG_ERROR, "get_hashref() Failed!");
    }    

    $db->dbclose();
}
else {
    debugprint(DEBUG_ERROR, "Connect failed: '%s'", $db->{errstr});
    debugprint(DEBUG_INFO, "FYI: test.pl assumes that the default MySQL test database exists andis world-writable.");
}

