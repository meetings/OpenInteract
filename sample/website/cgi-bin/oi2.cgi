#!/usr/bin/perl

# $Id: oi2.cgi,v 1.3 2003/06/11 01:58:22 lachoy Exp $

use strict;
use OpenInteract2::Auth;
use OpenInteract2::Controller;
use OpenInteract2::Context;
use OpenInteract2::Request;
use OpenInteract2::Response;

{
    my $website_dir = '[% website_dir %]';
    my $ctx = OpenInteract2::Context->create(
                                   { website_dir => $website_dir });
    $ctx->assign_request_type( 'cgi' );
    $ctx->assign_response_type( 'cgi' );

    my $response = OpenInteract2::Response->new();
    my $request  = OpenInteract2::Request->new();

    OpenInteract2::Auth->login();

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
}
