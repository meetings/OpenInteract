package OpenInteract2::Response::Standalone;

# $Id: Standalone.pm,v 1.4 2003/06/11 02:43:26 lachoy Exp $

use strict;
use base qw( OpenInteract2::Response );
use Data::Dumper             qw( Dumper );
use IO::File;
use HTTP::Status             qw( RC_OK RC_FOUND );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Response::Standalone::VERSION  = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $CURRENT );

sub get_current   { return $CURRENT }
sub clear_current { $CURRENT = undef }

sub init {
    my ( $self, @params ) = @_;
    $CURRENT = $self;
    return $self;
}

sub out {
    my $self = shift;
    for ( @_ ) {
        if ( ! ref( $_ ) ) {
            print $_;
        }
        elsif ( ref( $_ ) eq 'SCALAR' ) {
            print ${ $_ };
        }
        elsif ( UNIVERSAL::isa( $_, 'OpenInteract2::Exception' ) ) {
            print "<h1>Exception!</h1>\n",
                  "<p>Error: ", $_->message, "<br>",
                  $_->creation_location, "</p>\n";
        }
        else {
            $Data::Dumper::Indent = 1;
            print '<pre><font size="-1">', Dumper( $_ ), '</font></pre>';
        }
    }
}

sub send {
    my ( $self ) = @_;

    $self->save_session;

    if ( my $filename = $self->send_file ) {
        $self->set_file_info;
        my $fh = IO::File->new( "< $filename" )
                    || oi_error "Cannot open file [$filename]: $!";
        $self->out( $self->generate_cgi_header_fields, "\r\n\r\n" );
        my ( $data );
        while ( $fh->read( $data, 1024 ) ) {
            $self->out( $data );
        }
        return;
    }

    $self->out( $self->generate_cgi_header_fields, "\r\n\r\n" );
    $self->out( $self->content );
}


sub generate_cgi_header_fields {
    my ( $self ) = @_;
    $self->content_type( 'text/html' ) unless ( $self->content_type );
    $self->status( RC_OK )             unless ( $self->status       );
    my $header_entries = $self->header;

    my @header = ();
    push @header, "Status: " . $self->status;
    push @header, $self->_generate_cookie_lines;
    while ( my ( $key, $value ) = each %{ $header_entries } ) {
        next if ( $key eq 'Content-Type' );
        push @header, "$key: $value";
    }
    push @header, "Content-Type: " . $self->content_type;
    unless ( CTX->server_config->{no_promotion} ) {
        push @header, join( '', 'X-Powered-By: ', 'OpenInteract ', CTX->version );
    }
    return join( "\r\n", @header );
}


sub redirect {
    my ( $self, $url ) = @_;
    my @header = ();
    push @header, "Status: 302 Moved";
    push @header, "Location: $url";
    push @header, $self->_generate_cookie_lines;
    $self->out( join( "\r\n", @header ), "\r\n\r\n" );
}


sub _generate_cookie_lines {
    my ( $self ) = @_;
    my $cookies = $self->cookie;
    return () unless ( ref $cookies eq 'ARRAY' );
    return map { "Set-Cookie: " . $_->as_string } @{ $cookies };
}

1;

__END__

=head1 NAME

OpenInteract2::Response::Standalone

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
