package OpenInteract2::Request::LWP;

# $Id: LWP.pm,v 1.12 2003/06/11 02:43:27 lachoy Exp $

use strict;
use base qw( OpenInteract2::Request );
use CGI                     qw();
use File::Temp              qw( tempfile );
use IO::File;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( DEBUG LOG CTX );
use OpenInteract2::Upload;

$OpenInteract2::Request::LWP::VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( lwp );
OpenInteract2::Request::LWP->mk_accessors( @FIELDS );

my ( $CURRENT );

sub init {
    my ( $self, $params ) = @_;

    my $client      = $params->{client};
    my $lwp_request = $params->{request};
    $self->lwp( $lwp_request );

    $self->_set_url( $lwp_request->uri );

    # Then the various headers, properties, etc.

    $self->referer( $lwp_request->referer );
    $self->user_agent( $lwp_request->user_agent );
    my $cookie = $lwp_request->header( 'Cookie' );
    $self->cookie_header( $cookie );
    $self->_parse_cookies;

    $self->create_session;

    $self->server_name( $lwp_request->server );
    if ( $client ) {
        $self->remote_host( $client->peerhost );
    }
    DEBUG && LOG( LDEBUG, "Set request and server properties ok" );

    $self->_parse_request;
    DEBUG && LOG( LDEBUG, "Parsed request ok" );
    $CURRENT = $self;
    return $self;
}

sub get_current   { return $CURRENT }
sub clear_current { $CURRENT = undef }


sub _parse_request {
    my ( $self ) = @_;
    my $request = $self->lwp;
    my $method = $request->method;
    if ( $method eq 'GET' || $method eq 'HEAD' ) {
        $self->_assign_args( CGI->new( $request->uri->equery ) );
        $request->uri->query(undef);
    }
    elsif ( $method eq 'POST' ) {
        my $content_type = $request->content_type;
        if ( ! $content_type || $content_type eq "application/x-www-form-urlencoded" ) {
            $self->_assign_args( CGI->new( $request->content ) );
            $request->uri->query(undef);
        }
        elsif ( $content_type eq "multipart/form-data" ) {
            return $self->_parse_multipart_data();
        }
        else {
            die "Invalid content type: $content_type\n";
        }
    }
    else {
        die "Unsupported method: $method\n";
    }
}

sub _assign_args {
    my ( $self, $cgi ) = @_;
    foreach my $name ( $cgi->param() ) {
        my @values = $cgi->param( $name );
        if ( scalar @values > 1 ) {
            $self->param( $name, \@values );
        }
        else {
            $self->param( $name, $values[0] );
        }
    }
}

sub _parse_multipart_data {
    my ( $self ) = @_;
    my $request = $self->lwp;

    my $full_content_type = $request->headers->header( "Content-Type" );
    my ( $boundary ) = $full_content_type =~ /boundary=(\S+)$/;
    foreach my $part ( split(/-?-?$boundary-?-?/, $request->content ) ) {
        $part =~ s|^\r\n||g;
        next unless ( $part ); # whoops, empty part
        my %headers = ();
        my ( $name, $filename, $content_type );

        # Read in @lines of $part until we reach the end of the
        # description, grab the content type, name and filename

        my @lines = split /\r\n/, $part;
        while ( @lines ) {
            my $line = shift @lines;
            last unless ( $line );
            if ( $line =~ /^content-type: (.+)$/i ) {
                $content_type = $1;
            }
            elsif ( $line =~ /^content-disposition: (.+)$/i ) {
                my $full_disposition = $1;
                ( $name ) = $full_disposition =~ /\bname="(.+?)"/;
                ( $filename ) = $full_disposition =~ /filename="(.+?)"/;
            }
        }

        # OK, we've got an upload. Save it to a temp file then rewind
        # to the beginning of the file for a read

        if ( $filename ) {
            my ( $fh, $tmp_filename ) = tempfile();
            print $fh join( "\r\n", @lines );
            seek( $fh, 0, 0 );
            my $oi_upload = OpenInteract2::Upload->new({
                                   name         => $name,
                                   content_type => $content_type,
                                   size         => (stat $fh)[7],
                                   filehandle   => $fh,
                                   filename     => $filename,
                                   tmp_name     => $tmp_filename });
            $self->_set_upload( $name, $oi_upload );
            DEBUG && LOG( LDEBUG, "Set arg [$name] to OI::Upload" );
        }
        else {
            my $value = join( "\n", @lines );
            DEBUG && LOG( LDEBUG, "Set arg [$name] to $value" );
            $self->param( $name, $value );
        }
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Request::LWP - Read parameters, uploaded files and headers

=head1 SYNOPSIS

 CTX->assign_request_type( 'lwp' );
 ...
 while ( my $client = $daemon->accept ) {
     while ( my $lwp_request = $client->get_request ) {
         my $oi_request = OpenInteract2::Request->new(
                              { client  => $client,
                                request => $lwp_request } );
     }
 }

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

GET/POST parsing swiped from the OpenFrame project.
