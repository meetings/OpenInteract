package OpenInteract2::Request::Apache;

# $Id: Apache.pm,v 1.14 2004/02/18 05:25:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Request );
use Apache::Request;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Upload;
use OpenInteract2::URL;

$OpenInteract2::Request::Apache::VERSION = sprintf("%d.%02d", q$Revision: 1.14 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( apache );
OpenInteract2::Request::Apache->mk_accessors( @FIELDS );

sub init {
    my ( $self, $params ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    $log->is_info &&
        $log->info( "Creating Apache 1.x request" );
    unless ( ref $params->{apache} ) {
        $log->error( "No 'apache' object for creating request" );
        oi_error "Cannot initialize the OpenInteract2::Request object - ",
                 "pass in an Apache request object in 'apache'";
    }

    my $apache = Apache::Request->new( $params->{apache} );
    $self->apache( $apache );
    $log->is_debug &&
        $log->debug( "Created Apache::Request object and set" );

    # Set the URI and parse it

    $self->assign_request_url( $apache->uri );

    # Setup the GET/SET params

    my $num_param = 0;
    foreach my $field ( $self->apache->param() ) {
        my @values = $self->apache->param( $field );
        if ( scalar @values > 1 ) {
            $self->param( $field, \@values );
        }
        else {
            $self->param( $field, $values[0] );
        }
        $num_param++;
    }
    $log->is_debug &&
        $log->debug( "Set all parameters ok ($num_param)" );

    # Next set the uploaded files

    my $num_uploads = 0;
    foreach my $upload ( $self->apache->upload() ) {
        my $oi_upload = OpenInteract2::Upload->new({
                              name         => $upload->name,
                              content_type => $upload->type,
                              size         => $upload->size,
                              filehandle   => $upload->fh,
                              filename     => $upload->filename,
                              tmp_name     => $upload->tempname });
        $self->_set_upload( $upload->name, $oi_upload );
        $num_uploads++;
    }
    $log->is_debug &&
        $log->debug( "Set all uploaded files ($num_uploads)" );

    # Then the various headers, properties, etc.

    my $head_in = $self->apache->headers_in();
    $self->referer( $head_in->{'Referer'} );
    $self->user_agent( $head_in->{'User-Agent'} );
    $self->cookie_header( $head_in->{'Cookie'} );
    $self->language_header( $head_in->{'Accept-Language'} );

    my $srv = $self->apache->server;
    $self->server_name( $srv->server_hostname );
    $self->remote_host( $self->apache->connection->remote_ip );
    $log->is_info &&
        $log->info( "Finished creating Apache 1.x request" );
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

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>