package OpenInteract2::Response::LWP;

# $Id: LWP.pm,v 1.15 2003/06/27 17:15:51 lachoy Exp $

use strict;
use base qw( OpenInteract2::Response );
use HTTP::Response;
use HTTP::Status             qw( RC_OK RC_FOUND );
use IO::File;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Response::LWP::VERSION  = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( lwp_response client );
OpenInteract2::Response::LWP->mk_accessors( @FIELDS );

my ( $CURRENT );

sub init {
    my ( $self, $params ) = @_;
    $self->client( $params->{client} );
    $self->lwp_response( $params->{response} );
    $CURRENT = $self;
    return $self;
}

sub get_current   { return $CURRENT }
sub clear_current { $CURRENT = undef }

sub send {
    my ( $self ) = @_;
    my $log = get_logger( LOG_RESPONSE );

    $log->is_info && $log->info( "Sending LWP response" );
    $self->content_type( 'text/html' ) unless ( $self->content_type );
    $self->status( RC_OK )             unless ( $self->status );

    $self->save_session;
    $log->is_info && $log->info( "Saved session ok" );

    if ( $self->lwp_response ) {
        $self->lwp_response->code( $self->status );
    }
    else {
        $self->lwp_response( HTTP::Response->new( $self->status ) );
    }
    if ( my $filename = $self->send_file ) {
        $self->set_file_info;
        $self->_set_lwp_headers;
        my $fh = IO::File->new( "< $filename" )
                    || oi_error "Cannot open file [$filename]: $!";
        $self->client->send_file( $fh );
        $log->is_info &&
            $log->info( "Sent file [$filename] directly to client" );
        return;
    }
    $self->_set_lwp_headers;
    $self->lwp_response->content(
          ( ref $self->content ) ? ${ $self->content } : $self->content
    );
    if ( my $client = $self->client ) {
        $client->send_response( $self->lwp_response );
        $log->is_info &&
            $log->info( "Sent response ok" );
    }
    else {
        $log->is_info &&
            $log->info( "Set content/headers but did not send content" );
    }
}


sub redirect {
    my ( $self, $url ) = @_;
    my $log = get_logger( LOG_RESPONSE );

    my $lwp_response = $self->lwp_response;
    unless ( $lwp_response ) {
        $self->lwp_response( HTTP::Response->new( RC_FOUND ) );
        $lwp_response = $self->lwp_response;
    }
    else {
        $lwp_response->code( RC_FOUND );
    }
    $lwp_response->header( Location => $url );
    $self->_set_lwp_cookies;
    $log->debug( "Getting ready to send response: ", CTX->dump( $lwp_response ) );
    if ( my $client = $self->client ) {
        $client->send_response( $lwp_response );
    }
    $log->info( "Sent redirect ok" );
}

sub _set_lwp_headers {
    my ( $self ) = @_;
    my $log = get_logger( LOG_RESPONSE );

    my $lwp_response = $self->lwp_response;
    $lwp_response->code( $self->status );
    while ( my ( $name, $value ) = each %{ $self->header } ) {
        if ( ref $value eq 'ARRAY' ) {
            $lwp_response->push_header( $name => $_ ) for ( @{ $value } );
        }
        else {
            $lwp_response->header( $name => $value );
        }
    }
    if ( CTX->server_config->{promote_oi} eq 'yes' ) {
        $lwp_response->header( 'X-Powered-By' => 'OpenInteract ' . CTX->version );
    }
    $log->debug( "Set response headers ok" );
    $self->_set_lwp_cookies;
}

sub _set_lwp_cookies {
    my ( $self ) = @_;
    my $log = get_logger( LOG_RESPONSE );

    for ( @{ $self->cookie } ) {
        $self->lwp_response->push_header( 'Set-Cookie' => $_->as_string );
    }
    $log->debug( "Set response cookies ok" );
}

1;

__END__

=head1 NAME

OpenInteract2::Response::LWP - Response handler using LWP

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
