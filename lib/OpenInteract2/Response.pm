package OpenInteract2::Response;

# $Id: Response.pm,v 1.16 2003/08/30 15:47:15 lachoy Exp $

use strict;
use base qw( Class::Factory Class::Accessor );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Response::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

########################################
# ACCESSORS

# TODO: 'error_hold' is temporary, until we get the error reporting
# back to the template worked out

my @FIELDS         = qw( status controller send_file content );
__PACKAGE__->mk_accessors( @FIELDS, 'error_hold' );

my ( $RESPONSE_TYPE, $RESPONSE_CLASS );

sub set_implementation_type {
    my ( $class, $type ) = @_;
    my $impl_class = eval { $class->get_factory_class( $type ) };
    oi_error $@ if ( $@ );
    $RESPONSE_TYPE  = $type;
    $RESPONSE_CLASS = $impl_class;
    return $impl_class;
}

sub get_implementation_type {
    return $RESPONSE_TYPE;
}

# Retrieve the current object

# XXX: This has the potential of an endless loop if 'get_current()'
# not defined in impl; maybe check whether it's defined in
# set_implementation_type()?

sub get_current { return $RESPONSE_CLASS->get_current }


sub new {
    my ( $class, @params ) = @_;
    my $log = get_logger( LOG_RESPONSE );
    unless ( $RESPONSE_CLASS ) {
        $log->fatal( "No response implementation type set" );
        oi_error 'Before creating an OpenInteract2::Response object you ',
                 'must set the request type with "set_implementation_type()"';
    }
    my $self = bless( { _cookie => {},
                        _header => {} }, $RESPONSE_CLASS );
    $self->init( @params );
    CTX->response( $self );
    return $self;
}

########################################
# HEADERS

# header shortcuts

sub content_type {
    my ( $self, $value ) = @_;
    if ( $value ) {
        $self->{_header}{'Content-Type'} = $value;
    }
    return $self->{_header}{'Content-Type'};
}


# TODO: We may want to dereference $self->{header} before sending it
# back, otherwise people can add headers directly to the hash. OTOH,
# this may be a good thing...

# TODO: Use an HTTP::Headers object here?

sub header {
    my ( $self, $name, $value ) = @_;
    unless ( $name ) {
        return $self->{_header};
    }
    my $log = get_logger( LOG_RESPONSE );
    if ( $value ) {
        $self->{_header}{ $name } = $value;
        $log->is_debug &&
            $log->debug( "Setting header [$name] to [$value]" );
    }
    return $self->{_header}{ $name };
}

sub remove_header {
    my ( $self, $name ) = @_;
    my $log = get_logger( LOG_RESPONSE );
    if ( $name ) {
        $log->is_debug &&
            $log->debug( "Removing header [$name] from response" );
        return delete $self->{_header}{ $name };
    }
}


# Cookies are special types of headers; the response should collect
# all of these and put them into the header in send()
# $cookie should be a CGI::Cookie object

sub cookie {
    my ( $self, $cookie ) = @_;
    my $log = get_logger( LOG_RESPONSE );
    unless ( $cookie ) {
        return [ values %{ $self->{_cookie} } ];
    }
    unless ( UNIVERSAL::isa( $cookie, 'CGI::Cookie' ) ) {
        $log->warn( "Tried to add a 'cookie()' to the response without ",
                    "passing a valid cookie object. (Must be a ",
                    "'CGI::Cookie' object or have it as a parent.)" );
        return;
    }
    my $name = $cookie->name;
    unless ( $name ) {
        $log->warn( "Cannot add cookie to response without a name; ",
                    "please ensure the 'CGI::Cookie' object set has a name" );
        return;
    }
    $log->is_debug &&
        $log->debug( "Setting cookie [$name] to [$cookie]" );
    $self->{_cookie}{ $name } = $cookie;
    return $cookie;
}

sub remove_cookie {
    my ( $self, $name ) = @_;
    my $log = get_logger( LOG_RESPONSE );
    if ( $name ) {
        $log->is_debug &&
            $log->debug( "Removing cookie [$name] from response" );
        return delete $self->{_cookie}{ $name };
    }
}


sub save_session {
    my ( $self ) = @_;
    OpenInteract2::SessionManager->save( CTX->request->session );
}


sub set_file_info {
    my ( $self ) = @_;
    my $log = get_logger( LOG_RESPONSE );
    my $filename = $self->send_file;
    unless ( $filename ) {
        return undef;
    }
    unless ( -f $filename ) {
        oi_error "Cannot set outbound file information for [$filename]: ",
                 "file does not exist";
    }
    $log->is_debug &&
        $log->debug( "Set response information for file [$filename]" );
    unless ( $self->header( 'Content-Length' ) ) {
        $self->header( 'Content-Length', (stat $filename)[7] );
    }
    unless ( $self->header( 'Content-Type' ) ) {
        $self->content_type( OpenInteract2::File->get_mime_type({
                                             filename => $filename }) );
    }
}

########################################
# PROPERTIES

sub return_url {
    my ( $self, $return_url ) = @_;
    if ( $return_url ) {
        $self->{return_url} =
            OpenInteract2::URL->create_relative_to_absolute( $return_url );
    }
    return $self->{return_url};
}

########################################
# FACTORY

sub factory_log {
    my ( $self, @msg ) = @_;
    get_logger( LOG_RESPONSE )->info( @msg );
}

sub factory_error {
    my ( $self, @msg ) = @_;
    get_logger( LOG_RESPONSE )->error( @msg );
    die @msg, "\n";
}

__PACKAGE__->register_factory_type(
                    apache     => 'OpenInteract2::Response::Apache' );
__PACKAGE__->register_factory_type(
                    cgi        => 'OpenInteract2::Response::CGI' );
__PACKAGE__->register_factory_type(
                    lwp        => 'OpenInteract2::Response::LWP' );
__PACKAGE__->register_factory_type(
                    standalone => 'OpenInteract2::Response::Standalone' );


########################################
# OVERRIDE

# Initialize new object
sub init          { die "Subclass must implement init()" }

# Clear out current object
sub clear_current { die "Subclass must implement clear_current()" }

# Set/send HTTP headers + cookies + content
sub send          { die "Subclass must implement send()" }

# Redirect to another URL (yay, proper HTTP redirects!)
sub redirect      { die "Subclass must implement redirect()" }

1;

__END__

=head1 NAME

OpenInteract2::Response - Information about and actions on an HTTP response

=head1 SYNOPSIS

 # Normal usage

 use HTTP::Status qw( RC_OK );

 my $response = OpenInteract2::Response->get_current;
 $response->status( RC_OK );                 # default
 $response->content_type( 'text/html' )      # default
 $response->header( 'X-Powered-By' => 'OpenInteract 2.0' );
 my $cookie = CTX->cookie->create({ name    => 'session',
                                    expires => '+3d',
                                    value   => 'ISDFUASDFHSDAFUE' });
 $response->cookie( 'session', $cookie );

 # Sends the header (including cookies) and content to client

 $response->send;

=head1 DESCRIPTION

=head1 METHODS

=head2 Class Methods

B<get_current()>

B<set_implementation_type( $type )>

B<get_implementation_type()>

B<new()>

=head2 Object Methods

B<content_type( [ $content_type ] )>

B<header( [ $name, $value ] )>

B<remove_header( $name )>

B<cookie( [ $cookie ] )>

B<remove_cookie( $name )>

B<send()>

B<redirect()>

=head2 Methods for Subclasses

B<set_file_info()>

B<init()>

B<clear_current()>

=head1 PROPERTIES

All of the properties can be get and set by their name. For example:

 my $status = $response->status;          # Get the current status
 $response->status( RC_MAN_OVERBOARD );   # Set a new status

B<status> - HTTP status of this response. If not set it will be set to
C<RC_OK> (from L<HTTP::Status|HTTP::Status>) in the controller.

B<controller> - The controller assigned to this response. This is
useful for modifying the default template layout, setting the page
title, etc. See L<OpenInteract2::Controller|OpenInteract2::Controller>
for more information.

B<return_url> - A URL to which the user should return. This is useful
for login boxes or other links that you don't want pointing to a
particular place without first going through the correct path. For
instance, returning from a '/Foo/edit/' you may want to set the return
URL to '/Foo/show/' or something else harmless so you don't
accidentally submit a new 'edit'. (Redirects are good for this, too.)

When set the response object ensures the given URL is located under
the server context; therefore, the value returned from this property
is always located under the server context.

B<send_file> - Filename of file to send directly to the user. It is
generally a good idea to set the 'Content-Type' header (via
C<add_header()>) when doing this.

B<content> - Set the content for this response. Can be a scalar or a
reference to a scalar, so the following will wind up displaying the
same information:

 my $foo = "Fourscore and seven years ago...";
 $response->content( $foo );
 $response->content( \$foo );

=head1 SUBCLASSING

The actual work to send the correct data to the client is accomplished
by a subclass of this class. Subclasses must do the following:

=over 4

=item B<Implement init()>

This method is called after the response is initialized. It must
return the response object.

=item B<Implement get_current()>

This must return the current response object

=item B<Implement clear_current()>

This must remove any reference to the current response
object. Successive calls to C<get_current()> before the next response
object is created must return C<undef>.

=item B<Implement send()>

This method will send the headers (including cookies) and content to
the client. Note that the property C<content> may be a scalar or a
reference to a scalar: you will need to deal with both.

=item B<Implement redirect()>

This should assemble headers appropriate to redirect the client to a
new URL, which is passed as the first argument. Whether it actually
sends the headers is another matter; most implementations will
probably wait to send them until C<send()> is called.

=back

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<Class::Factory|Class::Factory>

L<OpenInteract2::Response::Apache|OpenInteract2::Response::Apache>

L<OpenInteract2::Response::CGI|OpenInteract2::Response::CGI>

L<OpenInteract2::Response::LWP|OpenInteract2::Response::LWP>

L<OpenInteract2::Response::Standalone|OpenInteract2::Response::Standalone>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
