package OpenInteract2::Request::Apache2;

# $Id: Apache2.pm,v 1.5 2006/08/18 00:25:28 infe Exp $

use strict;
use base qw( OpenInteract2::Request );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Upload;

use Apache2::Request;
use Apache2::Upload;

$OpenInteract2::Request::Apache2::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( apache );
__PACKAGE__->mk_accessors( @FIELDS );

my ( $done );

sub init {
    my ( $self, $params ) = @_;
    $log ||= get_logger( LOG_REQUEST );
    $log->is_info &&
        $log->info( "Creating Apache 2.x request" );

    my $r = $params->{apache};
    unless ( ref $r ) {
        $log->error( "No 'apache' object for creating request" );
        oi_error "Cannot initialize the OpenInteract2::Request object - ",
                 "pass in an Apache2 request object in 'apache'";
    }
    
    my $apache = Apache2::Request->new($r);

    $self->apache( $apache );

    # Hopefully this will pull the right Apache::Request...
    unless ( $done ) {
        #require Apache::Connection;
#        require Apache::Request;
        require APR::URI;
        require APR::SockAddr;
        $done++;
    }

    my $apache_uri = $r->parsed_uri;
    my $full_url   = $apache_uri->path;
    my $query_args = $apache_uri->query;
    if ( $query_args ) {
        $full_url .= "?$query_args";
    }
    $log->is_debug && $log->debug( "Got URL from apache2 '$full_url'" );
    $self->assign_request_url( $full_url );

    # Setup the GET/POST params
    
    for my $field ($self->apache->param) {
        my @values = $self->apache->param($field);

        $self->param($field => (@values > 1 ? \@values : $values[0]));
    }

    # Uploads
    
    for my $upload_name ($self->apache->upload) {
        my $upload = $self->apache->upload($upload_name);

        my $oi_upload = eval {
            OpenInteract2::Upload->new({
                name         => $upload->name,
                content_type => $upload->type,
                size         => $upload->size,
                filehandle   => $upload->fh,
                filename     => $upload->filename,
                tmp_name     => $upload->tempname
            })
        };

        if ($@) {
            $log->error("Failed to process upload $upload_name: $@");
            next;
        }

        $self->_set_upload( $upload->name => $oi_upload );
    }

    # Then the various headers, properties, etc.

    my $in = $r->headers_in();
    $self->referer( $in->{'Referer'} );
    $self->user_agent( $in->{'User-Agent'} );
    $self->cookie_header( $in->{'Cookie'} );
    $self->language_header( $in->{'Accept-Language'} );

    $self->server_name( $r->get_server_name );
    $self->server_port( $r->get_server_port );
    $self->remote_host( $r->connection->remote_addr->ip_get );
    $self->forwarded_for( $r->headers_in->get('X-Forwarded-For') );
    
    $log->is_info &&
        $log->info( "Finished creating Apache 2.x request" );

    return $self;
}

sub post_body {
    my ( $self ) = @_;
    my ( $body, $buf );
        while ( $self->apache->read( $buf, $self->apache->header_in('Content-length') ) ) {
            $body .= $buf;
        }
    return $body;
}

1;

__END__

=head1 NAME

OpenInteract2::Request::Apache2 - Read parameters, uploaded files and headers from Apache2/mod_perl2

=head1 SYNOPSIS

 sub handler {
     my $r = shift;
     my $req = OpenInteract2::Request->new( 'apache2', { apache => $r } );
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

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
