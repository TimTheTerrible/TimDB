#!/usr/bin/perl

use strict;

use TimUtil;
use TimDB;

# Usage: ./test.pl --debug=all --dbhost=<test database host> --dbuser=<user> --dbpasswd=<user's password>
# Optional args: --dbport=<port> --dbname=<database name> --dbbackend=<mysql|Pg*>
#
# *: Yes, the capital "P" is required: "pg" won't mut the custard.

parse_args();

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
}

my %hash = ();
$db->get_hashref(\%hash, "select * from transactions where id=19045");

debugdump(DEBUG_DUMP, "hash", \%hash);

#my $int = 0;
#$db->get_int(\$int, "select count(*) from transactions where id=-1");
#debugprint(DEBUG_TRACE, "int = '%s'", $int)
