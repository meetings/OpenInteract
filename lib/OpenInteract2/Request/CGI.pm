package OpenInteract2::Request::CGI;

# $Id: CGI.pm,v 1.10 2003/06/11 02:43:27 lachoy Exp $

use strict;
use base qw( OpenInteract2::Request );
use CGI;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( DEBUG LOG CTX );
use OpenInteract2::Upload;
use OpenInteract2::URL;

$OpenInteract2::Request::CGI::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( cgi );
OpenInteract2::Request::CGI->mk_accessors( @FIELDS );

my ( $CURRENT );

sub init {
    my ( $self, $params ) = @_;
    if ( $params->{cgi} ) {
        $self->cgi( $params->{cgi} );
    }
    else {
        binmode STDIN;
        $self->cgi( CGI->new() );
    }
    my $cgi = $self->cgi;

    my $base_url = $cgi->script_name;
    DEBUG && LOG( LDEBUG, "Deployed under: [$base_url]" );
    CTX->assign_deploy_url( $base_url );

    my $full_url = join( '', $base_url, $cgi->path_info );
    DEBUG && LOG( LDEBUG, "OI URL: [$full_url]" );
    $self->_set_url( $full_url );

    # Then the various headers, properties, etc.

    $self->referer( $cgi->referer );
    $self->user_agent( $cgi->user_agent );
    $self->cookie_header( $cgi->raw_cookie );
    $self->_parse_cookies;

    $self->create_session;

    $self->server_name( $cgi->server_name );
    $self->remote_host( $cgi->remote_host );
    DEBUG && LOG( LDEBUG, "Set request and server properties ok" );

    # See if there are any uploads among the parameters. (Note: only
    # supporting a single upload per fieldname right now...)

    my @fields = $cgi->param;

    foreach my $field ( @fields ) {
        my @items = $cgi->param( $field );
        next unless ( scalar @items );

        # ISA upload
        if ( ref( $items[0] ) ) {
            foreach my $upload ( @items ) {
                my $upload_info = $cgi->uploadInfo( $upload );
                my $oi_upload = OpenInteract2::Upload->new({
                                   name         => $field,
                                   content_type => $upload_info->{'Content-Type'},
                                   size         => (stat $upload)[7],
                                   filehandle   => $upload,
                                   filename     => $cgi->tmpFileName( $upload ) });
                $self->_set_upload( $field, $oi_upload );
            }
        }

        # ISNOTA upload
        else {
            if ( scalar @items > 1 ) {
                $self->param( $field, \@items );
            }
            else {
                $self->param( $field, $items[0] );
            }
        }
    }
    DEBUG && LOG( LDEBUG, "Set parameters and file uploads ok" );
    return $CURRENT = $self;
}

sub get_current   { return $CURRENT }
sub clear_current { $CURRENT = undef }

1;

__END__

=head1 NAME

OpenInteract2::Request::CGI - Read parameters, uploaded files and headers

=head1 SYNOPSIS

 my $req = OpenInteract2::Request->new( 'cgi', { cgi => $q } );
 my $req = OpenInteract2::Request->new( 'cgi' );

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
