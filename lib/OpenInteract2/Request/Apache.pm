package OpenInteract2::Request::Apache;

# $Id: Apache.pm,v 1.8 2003/06/11 02:43:27 lachoy Exp $

use strict;
use base qw( OpenInteract2::Request );

use Apache::Request;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( DEBUG LOG );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Upload;
use OpenInteract2::URL;

$OpenInteract2::Request::Apache::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( apache );
OpenInteract2::Request::Apache->mk_accessors( @FIELDS );

sub init {
    my ( $self, $params ) = @_;
    unless ( ref $params->{apache} ) {
        oi_error "Cannot initialize the OpenInteract2::Request object - ",
                 "pass in an Apache request object in 'apache'";
    }

    my $apache = Apache::Request->new( $params->{apache} );
    $self->apache( $apache );
    DEBUG && LOG( LDEBUG, "Created Apache::Request object and set" );

    # Set the URI and parse it

    $self->_set_url( $apache->uri );

    # Setup the GET/SET params

    foreach my $field ( $self->apache->param() ) {
        my @values = $self->apache->param( $field );
        if ( scalar @values > 1 ) {
            $self->param( $field, \@values );
        }
        else {
            $self->param( $field, $values[0] );
        }
    }
    DEBUG && LOG( LDEBUG, "Set all parameters ok" );

    # Next set the uploaded files

    foreach my $upload ( $self->apache->upload() ) {
        my $oi_upload = OpenInteract2::Upload->new({
                              name         => $upload->name,
                              content_type => $upload->type,
                              size         => $upload->size,
                              filehandle   => $upload->fh,
                              filename     => $upload->filename,
                              tmp_name     => $upload->tempname });
        $self->_set_upload( $upload->name, $oi_upload );
    }
    DEBUG && LOG( LDEBUG, "Set all uploaded files ok" );

    # Then the various headers, properties, etc.

    my $head_in = $self->apache->headers_in();
    $self->referer( $head_in->{Referer} );
    $self->user_agent( $head_in->{'User-Agent'} );
    $self->cookie_header( $head_in->{Cookie} );
    $self->_parse_cookies;

    $self->create_session;

    my $srv = $self->apache->server;
    $self->server_name( $srv->server_hostname );
    $self->remote_host( $self->apache->connection->remote_ip );
    DEBUG && LOG( LDEBUG, "Set request and server properties ok" );
    return $self;
}


1;

__END__

=head1 NAME

OpenInteract2::Request::Apache - Read parameters, uploaded files and headers

=head1 SYNOPSIS

 sub handler {
     my $r = shift;
     my $req = OpenInteract2::Request->new( 'apache', { apache => $r } );
     ...
 }

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
