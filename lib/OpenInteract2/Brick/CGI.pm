package OpenInteract2::Brick::CGI;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'oi2.cgi' => 'OI2CGI',
    'oi2.fcgi' => 'OI2FCGI',
);

sub get_name {
    return 'cgi';
}

sub get_resources {
    return (
        'oi2.cgi' => [ 'cgi-bin oi2.cgi', 'yes' ],
        'oi2.fcgi' => [ 'cgi-bin oi2.fcgi', 'yes' ],
    );
}

sub load {
    my ( $self, $resource_name ) = @_;
    my $inline_sub_name = $INLINED_SUBS{ $resource_name };
    unless ( $inline_sub_name ) {
        OpenInteract2::Exception->throw(
            "Resource name '$resource_name' not found ",
            "in ", ref( $self ), "; cannot load content." );
    }
    return $self->$inline_sub_name();
}

OpenInteract2::Brick->register_factory_type( get_name() => __PACKAGE__ );

=pod

=head1 NAME

OpenInteract2::Brick::CGI - Script for running OI2 as a CGI

=head1 SYNOPSIS

  oi2_manage create_website --website_dir=/path/to/site

=head1 DESCRIPTION

This class holds the script for running OI2 as a CGI.

These resources are associated with OpenInteract2 version 1.99_06.

=head2 Resources

You can grab resources individually using the names below and
C<load_resource()> and C<copy_resources_to()>, or you can copy all the
resources at once using C<copy_all_resources_to()> -- see
L<OpenInteract2::Brick> for details.

=over 4


=item B<oi2.cgi>

=item B<oi2.fcgi>


=back

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS


Chris Winters E<lt>chris@cwinters.comE<gt>


=cut


sub OI2CGI {
    return <<'SOMELONGSTRING';
#!/usr/bin/perl

# $Id: oi2.cgi,v 1.5 2003/08/21 03:45:01 lachoy Exp $

use strict;
use Log::Log4perl;
use OpenInteract2::Auth;
use OpenInteract2::Controller;
use OpenInteract2::Context;
use OpenInteract2::Request;
use OpenInteract2::Response;

{
    my $website_dir = '[% website_dir %]';
    my $l4p_conf = File::Spec->catfile(
                       $website_dir, 'conf', 'log4perl.conf' );
    Log::Log4perl::init( $l4p_conf );
    my $ctx = OpenInteract2::Context->create(
                                   { website_dir => $website_dir });
    $ctx->assign_request_type( 'cgi' );
    $ctx->assign_response_type( 'cgi' );

    my $response = OpenInteract2::Response->new();
    my $request  = OpenInteract2::Request->new();

    OpenInteract2::Auth->new()->login();

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

SOMELONGSTRING
}

sub OI2FCGI {
    return <<'SOMELONGSTRING';
#!/usr/bin/perl

# $Id: oi2.fcgi,v 1.1 2005/02/18 03:29:40 lachoy Exp $

use strict;
use FCGI;
use File::Spec::Functions qw( catfile );
use Log::Log4perl;
use OpenInteract2::Auth;
use OpenInteract2::Controller;
use OpenInteract2::Context;
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
    $ctx->assign_request_type( 'cgi' );
    $ctx->assign_response_type( 'cgi' );

    my $fcgi_request = FCGI::Request();

    while ( $fcgi_request->Accept() >= 0 ) {
        my $response = OpenInteract2::Response->new();
        my $request  = OpenInteract2::Request->new();

        OpenInteract2::Auth->new()->login();

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
        $ctx->cleanup_request;
    }
}

SOMELONGSTRING
}

