package OpenInteract2::Datasource::LDAP;

# $Id: LDAP.pm,v 1.4 2003/06/11 02:51:16 lachoy Exp $

use strict;
use Data::Dumper          qw( Dumper );
use Net::LDAP             qw();
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Datasource::LDAP::VERSION  = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use constant LDAP_PORT    => 389;
use constant LDAP_DEBUG   => 0;
use constant LDAP_TIMEOUT => 120;
use constant LDAP_VERSION => 2;

sub connect {
    my ( $class, $ds_name, $ds_info ) = @_;
    unless ( ref $ds_info ) {
        oi_error "Cannot create connection without datasource info!";
    }
    unless ( $ds_name ) {
        LOG( LALL, 'WARNING: Correct usage of connect() is',
             '$class->connect( $ds_name, \%ds_info ). Continuing...' );
    }

    unless ( $ds_info->{host} ) {
        oi_error "Key 'host' must be defined in hashref of parameters.";;
    }

    # Set defaults

    $ds_info->{port}    ||= LDAP_PORT;
    $ds_info->{debug}   ||= LDAP_DEBUG;
    $ds_info->{timeout} ||= LDAP_TIMEOUT;
    $ds_info->{version} ||= LDAP_VERSION;

    DEBUG && LOG( LDEBUG, "LDAP connect info:\n", Dumper( $ds_info ) );

    my $ldap = Net::LDAP->new( $ds_info->{host},
                               timeout => $ds_info->{timeout},
                               port    => $ds_info->{port},
                               debug   => $ds_info->{debug},
                               version => $ds_info->{version} );

    unless ( $ldap ) {
        OpenInteract2::Exception::Datasource->throw(
                    "Cannot create connection to LDAP directory",
                    { datasource_name => $ds_name,
                      datasource_type => 'LDAP',
                      connect_params  => "$ds_info->{host} $ds_info->{port}" } );
    }

    DEBUG && LOG( LDEBUG, "LDAP directory [$ds_name] connected ok." );

    if ( $ds_info->{perform_bind} ) {
        $class->bind( $ldap, $ds_info );
    }
    return $ldap;
}


sub bind {
    my ( $class, $ldap, $ds_info ) = @_;
    my %bind_params = ();
    if ( $ds_info->{sasl} and $ds_info->{bind_dn} ) {
        eval { require Authen::SASL };
        if ( $@ ) {
            oi_error "You requested SASL authentication, but Authen::SASL ",
                     "could not be loaded: $@";
        }
        $bind_params{sasl} = Authen::SASL->new(
                                   'CRAM-MD5',
                                   password => $ds_info->{bind_password} );
    }
    elsif ( $ds_info->{bind_dn} ) {
        $bind_params{password} = $ds_info->{bind_password};
    }

    DEBUG && LOG( LDEBUG, "Calling bind() with DN ($ds_info->{bind_dn}) ",
                  "and params:\n", Dumper( \%bind_params ) );
    my $bind_msg = $ldap->bind( $ds_info->{bind_dn}, %bind_params );
    if ( my $bind_code = $bind_msg->code ) {
        my $error_msg = $bind_msg->error . " (Code: $bind_code)";
        my $params    = "DN: $ds_info->{bind_dn}; " .
                        join( '; ', map { "$_ = $bind_params{$_}" }
                                        keys %bind_params );
        OpenInteract2::Exception::Datasource->throw(
                         "Bind to LDAP directory failed: $error_msg",
                         { datasource_type => 'LDAP',
                           connect_params  => $params } );
    }
    DEBUG && LOG( LDEBUG, "Bind to [$ds_info->{bind_dn}] ok" );
}


sub connect_and_bind {
    my ( $class, $ds_info, @params ) = @_;
    my $ldap = $class->connect( $ds_info, @params );
    $class->bind( $ldap, $ds_info );
    return $ldap;
}

1;

__END__

=head1 NAME

OpenInteract2::Datasource::LDAP - Centralized connection location to LDAP directories

=head1 SYNOPSIS

 # Define the parameters for an LDAP connection called 'primary'

 [datasource primary]
 type          = LDAP
 host          = localhost
 port          = 389
 base_dn       = dc=mycompany, dc=com
 timeout       = 120
 version       = 2
 sasl          =
 debug         =
 bind_dn       = cn=webuser, ou=People, dc=mycompany, dc=com
 bind_password = urkelnut
 perform_bind  = yes

 # Request the datasource 'primary' from the $OP object

 my $ldap = CTX->datasource( 'primary' );
 my $mesg =  $ldap->search( "urkelFan=yes" );
 ...

=head1 DESCRIPTION

Connect and/or bind to an LDAP directory.

=head1 METHODS

B<connect( $datasource_name, \%datasource_info )>

Parameters used in C<\%datsource_info>

=over 4

=item *

B<host>: host LDAP server is running on

=item *

B<port>: defaults to 389

=item *

B<debug>: see L<Net::LDAP|Net::LDAP> for what this will do

=item *

B<timeout>: defaults to 120

=item *

B<version>: defaults to 2; version of the LDAP protocol to use.

=item *

B<perform_bind>: if true, we perform a bind (using 'bind_dn' and
'bind_password') when we connect to the LDAP directory

=item *

B<bind_dn>: DN to bind with (if requested to bind)

=item *

B<bind_password>: password to bind with (if requested to bind)

=item *

B<sasl>: if true, use SASL when binding (if requested to bind)

=back

Returns: a L<Net::LDAP|Net::LDAP> connection. If there is an error we
throw an exception of the
L<OpenInteract2::Exception::Datasource|OpenInteract2::Exception::Datasource>
variety.

B<bind( $ldap_connection, \%bind_params )>

Bind an LDAP connection using a DN/password combination. With many
servers, you can do this more than once with a single connection.

Parameters used:

=over 4

=item *

B<bind_dn>: DN to bind as.

=item *

B<bind_password>: Password to use when binding.

=item *

B<sasl>: If set to true, use SASL for authentication. Note: this is
completely untested, and even if it works it only uses the C<CRAM-MD5>
method of authentication.

=back

Returns: LDAP handle with bind() run, or throws an exception to
explain why it failed. An
L<OpenInteract2::Exception|OpenInteract2::Exception> is thrown if a
resource could not be loaded, a
L<OpenInteract2::Exception::Datasource|OpenInteract2::Exception::Datasource>
is thrown if we could not perform the bind.

B<connect_and_bind( \%connect_params, \%other_params )>

Run both the C<connect()> and C<bind()> methods.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::Exception::Datasource|OpenInteract2::Exception::Datasource>

L<Net::LDAP|Net::LDAP>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
