package OpenInteract2::Response::Apache;

# $Id: Apache.pm,v 1.7 2003/06/11 02:43:26 lachoy Exp $

use strict;
use base qw( OpenInteract2::Response );
use HTTP::Status             qw( RC_OK RC_FOUND );
use OpenInteract2::Context   qw( DEBUG LOG CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Response::Apache::VERSION  = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( apache );
OpenInteract2::Response::Apache->mk_accessors( @FIELDS );

my ( $CURRENT );

sub get_current   { return $CURRENT }
sub clear_current { $CURRENT = undef }

sub init {
    my ( $self, $params ) = @_;
    $self->apache( $params->{apache} );
    $CURRENT = $self;
    return $self;
}


sub send {
    my ( $self ) = @_;
    my $apache = $self->apache;

    $self->save_session;

    my $headers_out = $apache->headers_out;
    foreach my $cookie ( @{ $self->cookie } ) {
        $headers_out->add( 'Set-Cookie', $cookie->as_string );
    }

    while ( my ( $name, $value ) = each %{ $self->header } ) {
        $headers_out->add( $name, $value );
    }

    if ( my $filename = $self->send_file ) {
        $self->set_file_info;
        my $fh = $apache->gensym;
        eval { open( $fh, "< $filename" ) || die $!; };
        if ( $@ ) {
            oi_error "Cannot open file from filesystem [$filename]: $@";
        }
        $self->send_header( $apache );
        $apache->send_fd( $fh );
        return;
    }

    $self->send_header( $apache );
    $apache->print( $self->content );
}


sub send_header {
    my ( $self, $apache ) = @_;
    unless ( $self->content_type ) { $self->content_type( 'text/html' ) }
    unless ( $self->status       ) { $self->status( RC_OK ) }
    unless ( CTX->server_config->{no_promotion} ) {
        $apache->headers_out->add( 'X-Powered-By', "OpenInteract " . CTX->version );
    }
    $apache->send_http_header( $self->content_type );
}


sub redirect {
    my ( $self, $url ) = @_;
    $self->status( RC_FOUND );
    $self->header_out( Location => $url );
    return;
}

1;

__END__

=head1 NAME

OpenInteract2::Response::Apache

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
