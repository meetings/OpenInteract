package OpenInteract2::Request::Standalone;

# $Id: Standalone.pm,v 1.4 2003/06/11 02:43:26 lachoy Exp $

use strict;
use base qw( OpenInteract2::Request );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( DEBUG LOG );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Upload;
use OpenInteract2::URL;
use Sys::Hostname;

$OpenInteract2::Request::Standalone::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $CURRENT );

sub init {
    my ( $self, $props ) = @_;

    $self->_set_property_defaults( $props );

    # This will die if any problems found
    $self->_check_properties( $props );

    DEBUG && LOG( LDEBUG, "OI URL: [$props->{url}]" );
    $self->_set_url( $props->{url} );

    # Then the various headers, properties, etc.

    $self->referer( $props->{referer} );
    $self->user_agent( $props->{user_agent} );

    foreach my $cookie_info ( @{ $props->{cookie} } ) {
        if ( ref $cookie_info ) {
            $self->cookie( $cookie_info->name, $cookie_info->value );
        }
        else {
            $self->_parse_cookies( $cookie_info );
        }
    }

    $self->create_session;

    $self->server_name( $props->{server_name} );
    $self->remote_host( $props->{remote_host} );
    DEBUG && LOG( LDEBUG, "Set request and server properties ok" );

    foreach my $field ( keys %{ $props->{param} } ) {
        $self->param( $field, $props->{param}{ $field } );
    }
    foreach my $field ( keys %{ $props->{upload} } ) {
        $self->_set_upload( $field, $props->{upload}{ $field } );
    }
    DEBUG && LOG( LDEBUG, "Set parameters and file uploads ok" );

    return $CURRENT = $self;
}

sub get_current   { return $CURRENT }
sub clear_current { $CURRENT = undef }

sub _set_property_defaults {
    my ( $self, $props ) = @_;
    $props->{param}       ||= {};
    $props->{upload}      ||= {};
    $props->{server_name} ||= hostname;
    $props->{cookie}      ||= [];
    if ( ref $props->{cookie} ne 'ARRAY' ) {
        $props->{cookie} = [ $props->{cookie} ];
    }
}

sub _check_properties {
    my ( $self, $props ) = @_;
    my @errors = ();
    unless ( $props->{url} ) {
        push @errors, "Must be initialized with property 'url'";
    }
    if ( ref $props->{param} eq 'HASH' ) {
        while ( my ( $name, $value ) = each %{ $props->{param} } ) {
            my $typeof_p = ref $value;
            if ( $typeof_p and $typeof_p ne 'ARRAY' ) {
                push @errors, "Parameter '$name' must be set to a simple " .
                              "scalar or an arrayref, not a $typeof_p";
            }
        }
    }
    else {
        push @errors, "If set, the property 'param' must be set to a hashref";
    }
    foreach my $cookie ( @{ $props->{cookie} } ) {
        if ( ref $cookie and ! UNIVERSAL::isa( $cookie, 'OpenInteract2::Cookie' ) ) {
            push @errors, "A cookie is not a simple scalar or an " .
                          "acceptable cookie object";
        }
    }
    if ( ref $props->{upload} eq 'HASH' ) {
        while ( my ( $name, $upload ) = each %{ $props->{upload} } ) {
            unless( UNIVERSAL::isa( $upload, 'OpenInteract2::Upload' ) ) {
                push @errors, "Upload '$name' must be set to an acceptable " .
                              "upload object.";
            }
        }
    }
    else {
        push @errors, "If set, the property 'upload' must be set to a hashref";
    }
    if ( scalar @errors > 0 ) {
        oi_error "Properties not valid:\n", join( "\n", @errors );
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Request::Standalone - Manually create a request object

=head1 SYNOPSIS

 # Create all the request infomration offline...
 
 my %req_params = (
   url         => '/path/to/my/doc.html',
   referer     => 'http://www.foo.bar/path/to/my/index.html',
   user_agent  => 'OI2 Standalone Requester',
   server_name => 'www.foo.bar',
   remote_host => '192.168.1.1',
   param       => { eyes => 'two',
                    soda => [ 'rc', 'mr. pibb' ] },
   cookie      => [ 'lastSeen=1051797475;firstLogin=1051797075',
                    OpenInteract2::Cookie->new( ... ), ],
   upload      => { sendfile   => OpenInteract2::Upload->new( ... ),
                    screenshot => OpenInteract2::Upload->new( ... ) },
 );
 
 # ...and create a new object with it
 
 my $req = OpenInteract2::Request->new( 'standalone', \%req_params );

 # ...or just create an empty object with the bare minimum of
 # infomration and set properties as needed
 
 my $req = OpenInteract2::Request->new( 'standalone',
                                        { url => '/path/to/my/doc.html' } );
 $req->referer( 'http://www.foo.bar/path/to/my/index.html' );
 $req->param( eyes => 'two' );
 $req->param( soda => [ 'rc', 'mr. pibb' ] );
 $req->cookie( lastSeen => '1051797475' );

=head1 DESCRIPTION

This object is mainly used for testing, but you can also use it as
glue to some other operating environment. The only thing this module
does is take the properties passed into the C<new()> call (and passed
by L<OpenInteract2::Request|OpenInteract2::Request> via C<init()>) and
set them into the object.

=head1 METHODS

B<init( \%properties )>

Set all the properties from C<\%properties> in the object. Since
almost all the properties are simple key/value pairs this is
straightforward. There are a few more complicated ones:

=over 4

=item *

B<url> - Required. This is the URL path (without the protocol, host
and port information) and will get parsed into the B<url_absolute>,
B<url_relative> and B<url_initial> request properties.

Default: none

=item *

B<param> - This must be a hashref of key/value pairs. You can
represent multi-valued parameters by setting the value within the
hashref to an arrayref. Setting the value of this property to a
simple scalar or arrayref, or setting any of the parameter values to a
hashref, is grounds for an exception to be thrown.

Default: none

=item *

B<cookie> - You can pass in one or more cookie strings (what the
browser passes in its C<Cookie> header) and/or one or more
L<OpenInteract2::Cookie|OpenInteract2::Cookie> objects. If the values
set aren't simple scalars or cookie objects an exception is thrown.

Default: none

=item *

B<upload> - You can pass in one or more
L<OpenInteract2::Upload|OpenInteract2::Upload> objects associated with
fields in a hashref. Setting the property value to anything other than
a hashref, or setting the value associated with an upload field to
anything other than an upload object, will cause an exception.

Default: none

=back

The simple request properties set are:

=over 4

=item *

B<referer> - Set to what you'd like to be the referring page.

Default: none

=item *

B<user_agent> - Set to the user agent for this request.

Default: none

=item *

B<server_name> - Set to the server hostname.

Default: return value from L<Sys::Hostname|Sys::Hostname>

=item *

B<remote_host> - Set to the host making the request.

Default: none

=back

=head1 BUGS

None known.

=head1 TO DO

B<Add settable auth_* properties>

B<Add settable theme_* properties?>

=head1 SEE ALSO

L<OpenInteract2::Response::Standalone|<OpenInteract2::Response::Standalone>

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
