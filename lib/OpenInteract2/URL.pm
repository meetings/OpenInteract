package OpenInteract2::URL;

# $Id: URL.pm,v 1.13 2003/06/11 02:43:31 lachoy Exp $

use strict;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw(
    DEBUG LOG CTX DEPLOY_URL DEPLOY_IMAGE_URL DEPLOY_STATIC_URL
);
use URI;

use constant QUERY_ARG_SEPARATOR => '&amp;';

########################################
# URL PARSING

sub parse_absolute_to_relative {
    my ( $class, $url_absolute ) = @_;
    my $deployed_under = DEPLOY_URL;;
    $url_absolute =~ s/^$deployed_under//;
    return $url_absolute;
}

sub parse {
    my ( $class, $url_relative ) = @_;
    return _parse( $url_relative );
}

# Common alias
sub parse_relative { goto &parse }

sub parse_absolute {
    my ( $class, $url_absolute ) = @_;
    return _parse( $url_absolute, 'yes' );
}

sub _parse {
    my ( $url, $context_aware ) = @_;
    my $path = URI->new( $url )->path();

    if ( $context_aware and DEPLOY_URL ) {
        my $deployed_under = DEPLOY_URL;
        unless ( $path =~ s/^$deployed_under// ) {
            return ( undef, undef );
        }
    }

    my ( $action_name ) = $path =~ m|^/([^/?]+)|;
    my ( $task )        = $path =~ m|^/[^/]+/([^/?]+)|;

    return ( $action_name, $task );
}


########################################
# URL CREATION


sub create_relative_to_absolute {
    my ( $class, $url_relative ) = @_;
    my $deployed_under = DEPLOY_URL;
    return $url_relative unless ( $deployed_under );
    unless ( $url_relative =~ /^$deployed_under/ ) {
        $url_relative = join( '', $deployed_under, $url_relative );
    }
    return $url_relative;
}

sub create {
    my ( $class, $url_base, $params ) = @_;
    if ( $params->{IMAGE} ) {
        delete $params->{IMAGE};
        return $class->create_image( $url_base, $params );
    }
    elsif ( $params->{STATIC} ) {
        delete $params->{STATIC};
        return $class->create_image( $url_base, $params );
    }
    return $class->_create_deployment( DEPLOY_URL, $url_base, $params );
}

sub create_image {
    my ( $class, $url_base, $params ) = @_;
    return $class->_create_deployment(
               DEPLOY_IMAGE_URL, $url_base, $params );
}

sub create_static {
    my ( $class, $url_base, $params ) = @_;
    return $class->_create_deployment(
               DEPLOY_STATIC_URL, $url_base, $params );
}

# TODO: Modify to check 'REDIRECT' parameter to see if we should use
# '&amp;' or '&' for query argument separator?

sub _create_deployment {
    my ( $class, $deploy_under, $url_base, $params ) = @_;
    if ( $deploy_under ) {
        $url_base = join( '', $deploy_under, $url_base );
    }
    $params ||= {};
    return $url_base unless ( scalar keys %{ $params } );

	my $query = join( QUERY_ARG_SEPARATOR,
                      map  { "$_=" . _url_escape( $params->{ $_ } ) }
                      grep { defined $params->{ $_ } }
                      keys %{ $params } );
    return "$url_base?$query";

}

# NOTE: Coupling to OI2::Context->action_table with the 'url_primary'
# key.
#
# TODO: instead of using {url_primary}, first check and see if the
# action has a ->url property set.

sub create_from_action {
    my ( $class, $action, $task, $params ) = @_;
    my $info = eval { CTX->lookup_action_info( $action ) };

    # ...if the action isn't found
    if ( $@ ) {
        DEBUG && LOG( LWARN, "Request URL for action [$action] but ",
                             "it was not found" );
        return undef;
    }

    # ...if a URL for the action isn't found
    unless ( $info->{url_primary} ) {
        DEBUG && LOG( LWARN, "Request URL for action [$action] but ",
                             "primary URL was not found in action info; ",
                             "probably means it's not URL-accessible" );
        return undef;
    }

    my $url_base = ( $task ) ? "/$info->{url_primary}/$task/"
                             : "/$info->{url_primary}/";
    return $class->create( $url_base, $params );
}

sub _url_escape {
    my ( $to_encode ) = shift;
    return undef unless defined( $to_encode );
    $to_encode =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
    return $to_encode;
}

1;

__END__

=head1 NAME

OpenInteract2::URL - Create URLs, parse URLs and generate action mappings

=head1 SYNOPSIS

 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/foo/bar/?baz=42' );
 my $action = OpenInteract2::URL->parse_action( '/foo/bar/' );

=head1 DESCRIPTION

This class has methods to dealing with URLs. They are not complicated,
but they ensure that OpenInteract applications can be deployed under
any URL context without any changes to the code. They also ensure that
URLs are mapped properly to the Action that should generate the
relevant content.

All methods check the following configuration item:

 context_info.deployed_under

to see under what context the application is deployed. Many times this
will be empty, which means the application sits at the root.

=head1 METHODS

=head2 URL Parsing Methods

All methods are class methods.

B<parse_absolute_to_relative( $absolute_url )>

Just strips the deployment context from the front of C<$absolute_url>,
returning the relative URL. If the deployment context does not lead
C<$absolute_url>, just returns C<$absolute_url>.

Returns: relative URL.

Examples:

 CTX->assign_deploy_url( undef );
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/games/explore/' );
 # $relative_url = '/games/explore/';
 
 CTX->assign_deploy_url( '/Public' );
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/games/explore/' );
 # $relative_url = '/games/explore/';
 
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/games/?foo=bar' );
 # $relative_url = '/games/?foo=bar'
 
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/Public/games/explore/' );
 # $relative_url = '/games/explore/'
 
 my $relative_url = OpenInteract2::URL->parse_absolute_to_relative( '/Public/games/?foo=bar' );
 # $relative_url = '/games/?foo=bar'

B<parse( $url )>

Parses C<$url> into an action name and task, disregarding the URL
context. It does not attempt to verify whether the action name or the
task is valid. This should only be used on relative URLs, or ones
already stripped by the
L<OpenInteract2::Request|OpenInteract2::Request> object.

Note that an action name and task are still returned if an application
is deployed under a context and the URL does not start with that
context. See C<parse_absolute()> for a version that takes this into
account.

Return: two-item list of the action name and task pulled from
C<$url>. Note that the second item may be undefined.

Examples:

 CTX->assign_deploy_url( undef );
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/games/explore/' );
 # $action_name = 'games', $task = 'explore'
 
 CTX->assign_deploy_url( '/Public' );
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/games/explore/' );
 # $action_name = 'games', $task = 'explore';
 
 CTX->assign_deploy_url( '/Public' );
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/games/?foo=bar' );
 # $action_name = 'games', $task = undef;
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/Public/games/explore/' );
 # $action_name = 'games', $task = 'explore'
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse( '/Public/games/?foo=bar' );
 # $action_name = 'games', $task = undef

B<Alias>: C<parse_relative( $url )>

B<parse_absolute( $url )>

Almost exactly the same as C<parse( $url )>, except if the application
is deployed under a context and C<$url> does not begin with that
context no values are returned.

Return: two-item list of the action name and task pulled from C<$url>.

Examples:

 CTX->assign_deploy_url( undef );
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/games/explore/' );
 # $action_name = 'games', $task = 'explore'
 
 CTX->assign_deploy_url( '/Public' );
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/games/explore/' );
 # $action_name = undef, $task = undef;
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/games/?foo=bar' );
 # $action_name = undef, $task = undef;
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/Public/games/explore/' );
 # $action_name = 'games', $task = 'explore'
 
 my ( $action_name, $task ) = OpenInteract2::URL->parse_absolute( '/Public/games/?foo=bar' );
 # $action_name = 'games', $task = undef

=head2 URL Creation Methods

B<create_relative_to_absolute( $relative_url )>

Just ensures C<$relative_url> is located under the server context. If
it already is then C<relative_url> is returned, otherwise we prepend
the current server context to it and return that.

Returns: URL with leading server context.

B<create( $base_url, \%params )>

Create a URL using the deployed context (if any), a C<$base_url> and
C<\%params> as a query string. This allows you to deploy your
application under any URL context and have all the internal URLs
continue to work properly.

If no C<\%params> are specified then the resulting URL will B<not>
have a trailing '?' to indicate the start of a query string. This is
important to note if you're doing further manipulation of the URL,
such as you with if you were embedding it in generated Javascript.

Return: URL formed from the deployed context, C<$base_url> and
C<\%params>.

Examples:

 CTX->assign_deploy_url( undef );

 $url = OpenInteract2::URL->create( '/foo');
 # $url = '/foo'
 
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz' } );
 # $url = '/foo?bar=baz'
 
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz', blah => 'blech' } );
 # $url = '/foo?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create( '/foo', { name => 'Mario Lemieux' } );
 # $url = '/foo?name=Mario%20Lemiux'
 
 CTX->assign_deploy_url( '/Public' );
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz' } );
 # $url = '/Public/foo?bar=baz'
 
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz', blah => 'blech' } );
 # $url = '/Public/foo?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create( '/foo', { name => 'Mario Lemieux' } );
 # $url = '/Public/foo?name=Mario%20Lemiux'
 
 CTX->assign_deploy_url( '/cgi-bin/oi.cgi' );
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz' } );
 # $url = '/cgi-bin/oi.cgi/Public/foo?bar=baz'
 
 $url = OpenInteract2::URL->create( '/foo', { bar => 'baz', blah => 'blech' } );
 # $url = '/cgi-bin/oi.cgi/Public/foo?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create( '/foo', { name => 'Mario Lemieux' } );
 # $url = '/cgi-bin/oi.cgi/Public/foo?name=Mario%20Lemiux'

B<create_image( $base_url, \%params )>

Create a URL using the deployed image context (if any), a C<$base_url>
and C<\%params> as a query string. This allows you to keep your images
under any URL context and have all the internal URLs continue to work
properly.

If no C<\%params> are specified then the resulting URL will B<not>
have a trailing '?' to indicate the start of a query string. This is
important to note if you're doing further manipulation of the URL,
such as you with if you were embedding it in generated Javascript.

Return: URL formed from the deployed context, C<$base_url> and
C<\%params>.

Examples:

 CTX->server_config->{context_info}{deployed_under_image} = undef;
 $url = OpenInteract2::URL->create_image( '/images/foo.png' );
 # $url = '/images/foo.png'
 
 $url = OpenInteract2::URL->create_image( '/gallery/photo.php',
                                          { id => 154393 } );
 # $url = '/gallery/photo.php?id=154393'
 
 CTX->server_config->{context_info}{deployed_under_image} = '/IMG';
 $url = OpenInteract2::URL->create_image( '/images/foo.png' );
 # $url = '/IMG/images/foo.png'
 
 $url = OpenInteract2::URL->create_image( '/gallery/photo.php',
                                          { id => 154393 } );
 # $url = '/IMG/gallery/photo.php?id=154393'


B<create_static( $base_url, \%params )>

Create a URL using the deployed static context (if any), a
C<$base_url> and C<\%params> as a query string. This allows you to
keep your static files under any URL context and have all the internal
URLs continue to work properly.

If no C<\%params> are specified then the resulting URL will B<not>
have a trailing '?' to indicate the start of a query string. This is
important to note if you're doing further manipulation of the URL,
such as you with if you were embedding it in generated Javascript.

Return: URL formed from the deployed context, C<$base_url> and
C<\%params>.

Examples:

 CTX->server_config->{context_info}{deployed_under_static} = undef;
 $url = OpenInteract2::URL->create_static( '/static/site.rdf' );
 # $url = '/static/site.rdf'
 
 $url = OpenInteract2::URL->create_static( '/reports/q1-2003-01.pdf' );
 # $url = '/reports/q1-2003-01.pdf'
 
 CTX->server_config->{context_info}{deployed_under_static} = '/STAT';
 $url = OpenInteract2::URL->create_static( '/static/site.rdf' );
 # $url = '/STAT/static/site.rdf'
 
 $url = OpenInteract2::URL->create_static( '/reports/q1-2003-01.pdf' );
 # $url = '/STAT/reports/q1-2003-01.pdf'

B<create_from_action( $action, $task, \%params )>

Similar to C<create()>, except first we find the primary URL for
C<$action> from the L<OpenInteract2::Context|OpenInteract2::Context>
object, add the optional C<$task> to that and send it to C<create()>
as the 'base_url' parameter.

If C<$action> is not found in the context we return C<undef>. And if
there is no primary URL for C<$action> in the context we also return
C<undef>.

See discussion in L<OpenInteract2::Action|OpenInteract2::Action> under
C<MAPPING URL TO ACTION> for what the 'primary URL' is and other
issues.

Return: URL formed from the deployed context, URL formed by looking up
the primary URL of C<$action> and the C<$task>, plus any additional
C<\%params>.

Examples, assuming that 'Foo' is the primary URL for action 'foo'.

 CTX->assign_deploy_url( undef );
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'edit', { bar => 'baz' } );
 # $url = '/Foo/edit/?bar=baz'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'edit', { bar => 'baz', blah => 'blech' } );
 # $url = '/Foo/edit/?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', undef, { name => 'Mario Lemieux' } );
 # $url = '/Foo/?name=Mario%20Lemiux'
 
 CTX->assign_deploy_url( '/Public' );
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'show', { bar => 'baz' } );
 # $url = '/Public/Foo/show/?bar=baz'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', undef, { bar => 'baz', blah => 'blech' } );
 # $url = '/Public/Foo/?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'show', { name => 'Mario Lemieux' } );
 # $url = '/Public/Foo/show/?name=Mario%20Lemiux'
 
 CTX->assign_deploy_url( '/cgi-bin/oi.cgi' );
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'list', { bar => 'baz' } );
 # $url = '/cgi-bin/oi.cgi/Public/Foo/list/?bar=baz'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', undef, { bar => 'baz', blah => 'blech' } );
 # $url = '/cgi-bin/oi.cgi/Public/Foo/?bar=baz;blah=blech'
 
 $url = OpenInteract2::URL->create_from_action(
                    'foo', 'detail', { name => 'Mario Lemieux' } );
 # $url = '/cgi-bin/oi.cgi/Public/Foo/detail/?name=Mario%20Lemiux'

=head1 SEE ALSO

L<URI|URI>

L<OpenInteract2::Context|OpenInteract2::Context>

=head1 COPYRIGHT

Copyright (c) 2002-2003 intes.net. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
