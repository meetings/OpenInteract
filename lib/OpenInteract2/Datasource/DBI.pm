package OpenInteract2::Datasource::DBI;

# $Id: DBI.pm,v 1.7 2003/06/25 16:47:53 lachoy Exp $

use strict;
use DBI                      qw();
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_datasource_error );

$OpenInteract2::Datasource::DBI::VERSION  = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_READ_LEN => 32768;
use constant DEFAULT_TRUNC_OK => 0;

sub connect {
    my ( $class, $ds_name, $ds_info ) = @_;
    my $log = get_logger( LOG_DS );
    unless ( ref $ds_info ) {
        $log->error( "No data given to create DBI [$ds_name] handle" );
        oi_error "Cannot create connection without datasource info";
    }
    unless ( $ds_name ) {
        $log->warn( 'Correct usage of connect() is',
                    '$class->connect( $ds_name, \%ds_info ). ',
                    'Continuing...' );
    }

    unless ( $ds_info->{driver_name} ) {
        $log->error( "Required configuration key undefined ",
                     "'datasource.$ds_name.driver_name'" );
        oi_error "Value for 'driver_name' must be defined in ",
                 "datasource [$ds_name]";
    }

    # Make the connection -- let the 'die' trickle up to our caller if
    # it happens

    my $dsn      = "DBI:$ds_info->{driver_name}:$ds_info->{dsn}";
    my $username = $ds_info->{username};
    my $password = $ds_info->{password};

    $log->is_debug &&
        $log->debug( "Trying to connect to DBI with:",
                     CTX->dump( $ds_info ) );

    my $db = DBI->connect( $dsn, $username, $password );
    unless ( $db ) {
        oi_datasource_error
                    "Error connecting: $DBI::errstr",
                    { datasource_name => $ds_name,
                      datasource_type => 'DBI',
                      connect_params  => "$dsn , $username , $password" };
    }

    # We don't set this until here so we can control the format of the
    # error...

    $db->{RaiseError}  = 1;
    $db->{PrintError}  = 0;
    $db->{ChopBlanks}  = 1;
    $db->{AutoCommit}  = 1;
    $db->{LongReadLen} = $ds_info->{long_read_len} || DEFAULT_READ_LEN;
    $db->{LongTruncOk} = $ds_info->{long_trunc_ok} || DEFAULT_TRUNC_OK;

    if ( $ds_info->{trace_level} ) {
        $db->trace( $ds_info->{trace_level} );
    }
    $log->is_debug &&
        $log->debug( "Extra parameters [LongReadLen: $db->{LongReadLen}] ",
                     "[LongTruncOk: $db->{LongTruncOk}] ",
                     "[Trace: $ds_info->{trace_level}]" );
    $log->is_info &&
        $log->info( "DBI connection [$ds_name] made ok" );
    return $db;
}

sub disconnect {
    my ( $class, $handle ) = @_;
    my $log = get_logger( LOG_DS );
    $log->is_info &&
        $log->info( "Disconnecting handle [$handle->{Name}]" );
    eval { $handle->disconnect };
    oi_error $@ if ( $@ );
}

1;

__END__

=head1 NAME

OpenInteract2::Datasource::DBI - Create DBI database handles

=head1 SYNOPSIS

 # Define the parameters for a database handle 'main'

 [datasource main]
 type          = DBI
 db_owner      =
 username      = webuser
 password      = urkelnut
 dsn           = dbname=urkelweb
 driver_name   = Pg
 long_read_len = 65536
 long_trunc_ok = 0
 
 # Request the datasource 'main' from the context object (which in
 # turn requests it from the OpenInteract2::DatasourceManager object,
 # which in turn requests it from this class)
 
 my $dbh = CTX->datasource( 'main' );
 my $sth = $dbh->prepare( "SELECT * FROM urkel_fan" );
 $sth->execute;
 ...

=head1 DESCRIPTION

No, we do not subclass DBI with this. No, we do not override any of
the DBI methods. Instead, we provide the means to connect to the
database from one location using nothing more than a datasource
name. This is somewhat how the Java Naming and Directory Interface
(JNDI) allows you to manage objects, including database connections.

Note that if you are using it this should work flawlessly (although
pointlessly) with L<Apache::DBI|Apache::DBI>, and if you are using this
on a different persistent Perl platform (say, PerlEx) then this module
gives you a single location from which to retrieve database handles --
this makes using the BEGIN/END tricks ActiveState recommends in their
FAQ pretty trivial.

=head1 METHODS

B<connect( $datasource_name, \%datasource_info )>

Returns: A DBI database handle with the following parameters set:

 RaiseError:  1
 PrintError:  0
 ChopBlanks:  1
 AutoCommit:  1 (for now...)
 LongReadLen: 32768 (or as set in \%datasource_info)
 LongTruncOk: 0 (or as set in \%datasource_info)

The parameter C<\%datasource_info> defines how we connect to the
database.

=over 4

=item *

B<dsn> ($)

The last part of a fully-formed DBI data source name used to
connect to this database. Examples:

 Full DBI DSN:     DBI:mysql:webdb
 OpenInteract DSN: webdb

 Full DBI DSN:     DBI:Pg:dbname=web
 OpenInteract DSN: dbname=web

 Full DBI DSN:     DBI:Sybase:server=SYBASE;database=web
 OpenInteract DSN: server=SYBASE;database=web

So the OpenInteract DSN string only includes the database-specific items
for DBI, the third entry in the colon-separated string. This third
item is generally separated by semicolons and usually specifies a
database name, hostname, packet size, protocol version, etc. See your
DBD driver for what to do.

=item *

B<driver_name> ($)

What DBD driver is used to connect to your database?  (Examples:
'Pg', 'Sybase', 'mysql', 'Oracle')

=item *

B<username> ($)

What username should we use to login to this database?

=item *

B<password> ($)

What password should we use in combination with the username to login
to this database?

=item *

B<db_owner> ($) (optional)

Who owns this database? Only use if your database uses the database
owner to differentiate different tables.

=item *

B<long_read_len> ($) (optional)

Set the C<LongReadLen> value for the database handle (See L<DBI|DBI>
for information on what this means.) If not set this defaults to
32768.

=item *

B<long_trunc_ok> (bool) (optional)

Set the C<LongTruncOk> value for the database handle (See L<DBI|DBI>
for information on what this means.) If not set this defaults to false.

=item *

B<trace_level> ($) (optional)

Use the L<DBI|DBI> C<trace()> method to output logging information for
all calls on a database handle. Default is '0', which is no
tracing. As documented by L<DBI|DBI>, the levels are:

    0 - Trace disabled.
    1 - Trace DBI method calls returning with results or errors.
    2 - Trace method entry with parameters and returning with results.
    3 - As above, adding some high-level information from the driver
        and some internal information from the DBI.
    4 - As above, adding more detailed information from the driver.
        Also includes DBI mutex information when using threaded Perl.
    5 and above - As above but with more and more obscure information.

=back

Any errors encountered will throw an exception, usually of the
L<OpenInteract2::Exception::Datasource|OpenInteract2::Exception::Datasource>
variety.

=head1 SEE ALSO

L<OpenInteract2::Exception::Datasource|OpenInteract2::Exception::Datasource>

L<Apache::DBI|Apache::DBI>

L<DBI|DBI> - http://www.symbolstone.org/technology/perl/DBI

PerlEx - http://www.activestate.com/Products/PerlEx/

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
