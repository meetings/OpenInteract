package OpenInteract2::Action::Logout;

# $Id: Logout.pm,v 1.5 2004/03/19 05:42:22 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use OpenInteract2::Constants qw( SESSION_COOKIE );
use OpenInteract2::Context   qw( CTX DEPLOY_URL );
use OpenInteract2::Cookie;

$OpenInteract2::Action::Logout::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub handler {
    my ( $self ) = @_;
    OpenInteract2::Cookie->expire( SESSION_COOKIE );
    my $request = CTX->request;
    $request->auth_clear;
    my $redirect_info = CTX->lookup_redirect_config;
    if ( my $url = $request->param( 'return_to' ) ) {
        CTX->response->return_url( $url );
    }
    if ( $redirect_info->{use_header_redirect} ) {
        CTX->response->redirect;
        return undef;
    }
    else {
        eval { CTX->controller->no_template( 'yes' ) };
        my $return_url = CTX->response->return_url;
        return $self->generate_content( { return_url => $return_url },
                                        { name => 'base::logout' } );
    }
}

1;
