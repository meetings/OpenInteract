package OpenInteract2::Request;

# $Id: Request.pm,v 1.18 2003/06/11 02:43:32 lachoy Exp $

use strict;
use base qw( Class::Factory Class::Accessor );
use DateTime;
use DateTime::Format::Strptime qw( strptime );
use OpenInteract2::Constants qw( :log SESSION_COOKIE );
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use OpenInteract2::Cookie;
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Session;
use OpenInteract2::URL;

$OpenInteract2::Request::VERSION = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

########################################
# ACCESSORS

my @FIELDS = qw( server_name remote_host user_agent referer cookie_header
                 url_absolute url_relative url_initial action_name task_name
                 theme theme_values session
                 auth_user auth_group auth_is_admin auth_is_logged_in );
__PACKAGE__->mk_accessors( @FIELDS );

my ( $REQUEST_TYPE, $REQUEST_CLASS );

sub set_implementation_type {
    my ( $class, $type ) = @_;
    my $impl_class = eval { $class->get_factory_class( $type ) };
    oi_error $@ if ( $@ );
    $REQUEST_TYPE  = $type;
    $REQUEST_CLASS = $impl_class;
    return $impl_class;
}

# Retrieve the current object

# XXX: This has the potential of an endless loop if 'get_current()'
# not defined in impl; maybe check whether it's defined in
# set_implementation_type()?

sub get_current { return $REQUEST_CLASS->get_current }


sub new {
    my ( $class, @params ) = @_;
    unless ( $REQUEST_CLASS ) {
        oi_error 'Before creating an OpenInteract2::Request object you ',
                 'must set the request type with "set_implementation_type()"';
    }
    my $self = bless( { '_upload' => {},
                        '_param'  => {},
                        '_cookie' => {} }, $REQUEST_CLASS );
    $self->init( @params );
    CTX->request( $self );
    return $self;
}


########################################
# PARAMETERS

sub param {
    my ( $self, $name, $value ) = @_;
    unless ( $name ) {
        return keys %{ $self->{_param} };
    }
    if ( defined $value ) {
        $self->{_param}{ $name } = $value;
    }
    if ( ref $self->{_param}{ $name } eq 'ARRAY' ) {
        return ( wantarray )
                 ? @{ $self->{_param}{ $name } }
                 : $self->{_param}{ $name };
    }
    if ( exists $self->{_param}{ $name } ) {
        return ( wantarray )
                 ? ( $self->{_param}{ $name } )
                 : $self->{_param}{ $name };
    }
    return wantarray ? () : undef;
}


sub param_toggled {
    my ( $self, $name ) = @_;
    return ( defined $self->param( $name ) ) ? 'yes' : 'no';

}

sub param_date {
    my ( $self, $name, $format ) = @_;
    if ( $format ) {
        return _parse_date_with_format( $self->param( $name ),
                                        $format );
    }
    my ( $y, $m, $d ) = ( $self->param( $name . '_year' ),
                          $self->param( $name . '_month' ),
                          $self->param( $name . '_day' ) );
    return undef unless ( $y and $m and $d );
    return DateTime->new( year     => $y,
                          month    => $m,
                          day      => $d );
}

sub param_datetime {
    my ( $self, $name, $format ) = @_;
    if ( $format ) {
        return _parse_date_with_format( $self->param( $name ),
                                        $format );
    }
    my $date = $self->param_date( $name );
    my ( $hour, $minute, $am_pm ) =
        ( $self->param( $name . '_hour' ),
          $self->param( $name . '_minute' ),
          $self->param( $name . '_am_pm' ) );
    $hour += 12 if ( lc $am_pm eq 'pm' );
    $date->set( hour   => $hour,
                minute => $minute );
    return $date;
}

sub _parse_date_with_format {
    my ( $value, $format ) = @_;
    return strptime( $value, $format );
}


########################################
# PROPERTIES

# shortcut
sub auth_user_id {
    my ( $self ) = @_;
    return ( $self->auth_is_logged_in ) ? $self->auth_user->id : 0;
}


sub _set_url {
    my ( $self, $url ) = @_;
    $self->url_absolute( $url );
    my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( $url );
    $self->url_relative( $relative_url );

    my ( $action_url, $task ) = OpenInteract2::URL->parse( $relative_url );
    $self->url_initial( $action_url );
    my ( $action_name );
    if ( $action_url ) {
        $action_name = eval { CTX->lookup_action_name( $action_url ) };
        if ( $@ ) {
            my $action_nf = CTX->lookup_action_not_found();
            $action_name = $action_nf->name;
        }
    }
    else {
        my $action_none = CTX->lookup_action_none();
        $action_name = $action_none->name;
    }
    $self->action_name( $action_name );
    $self->task_name( $task );
    DEBUG && LOG( LDEBUG, "Read URI and parsed ok" );

    return $relative_url;
}

########################################
# UPLOADS

sub upload {
    my ( $self, $name ) = @_;
    if ( $name ) {
        if ( ! $self->{_upload}{ $name } ) {
            return wantarray ? () : undef;
        }
        elsif ( ref $self->{_upload}{ $name } eq 'ARRAY' and wantarray ) {
            return @{ $self->{_upload}{ $name } };
        }
        return wantarray ? ( $self->{_upload}{ $name } )
                         : $self->{_upload}{ $name };
    }
    $self->{_upload} ||= {};
    my @items = ();
    foreach my $item ( values %{ $self->{_upload} } ) {
        next unless ( $item );
        if ( ref $item eq 'ARRAY' ) {
            push @items, @{ $item };
        }
        else {
            push @items, $item;
        }
    }
    return @items;
}


sub _set_upload {
    my ( $self, $name, $value ) = @_;
    unless ( $name and $value ) {
        LOG( LWARN, "Called set_upload() without valid params",
                    "Name [$name] Value [", ref( $value ), "]" );
        return undef;
    }
    my @existing = $self->upload( $name );
    if ( ref $value eq 'ARRAY' ) {
        push @existing, @{ $value };
    }
    else {
        push @existing, $value;
    }
    $self->{_upload}{ $name } = ( scalar @existing > 1 )
                                  ? \@existing : $existing[0];
    return $self->{_upload}{ $name };
}


sub clean_uploads {
    my ( $self ) = @_;
    my @uploads = $self->upload;
    foreach my $item ( @uploads ) {
        unlink( $item->tmp_name ) if ( -f $item->tmp_name );
    }
}

########################################
# COOKIES (INBOUND)

sub cookie {
    my ( $self, $name, $value ) = @_;
    unless ( $name ) {
        return keys %{ $self->{_cookie} };
    }
    if ( defined $value ) {
        $self->{_cookie}{ $name } = $value;
    }
    return $self->{_cookie}{ $name };
}

sub _parse_cookies {
    my ( $self, $parse_string ) = @_;
    $parse_string ||= $self->cookie_header;
    if ( $parse_string ) {
        my $cookies = OpenInteract2::Cookie->parse( $parse_string );
        while ( my ( $name, $cookie ) = each %{ $cookies } ) {
            $self->cookie( $name, $cookie->value );
        }
    }
    return $self->cookie;
}


########################################
# SESSION

# This should create at least an empty hashref...

sub create_session {
    my ( $self ) = @_;
    my $session_id = $self->cookie( SESSION_COOKIE );
    my $oi_session_class = CTX->server_config->{session_info}{class};
    my $session = $oi_session_class->create( $session_id );
    return $self->session( $session );
}

########################################
# THEME

# This should be called only after you've authenticated
# TODO: Modify to also lookup in session cache...

sub create_theme {
    my ( $self ) = @_;
    my $user = $self->auth_user;
    unless ( $user ) {
        oi_error "Must authenticate before trying to fetch/create theme";
    }
    my $theme_id = $user->{theme_id}
                   || CTX->server_config->{default_objects}{theme};
    my $theme = eval {
        CTX->lookup_object( 'theme' )->fetch( $theme_id )
    };
    if ( $@ ) {
        LOG( LERROR, "Failed to fetch theme [$theme_id]: $@" );
        oi_error "Failed to fetch requested theme";
    }
    $self->theme( $theme );
    DEBUG && LOG( LDEBUG, "Loaded theme $theme_id ok, now getting values" );
    $self->theme_values( $theme->all_values );
}


########################################
# FACTORY INFO

OpenInteract2::Request->register_factory_type(
                    apache     => 'OpenInteract2::Request::Apache' );
OpenInteract2::Request->register_factory_type(
                    cgi        => 'OpenInteract2::Request::CGI' );
OpenInteract2::Request->register_factory_type(
                    lwp        => 'OpenInteract2::Request::LWP' );
OpenInteract2::Request->register_factory_type(
                    standalone => 'OpenInteract2::Request::Standalone' );


########################################
# OVERRIDE

# Initialize new object
sub init          { die 'Subclass must implement init()' }

# Clear out current object
sub clear_current { die 'Subclass must implement clear_current()' }

1;

__END__

=head1 NAME

OpenInteract2::Request - Represent a single request

=head1 SYNOPSIS

 # In server startup/OI::Context initialization
 
 OpenInteract2::Request->set_implementation_type( 'cgi' );
 
 # Later...
 use OpenInteract2::Request;
 
 my $req = OpenInteract2::Request->get_current;
 print "All parameters: ", join( ', ', $req->param(), "\n";
 print "User agent: ", $req->user_agent(), "\n";

=head1 DESCRIPTION

This object represents all information that we know about a
request. It is modeled after the interfaces for L<CGI|CGI> and
L<Apache::Request|Apache::Request>, so there are a couple of items
that are slightly inconsistent with the rest of OpenInteract.

When you create a new request object you need to specify what type of
request it is. (Your OpenInteract server configuration should have
this specified in the 'server_info' section.) The process of
initializing the object during the C<new()> call fills the Request
object with any parameters, uploaded files and important headers from
the client.

The L<OpenInteract2::Context|OpenInteract2::Context> object is
responsible for associating cookies and the session with this request
object.

=head1 METHODS

B<param( [ $name, $value ] )>

With no arguments, this returns a list -- not an arrayref! -- of
parameters the client passed in.

If you pass in C<$name> by itself then you get the value(s) associated
with it. If C<$name> has not been previously set you get an empty list
or undef depending on the context. Otherwise, we return the
context-sensitive value of C<$name>

If you pass in a C<$value> along with C<$name> then it's assigned to
C<$name>, overwriting whatever may have been there before.

Returns: list of parameters (no argument), the parameter associated
with the first argument (one argument, two arguments),

B<param_toggled( $name )>

Given the name of a parameter, return 'yes' if it's defined and 'no'
if not.

B<param_date( $name, [ $strptime_format ]  )>

Given the name of a parameter return a L<DateTime|DateTime> object
populated with the data input from the HTTP request.

The parameter C<$name> can refer to:

=over 4

=item 1.

a single field, in which case you must specify a strptime format in
C<$format>

=item 2.

multiple fields where C<$name> is a prefix and '_year', '_month',
'_day' are the suffixes.

=back

For example:

 # mydate = '2003-04-01'
 my $datetime = $request->param_date( 'mydate', '%Y-%m-%d' );

 # mydate_year  = '2003'
 # mydate_month = '04'
 # mydate_day   = '01'
 my $datetime = $request->param_date( 'mydate' );

B<param_datetime( $name, [ $format ] )>

Similar to C<param_date> in that it reads parameter information and
returns a L<DateTime|DateTime> object, except it also reads hour,
minute and AM/PM information.

The parameter C<$name> can refer to:

=over 4

=item 1.

a single field, in which case you must specify a strptime format in
C<$format>

=item 2.

multiple fields where C<$name> is a prefix and '_year', '_month',
'_day', '_hour', '_minute' and '_am_pm' are the suffixes.

=back

For example:

 # mytime = '2003-04-01 6:08 PM'
 my $datetime = $request->param_date( 'mytime', '%Y-%m-%d %I:%M %p' );

 # mytime_year   = '2003'
 # mytime_month  = '04'
 # mytime_day    = '01'
 # mytime_hour   = '6'
 # mytime_minute = '08'
 # mytime_am_pm  = 'PM'
 my $datetime = $request->param_datetime( 'mytime' );

B<cookie( [ $name, $value ] )>

With no arguments it returns a list -- not an arrayref! -- of cookie
names the client passed in.

If you pass in C<$name> by itself you get the value associated with
the cookie. This is a simple scalar, not a L<CGI::Cookie|CGI::Cookie>
object.

If you pass in a C<$value> along with C<$name> then it's assigned to
C<$name>, overwriting whatever may have been there before.

B<Note>: These are only incoming cookies, those the client sends to
the server. For outgoing cookies (setting cookies on the client from
the server) see L<OpenInteract2::Response|OpenInteract2::Response>.

Returns: list of cookie names (no argument), the value associated with
the first argument (one argument, two arguments).

B<upload( [ $name ] )>

With no arguments, this returns a list -- B<not> an arrayref! -- of
L<OpenInteract2::Request::Upload|OpenInteract2::Request::Upload> objects
mapping to the files uploaded by the client. If you pass in C<$name>
then you get the specific
L<OpenInteract2::Request::Upload|OpenInteract2::Request::Upload> object
associated with it.

Returns: list of parameters (no argument), or the parameter associated
with the single argument.

B<clean_uploads()>

Deletes all uploads associated with the request.

=head1 PROPERTIES

B<url_absolute>

This is set to the URL the user entered, still containing the
deployment context.

B<url_relative>

This is set to the internal URL OI uses. It does not include the
deployment context. It should be the URL all actions deal with.

B<url_initial>

This is the URL we used to lookup the action.

B<server_name>

B<remote_host>

B<user_agent>

B<referer>

B<theme>

B<theme_values>

B<session>

B<action_name>

B<task_name>

B<auth_user>

B<auth_group>

B<auth_is_admin>

B<auth_is_logged_in>

B<auth_user_id>

Shortcut so you do not have to test whether the user is logged in to
get an ID. If the user is not logged in, you get a '0' back.

=head1 SUBCLASSING

If you're extending OpenInteract to a new architecture and need to
create a request adapter it's probably best to look at an existing one
to see what it does. (Working code is always more up-to-date than
documentation...) That said, here are a few tips:

=over 4

=item *

If your architecture is deployed under a particular URL you should set
this as soon as possible. Do so using the C<assign_deploy_url()>
method of the context. See
L<OpenInteract2::Request::CGI|OpenInteract2::Request::CGI> for an
example.

=back

Other than that take a look at
L<OpenInteract::Request::Standalone|OpenInteract::Request::Standalone>. It
forces you to deal with parameters and file uploads yourself, but it
may be the path of least resistance.

=head2 Methods

B<_set_url( $full_url )>

This method is implemented in this class but is called by the
implementing subclass. The subclass should pass the full, absolute URL
in so the C<url_absolute> and C<url_relative> properties are properly
set. This also sets the action name and task for use by the
controller.

B<_set_upload( $name, $upload )>

Associates the
L<OpenInteract2::Request::Upload|OpenInteract2::Request::Upload>
C<$upload> object with C<$name>.

Returns: the upload object

B<_parse_cookies( [ $cookie_header_string ] )>

Pass in the value from the client for the HTTP 'Cookie' header and the
string will be parsed and the name/value pairs assigned to the request
object. If C<$cookie_header_string> not passed in we look in the
C<cookie_header> property.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<Class::Factory|Class::Factory>

L<OpenInteract2::Request::Apache|OpenInteract2::Request::Apache>

L<OpenInteract2::Request::CGI|OpenInteract2::Request::CGI>

L<OpenInteract2::Request::LWP|OpenInteract2::Request::LWP>

L<OpenInteract2::Request::Standalone|OpenInteract2::Request::Standalone>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
