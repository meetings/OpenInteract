#!/usr/bin/perl

use strict;
use Apache::OpenInteract2;
use Apache::OpenInteract2::HttpAuth;
use OpenInteract2::Config::Base;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context;

my $BASE_CONFIG_FILE = '[% website_dir %]/conf/base.conf';

{
    my $base_config = OpenInteract2::Config::Base->new(
                              { filename => $BASE_CONFIG_FILE } );
    my $ctx = OpenInteract2::Context->create(
                    $base_config, { temp_lib_create => 'create' } );
    $ctx->assign_request_type( 'apache' );
    $ctx->assign_response_type( 'apache' );
}

1;
