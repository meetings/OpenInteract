#!/usr/bin/perl

use strict;
use Apache2 ();
use Apache2::OpenInteract2;
use CGI;
use Log::Log4perl;
use OpenInteract2::Config::Bootstrap;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context;

CGI->compile( ':all' );

my $BOOTSTRAP_CONFIG_FILE = '/root/vendor/OpenInteract/t/_tmp/site/conf/bootstrap.ini';

{
    Log::Log4perl::init( '/root/vendor/OpenInteract/t/_tmp/site/conf/log4perl.conf' );
    my $bootstrap = OpenInteract2::Config::Bootstrap->new({
        filename => $BOOTSTRAP_CONFIG_FILE
    });
    my $ctx = OpenInteract2::Context->create(
                    $bootstrap, { temp_lib_create => 'create' } );
    $ctx->assign_request_type( 'apache2' );
    $ctx->assign_response_type( 'apache2' );
}

1;

