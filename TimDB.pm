#!/usr/bin/perl

package TimDB;

use strict;

use DBI;
use TimUtil;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
    E_DB_NO_ERROR
    E_DB_INVALID_STATE
    E_DB_CONNECT_FAILED
    E_DB_PREPARE_FAILED
    E_DB_EXECUTE_FAILED
    E_DB_NO_ROWS
    $DBHost
    $DBPort
    $DBUser
    $DBPasswd
    $DBName
    $DBBackEnd
);

# Debug Modes
use constant DEBUG_DB	=> 0x00100000;

# Unused place-holders...
use constant DEBUG_DB1	=> 0x00200000;
use constant DEBUG_DB2	=> 0x00400000;
use constant DEBUG_DB3	=> 0x00800000;

my %DebugModes = (
    (DEBUG_DB) => {
        name => "db",
        title => "DEBUG_DB",
    },
);

# Errors
use constant E_DB_NO_ERROR		=> E_NO_ERROR;
use constant E_DB_INVALID_STATE         => 42001;
use constant E_DB_CONNECT_FAILED        => 42002;
use constant E_DB_PREPARE_FAILED        => 42003;
use constant E_DB_EXECUTE_FAILED        => 42004;
use constant E_DB_NO_ROWS               => 42005;

# Error Messages
my %ErrorMessages = (
    (E_DB_NO_ERROR)	=> {
        title => "E_DB_NO_ERROR",
        message => "No DB Error",
    },
    (E_DB_INVALID_STATE)	=> {
        title => "E_DB_INVALID_STATE",
        message => "Invalid DB State",
    },
    (E_DB_CONNECT_FAILED)	=> {
        title => "E_DB_CONNECT_FAILED",
        message => "DB Connect Failed",
    },
    (E_DB_PREPARE_FAILED)	=> {
        title => "E_DB_PREPARE_FAILED",
        message => "DB Prepare Failed",
    },
    (E_DB_EXECUTE_FAILED)	=> {
        title => "E_DB_EXECUTE_FAILED",
        message => "DB Execute Failed",
    },
    (E_DB_NO_ROWS)	=> {
        title => "E_DB_NO_ROWS",
        message => "No DB rows returned",
    },
);

# object state
use constant STATE_CLOSED	=> 0;
use constant STATE_OPEN		=> 1;
use constant STATE_ERROR	=> 2;

my %States = (
    (STATE_CLOSED)	=> "Closed",
    (STATE_OPEN)	=> "Open",
    (STATE_ERROR)	=> "Error",
);

# DSN
our $DBHost = "localhost";
our $DBPort = 3306;
our $DBName = "mysql";
our $DBUser = "mysql";
our $DBPasswd = "";
our $DBBackEnd = "mysql";

# Default Parameters
my %ParamDefs = (
    "dbhost" => {
        name	=> "Database Host",
        type	=> PARAMTYPE_STRING,
        var	=> \$DBHost,
        usage   => "--dbhost",
        comment => "Hostname of database server",
    },
    "dbport" => {
        name	=> "TCP Port on Database Host",
        type	=> PARAMTYPE_INT,
        var	=> \$DBPort,
        usage   => "--dbport",
        comment => "MySQL TCP Port on database server",
    },
    "dbname" => {
        name	=> "Database Name",
        type	=> PARAMTYPE_STRING,
        var	=> \$DBName,
        usage   => "--dbname",
        comment => "Name of database to use",
    },
    "dbuser" => {
        name	=> "Database User Name",
        type	=> PARAMTYPE_STRING,
        var	=> \$DBUser,
        usage   => "--dbuser",
        comment => "Username to use when connecting to database",
    },
    "dbpasswd" => {
        name	=> "Database User Password",
        type	=> PARAMTYPE_STRING,
        var	=> \$DBPasswd,
        usage   => "--dbpasswd",
        comment => "Password to supply when connecting to database",
    },
    "dbbackend" => {
        name	=> "Database Back End (MySQL; PgSQL)",
        type	=> PARAMTYPE_STRING,
        var	=> \$DBBackEnd,
        usage   => "--dbbackend",
        comment => "Database Back End driver to use when connectiong to database server",
    },
);

#
# Methods
#

# TimDB::new
sub TimDB::new
{
    my $class = shift;
    my ($dsn) = @_;

    # The caller can optionally provide a DSN that serves as the base for
    # this object...
    my $self = $dsn;

    # If a DSN was not provided, create one from either the default values or those from the command line...
    $self = {
        dbhost		=> $DBHost,
        dbport		=> $DBPort,
        dbname		=> $DBName,
        dbuser		=> $DBUser,
        dbpasswd	=> $DBPasswd,
        dbbackend	=> $DBBackEnd,
    } unless $self;

    # Well bless my little hash!
    bless($self, $class);

    # Start out closed...
    $self->{state} = STATE_CLOSED;

    $self->{stopOnFatalError} = TRUE;

    return $self;
}

# TimDB::dbopen
sub TimDB::dbopen
{
    my $self = shift;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    if ( $self->{state} == STATE_CLOSED ) {
        my $DSN = sprintf("DBI:%s:dbname=%s;host=%s;port=%s", $self->{dbbackend}, $self->{dbname}, $self->{dbhost}, $self->{dbport});
        debugdump(DEBUG_DB, "DSN", $DSN);
        debugprint(DEBUG_DB, "Connecting as '%s::%s'", $self->{dbuser}, $self->{dbpasswd});

        if ( $self->{dbh} = DBI->connect($DSN, $self->{dbuser}, $self->{dbpasswd}, {PrintError=>0}) ) {
            debugprint(DEBUG_DB, "connection opened");
            $self->{state} = STATE_OPEN;
            $self->{dbh}->{AutoCommit} = 1;
        }
        else {
            debugprint(DEBUG_ERROR, "connection open failed!!!");
            $self->{state} = STATE_ERROR;
            $self->{errstr} = DBI->errstr;
            $returnval = E_DB_CONNECT_FAILED;
        }
    }
    elsif ( $self->{state} == STATE_OPEN ) {
        debugprint(DEBUG_DB, "Connection is already open...");
    }
    else {
        my $message = sprintf("Attempted dbopen() while in state '%s'", $States{$self->{state}});
        debugprint(DEBUG_ERROR, $message);
        $returnval = E_DB_INVALID_STATE;

        # TODO: Do we really want to die() here?
        die($message) if $self->{stopOnFatalError};
    }

    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));

    return $returnval;
}

# TimDB::dbclose
sub TimDB::dbclose
{
    my $self = shift;

    debugprint(DEBUG_TRACE, "Entering...");

    # Check the error status and record it...
    $self->check_error(0);

    # Disconnect...
    if ( $self->{state} == STATE_OPEN ) {
        $self->{dbh}->disconnect();
    }

    # Throw away the handle...
    delete($self->{dbh});

    # Prevent any further use of this instance...
    $self->{state} = STATE_CLOSED;

    debugprint(DEBUG_TRACE, "Returning State: %s", $States{$self->{state}});

    return $self->{state};
}

# TimDB::check_error
sub TimDB::check_error
{
    my $self = shift;

    # This is so that check_error() only overwrites $returnval if there's an error...
    my ($returnval) = @_;

    debugprint(DEBUG_TRACE, "Entering...");

    if ( $DBI::err ) {
        $self->{errstr} = $DBI::errstr;
        $self->{state} = STATE_ERROR;
        $returnval = E_DB_INVALID_STATE;
        debugprint(DEBUG_ERROR, "DBI Error detected: %s", $self->{errstr});
    }

    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));

    return $returnval;
}

# TimDB::defer
sub TimDB::defer
{
    my $self = shift;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    # Make sure we're in a valid state...
    if ( $self->{state} == STATE_OPEN ) {

        # Call begin_work() to enable transactions...
        debugprint(DEBUG_DB, "Enabling Transactions...");
        $self->{dbh}->begin_work();

        # Make sure it worked...
        if ( ($returnval = $self->check_error($returnval)) != E_DB_NO_ERROR ) {
            debugprint(DEBUG_ERROR, "Failed to enable transactions: '%s'", $self->{dbh}->errstr());

            # Close the connection; it's crap now anyway...
            $self->dbclose();
        }
    }
    else {
        $returnval = E_DB_INVALID_STATE;
        debugprint(DEBUG_ERROR, "Invalid Operation: Enable Tranasactions while closed");
    }

    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));

    return $returnval;
}

# TimDB::resume
sub TimDB::resume
{
    my $self = shift;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    # Make sure we're in a valid state...
    if ( $self->{state} == STATE_OPEN ) {

        # Try to commit any pending transactions...
        debugprint(DEBUG_DB, "Disabling Transactions and calling commit()...");
        $self->{dbh}->commit();

        # Make sure it worked...
        if ( ($returnval = $self->check_error($returnval)) != E_DB_NO_ERROR ) {
            debugprint(DEBUG_ERROR, "Failed to commit transactions: '%s'", $self->{dbh}->errstr());

            # Close the connection; it's crap now anyway...
            $self->dbclose();
        }
    }
    else {
        $returnval = E_DB_INVALID_STATE;
        debugprint(DEBUG_ERROR, "Invalid Operation: enable AutoCommit while closed");
    }

    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));

    return $returnval;
}

# TimDB::abort
sub TimDB::abort
{
    my $self = shift;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    # Make sure we're in a valid state...
    if ( $self->{state} == STATE_OPEN ) {

        # Try to roll back any pending transactions...
        debugprint(DEBUG_DB, "Rolling back deferred transactions...");
        $self->{dbh}->rollback();

        if ( ($returnval = $self->check_error($returnval) != E_DB_NO_ERROR ) {
            debugprint(DEBUG_ERROR, "Failed to roll back transactions: '%s'", $self->{dbh}->errstr());

            # Close the connection; it's crap now anyway...
            $self->dbclose();
        }
    }
    else {
        $returnval = E_DB_INVALID_STATE;
        debugprint(DEBUG_ERROR, "Invalid Operation: rollback transactions while closed");
    }

    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));

    return $returnval;
}

# TimDB::execute
sub TimDB::execute
{
    my $self = shift;
    my ($query) = @_;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    debugprint(DEBUG_DB, "query: " . $query);

    # Validate our internal state...
    if ( $self->{state} == STATE_OPEN ) {

        # Prepare the statement...
        if ( $self->{sth} = $self->{dbh}->prepare($query) ) {

            debugprint(DEBUG_DB, "Prepared: " . ($self->{sth}->errstr ? $self->{sth}->errstr : "OK"));

            # Execute it...
            debugprint(DEBUG_DB, "Executing...");
            if ( $self->{sth}->execute() ) {
                debugprint(DEBUG_DB, "Executed: " . ($self->{sth}->errstr ? $self->{sth}->errstr : "OK"));

                $self->{rows} = $self->{sth}->rows();
                debugprint(DEBUG_DB, "%d rows affected", $self->{rows});

                debugprint(DEBUG_DB, "Transaction enabled; changes may be delayed.")
                    if $self->{dbh}->{AutoCommit} != 0;
            }
            else {
                debugprint(DEBUG_ERROR, "Query execute failed!!!");
                $returnval = E_DB_EXECUTE_FAILED;
                $self->{state} = STATE_ERROR;
                $self->{errstr} = $self->{sth}->errstr;
            }

        }
        else {
            debugprint(DEBUG_ERROR, "Query prepare failed!!!");
            $returnval = E_DB_PREPARE_FAILED;
            $self->{state} = STATE_ERROR;
            $self->{errstr} = $self->{dbh}->errstr;
        }

    }
    else {
        $returnval = E_DB_INVALID_STATE;
        $self->{state} = STATE_ERROR;
        $self->{errstr} = "Tried to EXECUTE with a CLOSEd db object!";
    }

    # Just in case...
    $returnval = $self->check_error($returnval);

    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));

    return $returnval;
}

# TimDB::dbexec
sub TimDB::dbexec
{
    my $self = shift;
    my($query) = @_;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    # Open the connection to the database...
    if ( ($returnval = $self->dbopen()) == E_DB_NO_ERROR ) {

        debugprint(DEBUG_DB, "query: " . $query);

        $self->{rows} = $self->{dbh}->do($query);
        debugprint(DEBUG_DB, "%d rows affected", $self->{rows});

        $returnval = $self->check_error($returnval);

        # Don't do this, it breaks transactions...
        # $self->dbclose();
    }
    else {
        debugprint(DEBUG_ERROR, "Failed to open DB connection!");
    }
    
    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));
    
    return $returnval;
}   

# TimDB::get_int
sub TimDB::get_int
{
    my $self = shift;
    my($num,$query) = @_;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    # Open the connection to the database...
    if ( ($returnval = $self->dbopen()) == E_DB_NO_ERROR ) {

        # Execute the query...
        if ( ($returnval = $self->execute($query)) == E_DB_NO_ERROR ) {

            my $result = $self->{sth}->fetchrow();

            if ( defined($result) ) {
                $$num = $result;
            }
            else {
                $returnval = E_DB_NO_ROWS;
            }
            
            $self->{sth}->finish();
        }
        else {
            debugprint(DEBUG_ERROR, "Failed to execute query!");
        }

        # Don't do this, it breaks transactions...
        # $self->dbclose();
    }
    else {
        debugprint(DEBUG_ERROR, "Failed to open DB connection!");
    }
    
    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));
    
    return $returnval;
}   

# TimDB::get_str
sub TimDB::get_str
{
    my $self = shift;
    my($str_ref,$query) = @_;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    # Open the connection to the database...
    if ( ($returnval = $self->dbopen()) == E_DB_NO_ERROR ) {

        # Execute the query...
        if ( ($returnval = $self->execute($query)) == E_DB_NO_ERROR ) {

            my $result = $self->{sth}->fetchrow();

            if ( defined($result) ) {
                $$str_ref = $result;
            }
            else {
                $returnval = E_DB_NO_ROWS;
            }

            $self->{sth}->finish();
        }
        else {
            debugprint(DEBUG_ERROR, "Failed to execute query!");
        }

        # Don't do this, it breaks transactions...
        # $self->dbclose();
    }
    else {
        debugprint(DEBUG_ERROR, "Failed to open DB connection!");
    }
    
    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));
    
    return $returnval;
}   

# TimDB::get_hashref
sub TimDB::get_hashref
{
    my $self = shift;
    my($hashref,$query) = @_;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    # Open the connection to the database...
    if ( ($returnval = $self->dbopen()) == E_DB_NO_ERROR ) {

        # Execute the query...
        if ( ($returnval = $self->execute($query)) == E_DB_NO_ERROR ) {

            # Fetch the first (and hopefully, only) row...
	    my $result = $self->{sth}->fetchrow_hashref('NAME_lc');

            if ( defined($result) ) {
                %$hashref = %{$result};
            }
            else {
                debugprint(DEBUG_DB, "Query returned no results");
                $returnval = E_DB_NO_ROWS;
            }

            debugdump(DEBUG_DUMP, "hashref", $hashref);

            $self->{sth}->finish();
        }
        else {
            debugprint(DEBUG_ERROR, "Failed to execute query!");
        }

        $self->dbclose();
    }
    else {
        debugprint(DEBUG_ERROR, "Failed to open DB connection!");
    }
    
    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));
    
    return $returnval;
}   

# TimDB::get_hashref_array
sub TimDB::get_hashref_array
{
    my $self = shift;
    my ($rows,$query) = @_;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    # Open the connection to the database...
    if ( ($returnval = $self->dbopen()) == E_DB_NO_ERROR ) {

        # Execute the query...
        if ( ($returnval = $self->execute($query)) == E_DB_NO_ERROR ) {

            # Empty the array if we got results...
            @$rows = () if $self->{sth}->rows;

            # Loop until all rows have been retrieved...
            while ( my $row = $self->{sth}->fetchrow_hashref('NAME_lc') ) {
                push(@$rows, $row);
            }

            $returnval = E_DB_NO_ROWS unless @$rows;

            $self->{sth}->finish();
        }
        else {
            debugprint(DEBUG_ERROR, "Failed to execute query!");
        }

        $self->dbclose();
    }
    else {
        debugprint(DEBUG_ERROR, "Failed to open DB connection!");
    }

    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));

    return $returnval;
}

# TimDB::get_array
sub TimDB::get_array
{
    my $self = shift;
    my ($rows,$query) = @_;
    my $returnval = E_DB_NO_ERROR;

    debugprint(DEBUG_TRACE, "Entering...");

    # Open the connection to the database...
    if ( ($returnval = $self->dbopen()) == E_DB_NO_ERROR ) {

        # Execute the query...
        if ( ($returnval = $self->execute($query)) == E_DB_NO_ERROR ) {

            # Empty the array if we got results...
            @$rows = () if $self->{sth}->rows;

            # Loop until all rows have been retrieved...
            while ( my $row = $self->{sth}->fetchrow() ) {
                push(@$rows, $row);
            }

            $self->{sth}->finish();
        }
        else {
            debugprint(DEBUG_ERROR, "Failed to execute query!");
        }

        # Don't do this, it breaks transactions...
        # $self->dbclose();
    }
    else {
        debugprint(DEBUG_ERROR, "Failed to open DB connection!");
    }

    debugprint(DEBUG_TRACE, "Returning: %s", error_message($returnval));

    return $returnval;
}

# TimDB::num_rows
sub TimDB::num_rows
{
    my $self = shift;

    my $result = 0;

    if ( $self->{state} != STATE_CLOSED ) {
        $result = $self->{rowcount};
    }

    return $result;
}

# TimDB::agglom_hash
sub TimDB::agglom_hash
{
    my $self = shift;

    my ($hash) = @_;
    my $result;

    foreach my $key ( keys(%$hash) ) {
        $result .= sprintf("%s='%s',", $key, $$hash{$key});
    }

    chop($result);

    return $result;
}

#
# Module Initialization
#

debugprint(DEBUG_TRACE, "Beginning intiailization...");

# Register TimDB-specific debug modes...
register_debug_modes(\%DebugModes);

# Register TimDB-specific error messages...
register_error_messages(\%ErrorMessages);

# Register TimDB-specific parameters...
register_params(\%ParamDefs);

debugprint(DEBUG_TRACE, "Intiailization Complete!");

# Done!

return SUCCESS;

