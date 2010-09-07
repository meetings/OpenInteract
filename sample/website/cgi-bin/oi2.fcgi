#!/usr/bin/perl

# $Id: oi2.fcgi,v 1.2 2006/02/01 20:22:10 a_v Exp $

use strict;
use CGI::Fast;
use File::Spec::Functions qw( catfile );
use Log::Log4perl qw(get_logger);
use OpenInteract2::Auth;
use OpenInteract2::Controller;
use OpenInteract2::Context;
use OpenInteract2::Constants qw(:log);
use OpenInteract2::Request;
use OpenInteract2::Response;

{
    my $website_dir = '[% website_dir %]';
    my $l4p_conf = File::Spec->catfile(
                       $website_dir, 'conf', 'log4perl.conf' );
    Log::Log4perl::init( $l4p_conf );
    my $ctx = OpenInteract2::Context->create({
        website_dir => $website_dir
    });

    my $log = get_logger(LOG_APP);

    $log->debug("Creating context");

    my $ctx = OpenInteract2::Context->create({
        website_dir => $website_dir
    });

    $log->debug("Assigning request and response types");

    $ctx->assign_request_type( 'cgi' );
    $ctx->assign_response_type( 'cgi' );

    $log->debug("Waiting for a client request");

    while ( my $fcgi_request = CGI::Fast->new ) { # ) $fcgi_request->Accept() >= 0 ) {
        $SPOPS::Tie::COUNT = {};

        #DB::enable_profile();

        $log->debug("Got a request");

        $log->debug("Creating response");
        my $response = OpenInteract2::Response->new({ cgi => $fcgi_request });

        $log->debug("Creating request");
        my $request  = OpenInteract2::Request->new({ cgi => $fcgi_request });

        $log->debug("Calling auth->new");

        OpenInteract2::Auth->new()->login();

        $log->debug("Creating controller object");

        my $controller = eval {
            OpenInteract2::Controller->new( $request, $response )
        };
        if ( $@ ) {
            $log->error("Controller returned error: $@");
            $response->content( $@ );
        }
        else {
            $log->debug("Executing controller");
            $controller->execute;
        }

        $log->debug("Sending response");

        $response->send;

        $log->debug("Cleaning up");

        $ctx->cleanup_request;

        #DB::disable_profile();
    }
}
