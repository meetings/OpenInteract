package Apache::OpenInteract2;

# $Id: OpenInteract2.pm,v 1.11 2003/08/21 03:45:01 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Auth;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Request;
use OpenInteract2::Response;

sub handler($$) {
    my ( $class, $r ) = @_;
    my $log = get_logger( LOG_OI );

    $log->is_info &&
        $log->info( scalar( localtime ), ": request from ",
                    "[", $r->connection->remote_ip, "] for URL ",
                    "[", $r->uri, '?', scalar( $r->args ), "]" );

    my $response = OpenInteract2::Response->new({ apache => $r });
    my $request  = OpenInteract2::Request->new({ apache => $r });

    my $http_auth_user = $r->pnotes( 'login_user' );
    my $auth = OpenInteract2::Auth->new({ user => $http_auth_user });
    $auth->login();

    my $controller = eval {
        OpenInteract2::Controller->new( $request, $response )
    };
    if ( $@ ) {
        $response->content( $@ );
    }
    else {
        $controller->execute;
    }
    $response->send;
    return $response->status;
}

1;

__END__

=head1 NAME

Apache::OpenInteract2 - OpenInteract2 Content handler for Apache 1.x

=head1 SYNOPSIS

 # Need to tell Apache to run an initialization script

 PerlRequire /path/to/my/site/conf/startup.pl

 # In httpd.conf file (or 'Include'd virtual host file)
 <Location />
    SetHandler perl-script
    PerlHandler Apache::OpenInteract2
</Location>

=head1 DESCRIPTION

This external interface to OpenInteract2 just sets up the
L<OpenInteract2::Request|OpenInteract2::Request> and
L<OpenInteract2::Response|OpenInteract2::Response> objects, creates an
L<OpenInteract2::Controller|OpenInteract2::Controller> and retrieves
the content from it, then sets the content in the response and returns
the proper error code to make Apache happy.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

