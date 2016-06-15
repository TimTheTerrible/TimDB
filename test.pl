#!/usr/bin/perl

use strict;

use TimUtil;
use TimDB;

# Usage: ./test.pl --debug=all --dbhost=<test database host> --dbuser=<user> --dbpasswd=<user's password>
# Optional args: --dbport=<port> --dbname=<database name> --dbbackend=<mysql|Pg*>
#
our $Tuna;
my %ParamDefs = ( 
    "tuna" => {
        name    => "Tuna",
        type    => PARAMTYPE_STRING,
        var     => \$Tuna,
        usage   => "--tuna|-t",
        comment => "The name of the fish",
    },
);

register_params(\%ParamDefs);
parse_args();

my $dsn = {
    dbhost	=> "localhost",
    dbname	=> "test",
    dbuser	=> "test",
    dbpass	=> qw/test/,
    dbbackend	=> "Pg",
    dbport	=> 5432,
};

my $DB = TimDB->new($dsn);

if ( $DB->dbopen() == E_DB_NO_ERROR ) {

    my $returnval = E_NO_ERROR;

    my $queryspec = {
        action	=> ACTION_SELECT,
        select	=> "*",
        join	=> "foo",
        where	=> [
            "bar != 0",
            "baz not like '%mumble%'",
        ],
        limit	=> "3",
        order	=> "bar",
    };

    my $query = $DB->query($queryspec);

    my $result = [];
    if ( ($returnval = $DB->get_hashref_array($result,$query)) == E_DB_NO_ERROR ) {
        debugdump(DEBUG_DUMP, "result", $result);
    }
    elsif ( $returnval == E_DB_NO_ROWS ) {
        debugprint(DEBUG_WARN, "No rows returned");
    }
    else {
        debugprint(DEBUG_ERROR, "get_hashref_array() Failed!");
    }    

    $DB->dbclose();
}
else {
    debugprint(DEBUG_ERROR, "Connect failed: '%s'", $DB->{errstr});
    debugprint(DEBUG_INFO, "FYI: test.pl assumes that the included test database exists and is world-readable.");
}

