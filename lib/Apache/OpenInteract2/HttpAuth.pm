package Apache::OpenInteract2::HttpAuth;

# $Id: HttpAuth.pm,v 1.9 2004/02/22 04:41:48 lachoy Exp $

use strict;
use Apache::Constants        qw( FORBIDDEN AUTH_REQUIRED OK );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

my ( $log );

sub handler {
    my ( $r ) = @_;
    $log ||= get_logger( LOG_AUTH );

    unless ( $r->some_auth_required ) {
        $log->error( "Asked to process authentication request ",
                              "but no authentication configured" );
        $r->log_reason( "No authentication has been configured" );
        return FORBIDDEN;
    }

    my ( $res, $password_sent ) = $r->get_basic_auth_pw;

    # e.g., HTTP_UNAUTHORIZED
    if ( $res ) {
        $log->is_info &&
            $log->info( "Got result [$res] from auth" );
        return $res;
    }

    my $user_sent = $r->connection->user;
    $log->is_debug &&
        $log->debug( "Trying to authenticate [$user_sent]" );
    unless ( $user_sent ) {
        return AUTH_REQUIRED;
    }

    my $user = CTX->lookup_object( 'user' )
                  ->fetch_by_login_name( $user_sent, { skip_security => 1 } );
    unless ( $user ) {
        $log->is_info &&
            $log->info( "User [$user_sent] is not in OI" );
        $r->log_reason( "User [$user_sent] is not in OI" );
        return AUTH_REQUIRED;
    }
    unless ( $user->check_password( $password_sent ) ) {
        $log->is_info &&
            $log->info( "User [$user->{login_name}] found but password ",
                             "mismatch" );
        $r->log_reason( "User [$user->{login_name}] exists, but password ",
                        "does not match" );
        return AUTH_REQUIRED;
    }
    $log->is_debug &&
        $log->debug( "User [$user->{login_name}] auth ok" );
    $r->pnotes( 'login_user', $user );
    return OK;
}

1;

__END__

=head1 NAME

Apache::OpenInteract2::HttpAuth - Use HTTP authentication to check logins against OpenInteract2 users

=head1 SYNOPSIS

 # In httpd.conf file, or in .htaccess
 
 # People must login to get to anything under /foo
 
 <Location /foo>
   # This is the normal OI content handler...
   SetHandler perl-script
   PerlHandler Apache::OpenInteract2

   # ...this is the auth configuration
   PerlAuthenHandler Apache::OpenInteract2::HttpAuth
   AuthName "My Site Authentication"
   AuthType Basic
   Require valid-user
   Order deny,allow
   Allow from all
 </Location>

=head1 DESCRIPTION

Simple Apache 1.x authentication handler that uses HTTP authentication
rather than the normal cookie-based authentication. Fetch the user
object with the given username from OpenInteract2 -- if it's not found
then the request is denied. If the object is found and the passwords
don't match then the request is denied.

Otherwise we store the fetched user object in the Apache property
C<pnotes> under the key 'login_user'. OI2 should handle this for you
in its own authentication handler by first checking for this value in
C<pnotes>.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
