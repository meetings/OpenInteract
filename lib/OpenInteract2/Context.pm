package OpenInteract2::Context;

# $Id: Context.pm,v 1.35 2003/07/02 15:47:00 lachoy Exp $

use strict;
use base                     qw( Exporter Class::Accessor );
use Data::Dumper             qw( Dumper );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Log;

$OpenInteract2::Context::VERSION   = sprintf("%d.%02d", q$Revision: 1.35 $ =~ /(\d+)\.(\d+)/);

sub version { return '1.99_01' }

# Exportable deployment URL call -- main, images, static

my ( $DEPLOY_URL, $DEPLOY_IMAGE_URL, $DEPLOY_STATIC_URL );
sub DEPLOY_URL        { return $DEPLOY_URL }
sub DEPLOY_IMAGE_URL  { return $DEPLOY_IMAGE_URL }
sub DEPLOY_STATIC_URL { return $DEPLOY_STATIC_URL }

# This is the only copy of the context that should be around. We might
# modify this later so we can have multiple copies of the context
# around (produced by, say, a ContextFactory), but W(P)AGNI. Note that
# before accessing the exported variable you should first ensure that
# it's initialized.

my ( $CTX );
sub CTX { return $CTX }

@OpenInteract2::Context::EXPORT_OK = qw(
     CTX DEPLOY_URL DEPLOY_IMAGE_URL DEPLOY_STATIC_URL
);

require OpenInteract2::Config::Base;
require OpenInteract2::DatasourceManager;
require OpenInteract2::Filter;
require OpenInteract2::Request;
require OpenInteract2::Response;
require OpenInteract2::Setup;
require OpenInteract2::Action;
require OpenInteract2::Controller;

my @CORE_FIELDS    = qw( base_config server_config repository packages cache
                         datasource_manager );
my @REQUEST_FIELDS = qw( request response controller user group is_logged_in is_admin );
__PACKAGE__->mk_accessors( @CORE_FIELDS, @REQUEST_FIELDS );

########################################
# CONSTRUCTOR AND INITIALIZATION

# $item should be either a hashref of parameters (preferably with one
# parameter 'website_dir') or an OI::Config::Base object

sub create {
    my ( $class, $item, $params ) = @_;
    return $CTX if ( $CTX );
    $item   ||= {};
    $params ||= {};

    my ( $website_dir );
    $CTX = bless( {}, $class );
    my ( $base_config );
    if ( ref $item eq 'OpenInteract2::Config::Base' ) {
        $base_config = $item;
        $website_dir = $base_config->website_dir;
    }
    elsif ( $item->{website_dir} ) {
        $base_config = eval {
            OpenInteract2::Config::Base->new({
                              website_dir => $item->{website_dir} })
        };
        if ( $@ ) {
            oi_error "Cannot create base config object using website ",
                     "directory [$item->{website_dir}]: $@";
        }
        $website_dir = $item->{website_dir};
    }

    # this is typically only set from standalone scripts; see POD

    if ( $params->{initialize_log} and -d $website_dir ) {
        OpenInteract2::Log->init_from_website( $website_dir );
    }
    elsif ( $params->{initialize_log} ) {
        OpenInteract2::Log->init_screen;
    }

    my $log = get_logger( LOG_INIT );

    if ( $base_config ) {
        $CTX->base_config( $base_config );
        $log->is_debug && $log->debug( "Assigned base config ok" );
        eval { $CTX->setup( $params ) };
        if ( $@ ) {
            $log->error( "Setup failed to run: $@" );
        }
        else {
            $log->is_info && $log->info( "Setup ran ok" );
        }
    }
    return $CTX;
}


sub instance {
    my ( $class ) = @_;
    return $CTX if ( $CTX );
    oi_error "No context available; first call 'create()'";
}


# Initialize the Context

sub setup {
    my ( $self, $params ) = @_;
    $params ||= {};
    my $log = get_logger( LOG_INIT );

    my %skip = ();
    if ( $params->{skip} ) {
        if ( ref $params->{skip} ne 'ARRAY' ) {
            $params->{skip} = [ $params->{skip} ];
        }
        %skip = map { $_ => 1 } @{ $params->{skip} };
    }

    my $base_config = $self->base_config;
    unless ( $base_config and
             ref( $base_config ) eq 'OpenInteract2::Config::Base' ) {
        $log->error( "Cannot run setup() without base_config defined" );
        oi_error "Cannot run setup() on context without a valid base ",
                 "configuration object set";
    }

    my $setup = OpenInteract2::Setup->new;
    my $server_config = $setup->read_server_config;
    $self->server_config( $server_config );
    $log->is_info && $log->info( "Assigned server config ok" );

    # Assign constants from server config to the context.

    $self->assign_deploy_url;
    $self->assign_deploy_image_url;
    $self->assign_deploy_static_url;
    $self->assign_request_type;
    $self->assign_response_type;
    $log->is_info &&
        $log->info( "Assigned constants from server config ok" );

    if ( $skip{ 'initialize repository' } ) {
        $skip{ 'initialize temp lib' }++;
        $skip{ 'initialize action' }++;
        $skip{ 'initialize spops' }++;
        $skip{ 'initialize controller' }++;
    }
    else {
        my $repository = $setup->read_repository;
        if ( $repository ) {
            $self->repository( $repository );
            my $packages = $setup->read_packages;
            $self->packages( $packages );
        }
        $log->is_info &&
            $log->info( "Opened repository and read package definitions ok" );
    }


    unless ( $skip{ 'initialize temp lib' } ) {
        $setup->create_temp_lib( $params );
    }

    unless ( $skip{ 'initialize alias' } ) {
        my @alias_classes = ();
        my $aliases = $setup->read_aliases;
        foreach my $type ( keys %{ $aliases } ) {
            while ( my ( $alias, $alias_to ) = each %{ $aliases->{ $type } } ) {
                $self->alias( $type, $alias, $alias_to );
                push @alias_classes, $alias_to;
            }
        }
        $setup->require_module({ class => \@alias_classes });
        $log->is_info && $log->info( "Required alias classes ok" );
    }

    unless ( $skip{ 'initialize datasource' } ) {
        my $ds_manager_class = $server_config->{datasource_config}{manager};
        eval "require $ds_manager_class";
        $self->datasource_manager( $ds_manager_class );
        $log->is_info && $log->info( "Assigned aliases ok" );
        $setup->check_datasources();
    }

    if ( $skip{ 'initialize action' } ) {
        $skip{ 'initialze controller' }++;
    }
    else {
        my $action_table = $setup->read_action_table;
        $log->is_info && $log->info( "Read action table ok" );
        $setup->require_action_classes( $action_table );
        $setup->register_action_types;
        $log->is_info && $log->info( "Required action classes ok" );
        $self->action_table( $action_table );
        $log->is_info && $log->info( "Assigned action table ok" );
        $setup->initialize_action_filters;
        $log->is_info && $log->info( "Assigned filters (if any) ok" );
    }

    unless ( $skip{ 'initialize spops' } ) {
        my $spops_config = $setup->read_spops_config;
        $log->is_info && $log->info( "Read SPOPS configurations ok" );
        unless ( $skip{ 'activate spops' } ) {
            $setup->activate_spops_classes( $spops_config );
            $log->is_info && $log->info( "Activated SPOPS classes ok" );
        }
        $self->spops_config( $spops_config );
        $log->is_info && $log->info( "Assigned SPOPS table ok" );
    }

    unless ( $skip{ 'initialize session' } ) {
        $setup->require_session_classes( $server_config->{session_info} );
    }

    unless ( $skip{ 'initialize cache' } ) {
        my $cache = $setup->create_cache;
        if ( $cache ) {
            $self->cache( $cache );
            $log->is_info && $log->info( "Created cache ok" );
        }
        else {
            $log->is_info &&
                $log->info( "Cache not configured for use, ok" );
        }
    }

    unless ( $skip{ 'initialize generator' } ) {
        $setup->initialize_content_generator;
        $log->is_info && $log->info( "Initialized content generators ok" );
    }

    unless ( $skip{ 'initialze controller' } ) {
        $setup->initialize_controller;
        $log->is_info &&
            $log->info( "Initialized controller and default actions ok" );
    }

    $log->is_debug && $log->info( "Initialized context ok" );
    return $self;
}


########################################
# CONFIGURATION ASSIGNMENTS
#
# These subroutines generally map to some basic system information
# that can be modified at runtime in addition to the modifications in
# the configuration. Note: modifications made here should get
# reflected in the configuration as well.


# Where is this app deployed under?

sub assign_deploy_url {
    my ( $self, $url ) = @_;
    my $log = get_logger( LOG_INIT );
    $url ||= $self->server_config->{context_info}{deployed_under};
    $url = $self->_clean_deploy_url( $url );
    if ( $url and $url !~ m|^/| ) {
        oi_error "Deployment URL *MUST* begin with a '/'. It may not ",
                 "be a fully-qualified URL (e.g., 'http://foo.com/') ",
                 "and it may not be a purely relative URL (e.g., 'oi')";
    }
    $DEPLOY_URL = $url;
    $self->server_config->{context_info}{deployed_under} = $url;
    $log->is_info && $log->info( "Assigned deployment URL [$url]" );
    return $DEPLOY_URL;
}

sub assign_deploy_image_url {
    my ( $self, $url ) = @_;
    my $log = get_logger( LOG_INIT );
    $url ||= $self->server_config->{context_info}{deployed_under_image};
    $url = $self->_clean_deploy_url( $url );
    $DEPLOY_IMAGE_URL = $url;
    $self->server_config->{context_info}{deployed_under_image} = $url;
    $log->is_info &&
        $log->info( "Assigned image deployment URL [$url]" );
    return $DEPLOY_IMAGE_URL;
}

sub assign_deploy_static_url {
    my ( $self, $url ) = @_;
    my $log = get_logger( LOG_INIT );
    $url ||= $self->server_config->{context_info}{deployed_under_static};
    $url = $self->_clean_deploy_url( $url );
    $DEPLOY_STATIC_URL = $url;
    $self->server_config->{context_info}{deployed_under_static} = $url;
    $log->is_info &&
        $log->info( "Assigned static deployment URL [$url]" );
    return $DEPLOY_STATIC_URL;
}

sub _clean_deploy_url {
    my ( $self, $url ) = @_;
    return '' unless ( $url );
    $url =~ s/^\s+//;
    $url =~ s/\s+$//;
    $url =~ s|/$||;
    return $url;
}

# What type of requests/responses are we getting/generating?

sub assign_request_type {
    my ( $self, $type ) = @_;
    my $log = get_logger( LOG_INIT );
    $type ||= $self->server_config->{context_info}{request};
    $self->server_config->{context_info}{request} = $type;
    OpenInteract2::Request->set_implementation_type( $type );
    $log->is_info &&
        $log->info( "Assigned request type [$type]" );
}


sub assign_response_type {
    my ( $self, $type ) = @_;
    my $log = get_logger( LOG_INIT );
    $type ||= $self->server_config->{context_info}{response};
    $self->server_config->{context_info}{response} = $type;
    OpenInteract2::Response->set_implementation_type( $type );
    $log->is_info &&
        $log->info( "Assigned response type [$type]" );
}


########################################
# ACTION LOOKUP

sub lookup_action_name {
    my ( $self, $action_url ) = @_;
    my $log = get_logger( LOG_ACTION );
    unless ( $action_url ) {
        oi_error "Cannot lookup action without action name without URL";
    }
    $log->is_debug &&
        $log->debug( "Try to find action name for URL [$action_url]" );
    my $server_config = $self->server_config;
    my $action_name = $server_config->{action_url}{ $action_url };
    $log->is_debug &&
        $log->debug( "Found name [$action_name] for URL [$action_url]" );
    return $action_name;
}

sub lookup_action_info {
    my ( $self, $action_name ) = @_;
    my $log = get_logger( LOG_ACTION );
    unless ( $action_name ) {
        $log->error( "No action name given to lookup info" );
        oi_error "Cannot lookup action without action name";
    }

    $log->is_debug &&
        $log->debug( "Try to find action info for [$action_name]" );
    my $server_config = $self->server_config;
    my $action_info = $server_config->{action}{ lc $action_name };

    # Let the caller deal with a not found action rather than assuming
    # we know best.

    unless ( $action_info ) {
        $log->error( "Action [$action_name] not found in action table" );
        oi_error "Action [$action_name] not found in action table";
    }

    $log->is_debug && $log->debug( "Action [$action_name] is ",
                           "[Class: $action_info->{class}] ",
                           "[Template: $action_info->{template}] " );

    # Allow as many redirects as we need

    my $current_name = $action_name;
    while ( my $action_redir = $action_info->{redir} ) {
        $action_info = $server_config->{action}{ lc $action_redir };
        unless ( $action_info ) {
            $log->warn( "Failed redirect from [$current_name] to ",
                        "[$action_redir]: no action defined " );
            return undef;
        }
        $log->is_debug &&
            $log->debug( "Redirect to [$action_redir]" );
        $current_name = $action_redir;
    }
    return $action_info;
}


sub lookup_action {
    my ( $self, $action_name, $props ) = @_;
    my $log = get_logger( LOG_ACTION );
    my $action_info = $self->lookup_action_info( $action_name );
    unless ( $action_info ) {
        $log->error( "No action found for [$action_name]" );
        oi_error "No action defined for [$action_name]";
    }
    return OpenInteract2::Action->new( $action_info, $props );
}


sub lookup_action_none {
    my ( $self ) = @_;
    my $log = get_logger( LOG_ACTION );
    my $action_info = $self->server_config->{action_info}{none};
    unless ( $action_info ) {
        $log->error( "Please define the server configuration entry ",
                     "under 'action_info.none'" );
        oi_error "The 'none' item under 'action_info' is not defined. ",
                 "Please check your server configuration.";
    }
    if ( my $action_name = $action_info->{redir} ) {
        return $self->lookup_action( $action_name );
    }
    return OpenInteract2::Action->new( $action_info );
}


sub lookup_action_not_found {
    my ( $self ) = @_;
    my $log = get_logger( LOG_ACTION );
    my $action_info = $self->server_config->{action_info}{not_found};
    unless ( $action_info ) {
        $log->error( "Please define the server configuration entry ",
                     "under 'action_info.not_found'" );
        oi_error "The 'not_found' item under 'action_info' is not ",
                 "defined. Please check your server configuration.";
    }
    if ( my $action_name = $action_info->{redir} ) {
        return $self->lookup_action( $action_name );
    }
    return OpenInteract2::Action->new( $action_info );
}


########################################
# OBJECT CLASS LOOKUP

sub lookup_object {
    my ( $self, $object_name ) = @_;
    my $log = get_logger( LOG_SPOPS );
    unless ( $object_name ) {
        $log->error( "Must lookup object class using name" );
        oi_error "Cannot lookup object class without object name";
    }
    my $spops_config = $self->spops_config;
    unless ( $spops_config->{ lc $object_name } ) {
        my $msg = "No object class found for [$object_name]";
        $log->error( $msg );
        oi_error $msg;
    }
    my $object_class = $spops_config->{ lc $object_name }{class};
    $log->is_debug &&
        $log->debug( "Found class [$object_class] for [$object_name]" );
    return $object_class;
}


########################################
# CONTROLLER LOOKUP

sub lookup_controller {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->server_config->{controller}{ $name };
    }
    return $self->server_config->{controller};
}

########################################
# CONTENT GENERATOR LOOKUP

sub lookup_content_generator {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->server_config->{content_generator}{ $name };
    }
    return $self->server_config->{content_generator};
}

sub lookup_filter {
    my ( $self, $name ) = @_;
    if ( $name ) {
        return $self->{filters}{ $name };
    }
    return $self->{filters};
}

sub set_filter_registry {
    my ( $self, $registry ) = @_;
    $self->{filters} = $registry;
    return;
}

sub add_filter {
    my ( $self, $filter_name, $filter_info ) = @_;
    OpenInteract2::Filter->register_filter(
            $filter_name, $filter_info, $self->{filters} );
}

########################################
# DIRECTORY LOOKUP

sub lookup_directory {
    my ( $self, $dir_name ) = @_;
    if ( $dir_name ) {
        return $self->server_config->{dir}{ $dir_name };
    }
    return $self->server_config->{dir};
}

########################################
# GLOBAL SETTINGS/ALIASES

# These are generally temporary
# TODO: Get rid of these?

sub global_attribute {
    my ( $self, $name, $value ) = @_;
    return undef unless ( $name );
    if ( $value ) { $self->{attrib}{ $name } = $value }
    return $self->{attrib}{ $name };
}


sub clear_global_attributes {
    my ( $self ) = @_;
    return $self->{attrib} = {};
}

# TODO: Could this closure be a potential memory leak? Test!

sub alias {
    my ( $self, $type, $name, $value ) = @_;
    return unless ( $type and $name );
    if ( $value ) {
        $self->{alias}{ $type }{ $name } = $value;
        my $class = ref $self;
        no strict 'refs';
        *{ $class . '::' . $name } = sub { return $value };
    }
    return $self->{alias}{ $type }{ $name };
}


# Config shortcut

# NOTE: Coupling to OI2::URL->create_from_action with the
# 'url_primary' key.

sub action_table {
    my ( $self, $table ) = @_;
    my $log = get_logger( LOG_ACTION );
    if ( $table ) {
        $log->is_info &&
            $log->info( "Assigning new action table" );
        $self->server_config->{action} = $table;
        my %url_to_name = ();
        while ( my ( $name, $info ) = each %{ $table } ) {
            $log->is_debug &&
                $log->debug( "Finding URL(s) for action [$name]" );
            my $action = OpenInteract2::Action->new( $info );
            my $respond_urls = $action->get_dispatch_urls;
            $url_to_name{ $_ } = $name for ( @{ $respond_urls } );
            $info->{url_primary} = $respond_urls->[0];
        }
        $self->server_config->{action_url} = \%url_to_name;
    }
    return $self->server_config->{action};
}

# Config shortcut

sub spops_config {
    my ( $self, $table ) = @_;
    my $log = get_logger( LOG_SPOPS );
    if ( $table ) {
        $log->is_info &&
            $log->info( "Assigning new SPOPS configuration" );
        $self->server_config->{SPOPS} = $table;
    }
    return $self->server_config->{SPOPS};
}

# Config shortcut

sub datasource_config {
    my ( $self ) = @_;
    return $self->server_config->{datasource};
}


########################################
# GLOBAL RESOURCES

# Get the named datasource -- just pass along the request to the
# DatasourceManager

sub datasource {
    my ( $self, $name ) = @_;
    $name ||= $self->server_config->{datasource_config}{system};
    return OpenInteract2::DatasourceManager->datasource( $name );
}

sub content_generator {
    my ( $self, $name ) = @_;
    return OpenInteract2::ContentGenerator->instance( $name );
}

# Use a routine rather than letting Class::Accesor to do this because
# we'll probably allow for multiple templates, and multiple types of
# templates, to be stored

sub template {
    my ( $self, $template ) = @_;
    my $log = get_logger( LOG_TEMPLATE );
    if ( $template ) {
        $log->is_info &&
            $log->info( "Assigning new template object" );
        $self->{template} = $template;
    }
    return $self->{template};
}


sub cleanup_request {
    my ( $self ) = @_;
    $self->set( $_, undef )  for ( @REQUEST_FIELDS );
    $self->clear_global_attributes;
    $self->clear_exceptions;
}


# Shortcut -- use to check security on classes that are not derived
# from SPOPS::Secure, or from other resources

sub check_security {
    my ( $self, $params ) = @_;
    my $log = get_logger( LOG_SECURITY );

    # TODO: make static at startup...
    my $security_class = $self->lookup_object( 'security' );

    my %security_info = ( security_object_class => $security_class,
                          class                 => $params->{class},
                          object_id             => $params->{object_id},
                          user                  => $params->{user},
                          group                 => $params->{group} );
    my $request = $self->request;
    if ( $request and $request->auth_is_logged_in ) {
        $log->is_debug &&
            $log->debug( "Assigning user/group from login" );
        $security_info{user}  ||= $request->auth_user;
        $security_info{group} ||= $request->auth_group;
    }
    $log->is_debug &&
        $log->debug( "Checking security for [$params->{class}] ",
                     "[$params->{object_id}] with [$security_class]" );
    return SPOPS::Secure->check_security( \%security_info );
}


########################################
# EXCEPTIONS

# Exception shortcuts (may remove?)

sub throw            { shift; goto &OpenInteract2::Exception::throw( @_ ) }


# outside world doesn't need to know...

sub dump {
    shift;
    my $output = '';
    $output .= Dumper( $_ ) for ( @_ );
    return $output;
}

1;

__END__

=head1 NAME

OpenInteract2::Context - Provides the environment for a server

=head1 SYNOPSIS

 use OpenInteract2::Context qw( CTX );
 
 # You can create a variable for the context as well, but normal way
 # is to import it
 my $ctx = OpenInteract2::Context->instance;
 
 # Get the information for the 'TT" content generator
 my $generator_info = CTX->content_generator( 'TT' );
 
 # Grab the server configuration
 my $conf = CTX->server_config;
 
 # Grab the 'main' datasource -- this could be DBI/LDAP/...
 my $db = CTX->datasource( 'main' );
 
 # Get the 'accounting' datasource
 my $db = CTX->datasource( 'accounting' );
 
 # Get the default system datasource
 my $db = CTX->datasource;
 
 # Get the template object (XXX: Future -- may be named like datasource...)
 my $template = CTX->template;
 
 # Find an object class
 my $news_class = CTX->lookup_object( 'news' );
 my $news = $news_class->fetch( 42 );
 
 # All in one step
 my $news = CTX->lookup_object( 'news' )->fetch( 42 );
 
 # Lookup an action
 my $action = CTX->lookup_action( 'news' );
 $action->params({ security_level => 8, news => $news });
 $action->task( 'show' );
 return $action->execute;
 
 # XXX: Add a cleanup handler (NOT DONE)
 #CTX->add_handler( 'cleanup', \&my_cleanup );

=head1 DESCRIPTION

This class supports a singleton object that contains your server
configuration plus pointers to other OpenInteract services. Much of
the information it holds is similar to what was in the
C<OpenInteract::Request> (C<$R>) object in OpenInteract 1.x. However,
the L<OpenInteract2::Context|OpenInteract2::Context> object does not
include any information about the current request.

The information is holds and services it provides access to include:

=over 4

=item B<configuration>

The data in the server configuration is always available. (See
C<server_config> property.)

=item B<datasource>

All datasources are retrieved through the context, including DBI, LDAP
and any others. (See C<datasource()>)

=item B<object aliases>

SPOPS object classes are stored based on the name so you do not need
to know the class of the object you are working with, just the
name. (See C<lookup_object()>)

=item B<actions>

The context contains the action table and can lookup action
information as well as create a
L<OpenInteract2::Action|OpenInteract2::Action> object from it. (See
C<lookup_action()>, C<lookup_action_info()>, C<lookup_action_none()>,
C<lookup_action_not_found()>)

=item B<controllers>

The context provides a shortcut to lookup controller information from
the server configuration.

=item B<other aliases>

Other classes are stored on an alias basis as well; currently this is
limited to the items under the configuration key C<system_alias>. (See
C<alias()>)

=item B<security checking>

You can check the security for any object or class from one
place. (See C<check_security()>

=item B<caching>

If it is configured, you can get the cache object for storing or
looking up data. (See C<cache> property)

=item B<packages>

The package repository and packages in your site are available from
the context. (See properties C<repository> and C<packages>)

=back

=head1 METHODS

=head2 Class Methods

B<instance()>

This is the method you will see many times when the object is not
being imported, since it returns the current context. There is only
one context object available at any one time. If the context has not
yet been created (with C<create()>), throws an exception.

Returns: L<OpenInteract2::Context|OpenInteract2::Context> object

B<create( $base_config|\%config_params, [ \%setup_params ] )>

Creates a new context. If you pass in a
L<OpenInteract2::Config::Base|OpenInteract2::Config::Base> object or
specify 'website_dir' in C<\%setup_params>, it will run the server
initialization routines in C<setup()>. (If you pass in an invalid
directory for the parameter an exception is thrown.)

If you do not know these items when the context is created, you can do
something like:

 my $ctx = OpenInteract2::Context->create();
 
 ... some time later ...
 
 my $base_config = OpenInteract2::Config::Base->new({ website_dir => $dir } );
 ... or ...
 my $base_config = OpenInteract2::Config::Base->new({ filename => $file } );
 $ctx->base_config( $base_config );
 $ctx->setup();

You may also initialize the L<Log::Log4perl|Log::Log4perl> logger when
creating the context by passing a true value for the 'initialize_log'
parameter in C<\%setup_params>. This is typically only done for
standalone scripts and as a convenience. For example:

 my $ctx = OpenInteract2::Context->create( { website_dir => $dir },
                                           { initialize_log => 1 });

Finally, C<create()> stores the context for later retrieval by
C<instance()>.

If the context has already been created then it is returned just as if
you had called C<instance()>.

See C<setup()> for the parameters possible in C<\%setup_params>.

Returns: the new L<OpenInteract2::Context|OpenInteract2::Context> object.

B<setup( \%params )>

Runs a series of routines, mostly from
L<OpenInteract2::Setup|OpenInteract2::Setup>, to initialize the
singleton context object. If the C<base_config> property has not been
set with a valid
L<OpenInteract2::Config::Base|OpenInteract2::Config::Base> object, an
exception is thrown.

If you pass to C<create()> a C<base_config> object or a valid website
directory, C<setup()> will be called automatically.

You can skip steps of the process by passing the step name in an
arrayref 'skip' in C<\%params>. (You normally pass these to
C<create()>.) This is most useful when you're creating a website for
the first time.

For instance, if you do not wish to activate the SPOPS objects:

 OpenInteract2::Context->create({ skip => 'activate spops' });

If you do not wish to read in the action table or SPOPS configuration:

 OpenInteract2::Context->create({ skip => [ 'initialize action',
                                            'initialize spops' ] });

The steps we take to setup the site are listed below. Steps performed
by L<OpenInteract2::Setup|OpenInteract2::Setup> are marked with the
method called.

=over 4

=item *

Read in the server configuration and assign the debugging level from
it. (Setup: C<read_server_config()>) (Skip: n/a)

=item *

Read in the package repository (Setup: C<read_repository()>) and all
packages in the site (Setup: C<read_packages()>). (Skip: 'initialize
repository')

=item *

Create a temporary library directory so all classes are found in one
location. (Setup: C<create_temp_lib>) (Skip: 'initialize temp lib')

=item *

Create aliases from the server configuration. These are stored under
the configuration key C<system_alias>. (Setup: C<read_aliases()>) We
also ensure that the classes aliased are brought into the system via
C<require>. (Skip: 'initialize alias')

=item *

Require modules specified in the C<session_info> server configuration
key under 'class' and 'impl_class'. (Skip: 'initialize session')

=item *

Read in the action table from the available packages. (Setup:
C<read_action_table()>) We also ensure that all classes referenced in
the action table are brought into the system via C<require>. (Skip:
'initialize action')

=item *

Read in the SPOPS object configurations from the available
packages. (Setup: C<read_spops_config()>) Activate all SPOPS objects
at once. (Setup: C<activate_spops_classes()>) (Skip: 'initialize
spops'; you can also skip just the activation step with 'activate
spops')

=item *

Create the cache. If it is not configured this is a no-op. (Setup:
C<create_cache()>) (Skip: 'initialize cache')

=item *

Initialize all content generators. (Setup:
C<initialize_content_generator()>) (Skip: 'initialize generator')

=item *

Initialize the main controller with default actions. (Skip:
'initialize controller'; also skipped with 'initialize action')

=back

Returns: the context object

=head2 Object Methods: Actions

B<lookup_action( $action_name [, \%values )>

Looks up the information for C<$action_name> in the action table and
returns a L<OpenInteract2::Action|OpenInteract2::Action> object
created from it. We also pass along C<\%values> as the second argument
to C<new()> -- any properties found there will override what's in the
action table configuration, and any properties there will be set into
the resulting object.

If C<$action_name> is not found, an exception is thrown.

Returns: L<OpenInteract2::Action|OpenInteract2::Action> object

B<lookup_action_name( $url_chunk )>

Given the URL piece C<$url_chunk>, find the associated action
name. Whenever we set the action table (using C<action_table()>), we
scan the actions to see if they have an associated URL, peeking into
the 'url' key in the action configuration.

If so, we only create one entry in the URL-to-name mapping.

If not, we create three entries in the URL-to-name mapping: the
lowercased name, the uppercased name, and the name with the first
character uppercased.

Additionally, we check the action configuration key 'url_alt' to see
if it may have one or more URLs that it responds to. Each of these go
into the URL-to-name mapping as well.

For example, say we had the following action configuration:

 [news]
 class = OpenInteract2::Action::News
 task_default = list

This would give the action key 'news' to three separate URLs: 'news',
'NEWS', and 'News'.

Given:

 [news]
 class = OpenInteract2::Action::News
 task_default = list
 url_alt = NeWs
 url_alt = Newsy

It would respond to the three URLs listed above, plus 'NeWs' and
'Newsy'.

Given:

 [news]
 class = OpenInteract2::Action::News
 task_default = list
 url = WhatReallyMatters

It would only respond to a single URL: 'WhatReallyMatters'.

B<lookup_action_none()>

Finds the action configured for no name -- this is used when the user
does not specify an action to take, such as when the root of a
deployed URL is queried. (e.g., 'http://www.mysite.com/')

If the configured item is not found or the action it refers to is not
found, an exception is thrown.

Returns: L<OpenInteract2::Action|OpenInteract2::Action> object

B<lookup_action_not_found()>

Finds the action configured for when an action is not found. This can
be used when an action is requested but not found in the action
table. Think of it as a 'catch-all' for requests you cannot foresee in
advance, such as mapping requests to the filesystem to an OpenInteract
action.

Currently, this is not called by default when you try to lookup an
action that is not found. This is a change from 1.x behavior. Instead,
you would probably do something like:

 my $action = eval { CTX->lookup_action( 'my_action' ) };
 if ( $@ ) {
     $action = eval { CTX->lookup_action_not_found() };
 }

This requires more on your part, but there is no peek-a-boo logic
going on, which to us is a good trade-off.

If the configured item is not found or the action it refers to is not
found, an exception is thrown.

Returns: L<OpenInteract2::Action|OpenInteract2::Action> object

B<lookup_action_info( $action_name )>

Find the raw action information mapped to C<$action_name>. This is
used mostly for internal purposes.

This method follows 'redir' paths to their end. See
L<OpenInteract2::Action|OpenInteract2::Action> for more information
about these. If an action redirects to an action which is not found,
we still return undef.

This method will never throw any exceptions or errors.

Returns: hashref of action information, or undef if the action is not
defined.

B<action_table( [ \%action_table ] )>

Retrieves the action table, and sets it if passed in. The action table
is a hashref of hashrefs -- the keys are the names of the actions, the
values the information for the actions themselves.

When it gets passed in we do some work to find all the URLs each
action will respond to and save them elsewhere in the server
configuration.

Application developers will probably never use this.

Returns: hashref of action information

=head2 Object Methods: SPOPS

B<lookup_object( $object_name )>

Finds the SPOPS object class mapped to C<$object_name>. An exception
is thrown if C<$object_name> is not specified or not defined as an
SPOPS object.

Here are two different examples. The first uses a temporary variable
to hold the class name, the second does not.

 my $news_class = CTX->lookup_object( 'news' );
 my $newest_items = $news_class->fetch_group({ where => 'posted_on = ?',
                                               value => [ $now ] });
 
 my $older_items = CTX->lookup_object( 'news' )
                      ->fetch_group({ where => 'posted_on = ?',
                                      value => [ $then ] });

Returns: SPOPS class name; throws an exception if C<$object_name> is
not found.

=head2 Object Methods: Controller

B<lookup_controller( [ $controller_name ] )>

Returns a hashref of information about C<$controller_name>. If
C<$controller_name> not given returns a hashref with the controller
names as keys and the associated info as values. This is typically
just a class and content generator type, but we may add more...

=head2 Object Methods: Content Generator

B<lookup_content_generator( [ $generator_name ] )>

Returns a hashref of information about C<$generator_name>. If
C<$generator_name> not given returns a hashref with the generator
names as keys and the associated info as values. This is typically
just a class and method, but we may add more...

B<content_generator( $name )>

Returns information necessary to call the content generator named by
C<$name>. A 'content generator' is simply a class which can marry some
sort of template with some sort of data to produce content. The
generator that comes with OpenInteract is the Template Toolkit, but
there is no reason you cannot use another templating system or an
entirely different technology, like C<SOAP>.

Returns: a
L<OpenInteract2::ContentGenerator|OpenInteract2::ContentGenerator>
object. Generally you'd only call C<execute()> on it with the
appropriate parameters to get the generated content.

=head2 Object Methods: Attributes and Aliases

B<global_attribute( $name, [ $value ] )>

This is preliminary and may go away.

Get/set method for global attributes. Global attributes are a simple
way of passing temporary information to various routines or actions
without setting them in the server configuration.

These may get removed at the end of a request cycle or folded into
something else.

Returns: Current value for attribute C<$name>

B<alias( $type, $name, [ $value ] )>

Get/set method for aliases. Setting an alias also dynamically creates
a subroutine that returns C<$value>. Note that resetting the alias
after it has already been created will cause Perl to warn you about
redefining a subroutine.

Example:

Create an alias for 'argle_bargle', which returns a class name for the
'nonsense' object class:

 my $nonsense = fetch_nonsense({ where => 'speaker = "native"' });
 print "Nonsense: ", $nonsense->spew, "\n";
 my $nonsense_class = ref $nonsense;
 CTX->alias( 'object', 'argle_bargle', $nonsense_class );

 ... later ...

 print CTX->argle_bargle->fetch_nonsense()->spew;

The best strategy for setting aliases would probably be to create them
at server startup so they will always be available.

Returns: the currently set value for the alias C<$name>.

=head2 Object Methods: Deployment Context

There are three separate deployment contexts used in OpenInteract2:
the application context, image context and static context. These
control how OI2 parses incoming requests and the URLs it generates in
L<OpenInteract2::URL|OpenInteract2::URL>.

All deployment contexts are set from the server configuration file at
startup. You'll find the relevant configuration keys under
C<context_info>.

B<assign_deploy_url( $path )>

This is the primary application context, and the one you should be
most interested in. OI2 uses this value to define a URL-space which it
controls. Since OI2 controls the space it's free to parse incoming
URLs and assign resources to them, and to generate URLs and have them
map to known resources.

The default deployment context is '', or the root context. So the
following request:

 http://foo.com/User/show/

OI2 will try to find an action mapping to 'User' and assign the 'show'
task to it. Similarly when OI2 generates a URL it will not prepend any
URL-space to it.

However, if we set the context to C</OI2>, like:

 CTX->assign_deploy_url( '/OI2' )

then the following request:

 http://foo.com/User/show/

will B<not> be properly parsed by OI2. In fact OI2 won't be able to
find an action for the request and will map it to the 'none' action,
which is not what you want. Instead it will look for the following:

 http://foo.com/OI2/User/show/

And when it generates a URL, such as with:

 my $url = OpenInteract2::URL->create( '/User/show/', { user_id => 55 } );

It will create:

 /OI2/User/show/?user_id=55

Use the server configuration key C<context_info.deployed_under> to set
this.

Returns: new deployment URL.

B<assign_deploy_image_url( $path|$url )>

This serves the same purpose as the application deployment context in
generating URLs but has no effect on URL/request parsing. It's useful
if you have your images on a separate host, so you can do:

 CTX->assign_image_url( 'http://images.foo.com' );
 ...
 my $url = OpenInteract2::URL->create_image( '/images/photos/happy_baby.jpg' );

and generate the URL:

 http://images.foo.com/images/photos/happy_baby.jpg

Unlike C<assign_deploy_url> you can use a fully-qualified URL here.

Returns: new deployment URL for images.

B<assign_deploy_static_url( $path|$url )>

Exactly like C<assign_deploy_image_url>, except it's used for static
resources other than images.

Returns: new deployment URL for static resources.

=head2 Object Methods: Other Resources

B<datasource( [ $name ] )>

Returns the datasource mapped to C<$name>. If C<$name> is not
provided, the method looks up the default datasource in the server
configuration (under C<datasource_info.default_connection>) and uses
that.

Returns: the result of looking up the datasource using
L<OpenInteract2::DatasourceManager|OpenInteract2::DatasourceManager>

B<template( [ $template ] )>

Get/set method for the global template object.

XXX: we might modify this to keep multiple template objects and have
them be available by name. Then you could mix-and-match templates as
you wish, using L<Template|Template Toolkit> for most of your site but
L<HTML::Template|HTML::Template> for a self-contained piece of it.

Returns: Currently available template object

=head1 PROPERTIES

The following are simple get/set properties of the context object.

B<base_config>: Holds the
L<OpenInteract2::Config::Base|OpenInteract2::Config::Base> object. This
must be defined for the context to be initialized.

B<server_config>: Holds the
L<OpenInteract2::Config::IniFile|OpenInteract2::Config::IniFile> object
with the server configuration. This will be defined after the context
is initialized via C<setup()>.

B<repository>: Holds the
L<OpenInteract2::Repository|OpenInteract2::Repository> object with
methods for retrieving packages. This will be defined after the context
is initialized via C<setup()>.

B<packages>: Holds an arrayref of
L<OpenInteract2::Package|OpenInteract2::Package> objects. These will be
defined after the context is initialized via C<setup()>.

B<cache>: Holds an object whose parent is
L<OpenInteract2::Cache|OpenInteract2::Cache>. This allows you to store
and retrieve data rapidly. This will be defined (if configured) after
the context is initialized via C<setup()>.

=head1 BUGS

None known.

=head1 TO DO

=head1 SEE ALSO

L<OpenInteract2::Action|OpenInteract2::Action>

L<OpenInteract2::Config::Base|OpenInteract2::Config::Base>

L<OpenInteract2::Setup|OpenInteract2::Setup>

L<OpenInteract2::URL|OpenInteract2::URL>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
