package OpenInteract2::Action;

# $Id: Action.pm,v 1.39 2003/09/05 02:18:24 lachoy Exp $

use strict;
use base qw( Class::Accessor Class::Observable Class::Factory Exporter );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log :template );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_security_error );
use OpenInteract2::Util;
use Scalar::Util             qw( blessed );
use SPOPS::Secure            qw( :level );

$OpenInteract2::Action::VERSION  = sprintf("%d.%02d", q$Revision: 1.39 $ =~ /(\d+)\.(\d+)/);

use constant CACHE_CLASS_KEY => 'class_cache_track';

# TODO: Set default action security from server configuration?
# This is what we set the action security level to when the action is
# not secured.

use constant DEFAULT_ACTION_SECURITY => SEC_LEVEL_WRITE;

########################################
# ACCESSORS

# See 'PROPERTIES' section below for other properties used.

my %PROPS = map { $_ => 1 }
            qw(
                request response controller content_generator
                action_type class method message_name
                task task_default task_valid task_invalid
                security_level security_required security
                url_alt url_none
                template_source
                cache_expire cache_param
            );

__PACKAGE__->mk_accessors( keys %PROPS );

# Used to track classes, types, methods and security info

my %CLASSES_USED        = ();
my %ACTION_TASK_METHODS = ();
my %ACTION_SECURITY     = ();

# Class method, called when server starts up

sub init_at_startup { return; }

########################################
# CONSTRUCTOR

# XXX: Document/change REQUEST_URL

sub new {
    my ( $class, $item, $props ) = @_;
    $props ||= {};
    my ( $self );

    my $log = get_logger( LOG_ACTION );

    # Pass in another action...
    if ( blessed( $item ) ) {
        $log->is_debug &&
            $log->debug( "Creating new action from existing action ",
                         "named [", $item->name, "] [", ref $item, "]" );
        $self = bless( {}, ref( $item ) );
        $self->property_assign( $item->property );
        $self->param_assign( $item->param );
    }

    # ...or action info
    elsif ( ref $item eq 'HASH' ) {
        $log->is_debug &&
            $log->debug( "Creating new action from action info with name ",
                         "[$item->{name}]" );
        $self = $class->_create_from_config( $item, $props );
    }

    # ...or a name
    elsif ( $item ) {
        $log->is_debug &&
            $log->debug( "Creating new action from name [$item]" );

        # This will throw an error if the action cannot be found
        my $action_info = CTX->lookup_action_info( $item );
        $self = $class->_create_from_config( $action_info, $props );
    }

    # ...or nothing.
    # TODO: get rid of this? do we ever need to create an action without a name?
    else {
        $self = bless( {}, $class );
    }

    # ...pickup messages deposited in the request...
    my $action_msg_name = $self->message_name || $self->name;
    if ( CTX and $action_msg_name ) {
        my $request = CTX->request;
        if ( $request and my $messages = $request->action_messages( $action_msg_name ) ) {
            while ( my ( $msg_name, $msg ) = each %{ $messages } ) {
                $self->add_view_message( $msg_name => $msg );
            }
        }
    }

    # ...these will override any previous assignments
    $self->property_assign( $props );
    $self->param_assign( $props );

    return $self->init();
}

sub _create_from_config {
    my ( $class, $action_info, $props ) = @_;
    $props ||= {};
    my $name = lc $action_info->{name};
    my $impl_class = $action_info->{class};
    my $log = get_logger( LOG_ACTION );

    if ( $impl_class ) {
        unless ( $CLASSES_USED{ $impl_class } ) {
            eval "require $impl_class";
            if ( $@ ) {
                my $msg = "Cannot include library [$impl_class]: $@";
                $log->error( $msg );
                oi_error $msg;
            }
            $CLASSES_USED{ $impl_class }++;
        }
    }
    elsif ( my $action_type = $action_info->{action_type} ) {
        $impl_class = $class->get_factory_class( $action_type );
        $log->debug &&
            $log->debug( "Got class [$impl_class] from action ",
                         "type [$action_type]" );
    }
    unless ( $impl_class ) {
        $log->error( "Implementation class not found for action ",
                     "[$name] [class: $action_info->{class}] ",
                     "[type: $action_info->{action_type}]" );
        oi_error "Action configuration for $name has no 'class' ",
                 "or 'action_type' defined";
    }
    my ( $self );
    $self = bless( {}, $impl_class );

    $self->_set_name( $name );
    my $url = $props->{REQUEST_URL}
# TODO: See if we can use 'url_primary' at this point...
#              || $action_info->{url_primary}
              || $action_info->{url}
              || $action_info->{name};
    $self->_set_url( $url );
    $self->property_assign( $action_info );
    $self->param_assign( $action_info );
    return $self;
}


sub init { return $_[0] }

########################################
# RUN

sub execute {
    my ( $self, $params ) = @_;
    my $log = get_logger( LOG_ACTION );

    $params ||= {};

    # All properties and parameters passed in become part of the
    # action itself

    $self->property_assign( $params );
    $self->param_assign( $params );

    # Ensure we have a task, that it is valid and that this user has
    # the security clearance to run it. Each of these find/check
    # methods will throw an exception if the action does not pass

    unless ( $self->task ) {
        $self->task( $self->_find_task );
    }

    # These checks will die if they fail -- let the error bubble up

    $self->_check_task_validity;
    $log->is_debug &&
        $log->debug( "Task is valid, continuing" );

    $self->_check_security;
    $log->is_debug &&
        $log->debug( "Task security checked, continuing" );

    # Check cache and return if found
    my $cached_content = $self->_check_cache;
    if ( $cached_content ) { return $cached_content }
    $log->is_debug &&
        $log->debug( "Cached data not found, continuing" );

    my $method_ref = $self->_find_task_method;
    $log->is_debug &&
        $log->debug( "Found task method ok, running" );

    my $content = eval { $self->$method_ref };
    if ( $@ ) {
        $log->warn( "Caught error from task: $@" );
        $content = $@;
    }
    else {
        $log->is_debug &&
            $log->debug( "Task executed ok, excuting filters" );
        $self->notify_observers( 'filter', \$content );

        $log->is_debug &&
            $log->debug( "Filters ran ok, saving to cache" );
        if ( my $cache_expire = $self->_is_using_cache ) {
            $self->_set_cached_content( $content, $cache_expire );
        }
    }
    return $content;
}


sub forward {
    my ( $self, $new_action ) = @_;

    # TODO: If we standardize on copying 'core' properties
    # from one action to another, add it here

    return $new_action->execute;
}

########################################
# TASK

sub _find_task {
    my ( $self ) = @_;

    # NOTE: a defined 'method' in the action will ALWAYS override a
    # task

    if ( my $method = $self->method ) {
        return $self->task( $method );
    }
    if ( $self->task ) {
        return $self->task;
    }

    my $default_task = $self->task_default;
    if ( $default_task ) {
        return $self->task( $default_task );
    }
    oi_error "Cannot find task to execute for [", $self->name, "]";
}


# Ensure that the task assigned is valid: if not throw an
# exception. There must be a task defined by this point.

sub _check_task_validity {
    my ( $self ) = @_;
    my $check_task = lc $self->task;
    my $log = get_logger( LOG_ACTION );

    unless ( $check_task ) {
        my $msg = "No task defined, cannot check validity";
        $log->error( $msg );
        oi_error $msg;
    }
    if ( $check_task =~ /^_/ ) {
        $log->error( "Task $check_task invalid, cannot begin with ",
                     "underscore" );
        oi_error "Tasks may not begin with an underscore";
    }

    # See if task has been specified in valid/invalid list

    my $is_invalid = grep { $check_task eq $_ } @{ $self->task_invalid || [] };
    if ( $is_invalid ) {
        $log->error( "Task $check_task explicitly forbidden in config" );
        oi_error "Task is forbidden";
    }
    my $task_valid = $self->task_valid || [];
    if ( scalar @{ $task_valid } ) {
        unless ( grep { $check_task eq $_ } @{ $task_valid } ) {
            $log->error( "Valid tasks enumerated and $check_task not member" );
            oi_error "Task is not specified in action property 'task_valid'";
        }
    }
}


# See if 'handler()' exists in the class (or parent class) we're
# calling and return that coderef; otherwise if the task method
# actually exists return that coderef. If not, throw an exception.

sub _find_task_method {
    my ( $self ) = @_;
    my $task = $self->task;
    my $log = get_logger( LOG_ACTION );

    if ( my $method = $ACTION_TASK_METHODS{ $self->name }->{ $task } ) {
        $log->is_debug &&
            $log->debug( "Cached method found for task $task" );
        return $method
    }

    foreach my $method_try ( ( 'handler', $task ) ) {
        if ( $PROPS{ $method_try } ) {
            $log->error( "PLEASE NOTE: You tried to execute the action task ",
                         "[$task] but this is one of the action properties. ",
                         "No content will be returned for this task." );
            next;
        }
        if ( my $method = $self->can( $method_try ) ) {
            $ACTION_TASK_METHODS{ $self->name }->{ $task } = $method;
            $log->is_debug &&
                $log->debug( "Stored method in cache for task $task" );
            return $method;
        }
    }
    $log->error( "Cannot find method for task $task" );
    oi_error "Cannot find valid method in [", ref( $self ), "] for task [$task]";
}


########################################
# SECURITY

sub _check_security {
    my ( $self ) = @_;
    my $log = get_logger( LOG_ACTION );

    unless ( $self->security_level ) {
        $self->security_level( $self->_find_security_level );
    }

    return $self->security_level unless ( $self->is_secure );

    my $action_security = $self->security;
    unless ( ref $action_security eq 'HASH' ) {
        $log->error( "Secure action, no security configuration" );
        oi_error "Configuration error: action is secured but no ",
                 "security requirements configured";
    }

    my $task  = $self->task;
    my $required_level = $action_security->{ $task } ||
                         $action_security->{DEFAULT} ||
                         $action_security->{default};


    unless ( defined $required_level ) {
        $log->is_info &&
            $log->info( "Assigned security level WRITE to task ",
                        "[$task] since security requirement not found" );
        $required_level = SEC_LEVEL_WRITE;
    }

    $self->security_required( $required_level );

    my $action_level = $self->security_level;
    if ( $required_level > $action_level ) {
        my $msg = join( '', "Security check for [", $self->name, "] ",
                            "[$task] failed" );
        $log->error( "$msg [required: $required_level] ",
                     "[found: $action_level]" );
        oi_security_error $msg,
                          { security_required => $required_level,
                            security_found    => $action_level };
    }
    return $self->security_level;
}

# Find the level for this user/group and this action

sub _find_security_level {
    my ( $self ) = @_;
    my $log = get_logger( LOG_ACTION );

    unless ( $self->is_secure ) {
        $log->is_debug &&
            $log->debug( "Action ", $self->name, " not secured, ",
                         "assigning default level." );
        return DEFAULT_ACTION_SECURITY;
    }

    # TODO: Dependency on object_id '0' sucks

    my $found_level = eval {
        CTX->check_security({ class     => ref $self,
                              object_id => '0' })
    };
    if ( $@ ) {
        $log->error( "Error in check_security: $@" );
        oi_error "Cannot lookup authorization for action: $@";
    }
    $log->is_debug &&
        $log->debug( "Found security level $found_level" );
    return $found_level;
}



########################################
# GENERATE CONTENT

sub generate_content {
    my ( $self, $content_params, $source, $template_params ) = @_;
    my $log = get_logger( LOG_ACTION );

    $log->is_debug &&
        $log->debug( "Generating content for [", $self->name, "]" );

    $content_params->{ACTION} = $self;
    $content_params->{action_messages} = $self->view_messages;

    # If source wasn't specified see if it's found in
    # 'template_source'

    unless ( $source ) {
        my $task = $self->task;
        if ( my $source_info = $self->template_source ) {
            unless ( ref $source_info eq 'HASH' ) {
                my $msg = "No template source specified in config, " .
                          "no source returned for task '$task'";
                $log->error( $msg );
                oi_error $msg;
            }
            my $task_template_source = $source_info->{ $task };
            unless ( $task_template_source ) {
                my $msg = "No template source in config for task '$task'";
                $log->error( $msg );
                oi_error $msg;
            }
            $log->is_debug &&
                $log->debug( "Found template source from action ",
                             "[$task_template_source] config" );
            $source = { name => $task_template_source };
        }
        else {
            my $msg = "No template source specified in config, " .
                      "no source returned for task '$task'";
            $log->error( $msg );
            oi_error $msg;
        }
    }

    my $generator = CTX->content_generator( $self->content_generator );
    my $content = $generator->execute( $template_params,
                                       $content_params,
                                       $source );

    return $content;
}


########################################
# CACHING

# Subclasses override

sub initialize_cache_params { return undef }

# Since we can't be sure what's affected by a change that would prompt
# this call, just clear out all cache entries for this action. (For
# instance, if a news object is removed we don't want to keep
# displaying the old copy in the listing.)

sub clear_cache {
    my ( $self  ) = @_;
    my $log = get_logger( LOG_ACTION );

    my $cache = CTX->cache;
    return unless ( $cache );

    my $class = ref( $self );
    $log->is_info &&
        $log->info( "Trying to clear cache for items in class [$class]" );
    my $tracking = $cache->get({ key => CACHE_CLASS_KEY });
    unless ( ref $tracking eq 'HASH' and scalar keys %{ $tracking } ) {
        $log->is_info &&
            $log->info( "Nothing yet tracked, nothing to clear" );
        return;
    }

    my $num_cleared = 0;
    my $keys = $tracking->{ $class } || [];
    foreach my $cache_key ( @{ $keys } ) {
        $log->is_debug &&
            $log->debug( "Clearing key [$cache_key]" );
        $cache->clear({ key => $cache_key });
        $num_cleared++;
    }
    $tracking->{ $class } = [];
    $cache->set({ key  => CACHE_CLASS_KEY,
                  data => $tracking });
    $log->is_debug &&
        $log->debug( "Tracking data saved back" );
    $log->is_info &&
        $log->info( "Finished clearing cache for [$class]" );
    return $num_cleared;
}


sub _is_using_cache {
    my ( $self ) = @_;
    my $expire = $self->cache_expire;
    return ( $expire ) ? $expire->{ $self->task } : undef;
}


sub _check_cache {
    my ( $self ) = @_;
    return undef unless ( $self->_is_using_cache );   # ...not using cache
    return undef if ( CTX->request->auth_is_admin );  # ...is admin
    my $cache = CTX->cache;
    return undef unless ( $cache );                   # ...no cache available
    my $cache_key = $self->_create_cache_key;
    return undef unless ( $cache_key );               # ...no cache key
    return $cache->get({ key => $cache_key });
}


sub _create_cache_key {
    my ( $self ) = @_;
    my $key = join( '-', ref( $self ), $self->task );
    my $cache_param = $self->_cache_param_by_task;
    unless ( scalar @{ $cache_param } > 0 ) {
        return $key;
    }

    my $set_cache_params = $self->initialize_cache_params;
    my $request = CTX->request;

    foreach my $param_name ( @{ $cache_param } ) {
        my $value = $set_cache_params->{ $param_name }
                    || $self->param( $param_name )
                    || $request->param( $param_name )
                    || $self->_get_cache_default_param( $param_name );
        $key .= ";$param_name=$value";
    }
    return $key;
}

my %CACHE_PARAM_DEFAULTS = map { $_ => 1 } qw( user_id theme_id );

sub _get_cache_default_param {
    my ( $self, $param_name ) = @_;
    return undef unless ( $CACHE_PARAM_DEFAULTS{ $param_name } );
    my $request = CTX->request;
    if ( $param_name eq 'user_id' ) {
        return $request->auth_user->id;
    }
    elsif ( $param_name eq 'theme_id' ) {
        return $request->theme->id;
    }
}

sub _set_cached_content {
    my ( $self, $content, $expiration ) = @_;
    my $log = get_logger( LOG_ACTION );

    my $cache = CTX->cache;
    return unless ( $cache );

    my $key = $self->_create_cache_key();
    $cache->set({ key    => $key,
                  data   => $content,
                  expire => $expiration });

    # Now set the tracking data so we can expire when needed

    my $tracking = $cache->get({ key => CACHE_CLASS_KEY }) || {};
    my $class = ref( $self );
    push @{ $tracking->{ $class } }, $key;
    $log->is_debug &&
        $log->debug( "Adding cache key [$key] to class [$class]" );
    $cache->set({ key  => CACHE_CLASS_KEY,
                  data => $tracking });
}

# ALWAYS return an arrayref, even if it's empty; order is ensured at
# startup (see OI2::Setup::_assign_action_info)

sub _cache_param_by_task {
    my ( $self ) = @_;
    my $task = $self->task;
    return [] unless ( $task );
    my $params = $self->cache_param;
    return [] unless ( ref $params eq 'HASH' );
    return $params->{ $task };
}


########################################
# PROPERTIES

# The 'name' and 'url' properties should not be set by the client,
# only by the constructor; they are read-only -- any parameters passed
# will be ignored.

sub name {
    my ( $self ) = @_;
    return $self->{name};
}

sub _set_name {
    my ( $self, $name ) = @_;
    $self->{name} = $name  if ( $name );
    return $self->{name};
}

sub url {
    my ( $self ) = @_;
    return $self->{url};
}

sub _set_url {
    my ( $self, $url ) = @_;
    $self->{url} = $url  if ( $url );
    return $self->{url};
}

sub is_secure {
    my ( $self, $setting ) = @_;
    if ( $setting ) {
        $setting = 'no' unless ( $setting eq 'yes' );
        $self->{is_secure} = $setting;
    }
    return ( $self->{is_secure} eq 'yes' ) ? 1 : 0;
}

# Assign the object properties from the params passed in; the rest of
# the parameters are instance parameters that we won't know in
# advance, accessible via param()

sub property_assign {
    my ( $self, $props ) = @_;
    while ( my ( $field, $value ) = each %{ $props } ) {
        if ( $field eq 'is_secure' ) {
            $self->is_secure( $value );
        }
        next unless ( $PROPS{ $field } );
        next unless ( defined $value ); # TODO: Set empty values?
        if ( $field eq 'cache_expire' ) {
            $self->_property_assign_cache( $value );
        }
        else {
            $self->$field( $value );
        }
    }
    return $self;
}


# Just ensure that every value is a number

sub _property_assign_cache {
    my ( $self, $cache ) = @_;
    $cache ||= {};
    foreach my $task ( keys %{ $cache } ) {
        $cache->{ $task } = int( $cache->{ $task } );
    }
    $self->cache_expire( $cache );
}

# Do a generic set if property and value given; return a hashref of
# all properties

sub property {
    my ( $self, $prop, $value ) = @_;
    if ( $prop and $PROPS{ $prop } ) {
        $self->{ $prop } = $value if ( $value );
        return $self->{ $prop };
    }
    return { map { $_ => $self->{ $_ } } keys %PROPS };
}


# Clear out a property (since passing undef for a set won't work)

sub property_clear {
    my ( $self, $prop ) = @_;
    return delete $self->{ $prop };
}

########################################
# PARAMS

sub param_assign {
    my ( $self, $params ) = @_;
    return unless ( ref $params eq 'HASH' );
    while ( my ( $key, $value ) = each %{ $params } ) {
        next if ( $PROPS{ $key } );
        next unless ( defined $value ); # TODO: Set empty values?
        $self->param( $key, $value );
    }
    return $self;
}


sub param {
    my ( $self, $key, $value ) = @_;
    return \%{ $self->{params} } unless ( $key );
    if ( defined $value ) {
        $self->{params}{ $key } = $value;
    }
    if ( ref $self->{params}{ $key } eq 'ARRAY' ) {
        return ( wantarray )
                 ? @{ $self->{params}{ $key } }
                 : $self->{params}{ $key };
    }
    return ( wantarray )
             ? ( $self->{params}{ $key } )
             : $self->{params}{ $key };
}

sub param_add {
    my ( $self, $key, @values ) = @_;
    return undef unless ( $key );
    my $num_values = scalar @values;
    return $self->{params}{ $key } unless ( scalar @values );
    if ( my $existing = $self->{params}{ $key } ) {
        my $typeof = ref( $existing );
        if ( $typeof eq 'ARRAY' ) {
            push @{ $self->{params}{ $key } }, @values;
        }
        elsif ( ! $typeof ) {
            $self->{params}{ $key } = [ $existing, @values ];
        }
        else {
            oi_error "Cannot add $num_values values to parameter [$key] ",
                     "since the parameter is defined as a [$typeof] to ",
                     "which I cannot reliably add values.";
        }
    }
    else {
        if ( $num_values == 1 ) {
            $self->{params}{ $key } = $values[0];
        }
        else {
            $self->{params}{ $key } = [ @values ];
        }
    }
    return $self->param( $key );
}

sub param_clear {
    my ( $self, $key ) = @_;
    return delete $self->{params}{ $key };
}

sub param_from_request {
    my ( $self, @params ) = @_;
    my $req = CTX->request;
    for ( @params ) {
        $self->{params}{ $_ } = $req->param( $_ );
    }
}

sub view_messages {
    my ( $self, $messages ) = @_;
    if ( ref $messages eq 'HASH' ) {
        $self->{_view_msg} = $messages
    }
    $self->{_view_msg} ||= {};
    return $self->{_view_msg};
}

sub add_view_message {
    my ( $self, $msg_name, $msg ) = @_;
    return $self->{_view_msg}{ $msg_name } = $msg;
}

########################################
# URL

sub create_url {
    my ( $self, $params ) = @_;

    # We may want to pass an empty TASK on purpose, so don't just
    # check to see if TASK exists...

    my $task = ( exists $params->{TASK} )
                 ? $params->{TASK} : $self->task;
    delete $params->{TASK};
    return OpenInteract2::URL->create_from_action(
                         $self->name, $task, $params );
}


# NOTE: DO NOT CHANGE THE ORDER OF PROCESSING HERE WITHOUT CHANGING
# DOCS IN 'MAPPING URL TO ACTION'. This includes checking 'url' first
# and the order of the default urls generates (lc, uc, ucfirst)

sub get_dispatch_urls {
    my ( $self ) = @_;
    my $log = get_logger( LOG_ACTION );

    $log->is_debug &&
        $log->debug( "Find dispatch URLs for [", $self->name, "]" );
    my $no_urls = $self->url_none;
    if ( defined $no_urls and $no_urls =~ /^\s*(yes|true)\s*$/ ) {
        $log->is_debug && $log->debug( "...has no URL" );
        return [];
    }
    my @urls = ();
    if ( $self->url ) {
        push @urls, $self->url;
        $log->is_debug &&
            $log->debug( "...has spec URL [", $self->url, "]" );
    }
    else {
        push @urls, lc $self->name,
                    uc $self->name,
                    ucfirst lc $self->name;
        $log->is_debug &&
            $log->debug( "...has named URLs [", join( '] [', @urls ), ']' );
    }
    if ( $self->url_alt ) {
        my @alternates = ( ref $self->url_alt eq 'ARRAY' )
                           ? @{ $self->url_alt }
                           : ( $self->url_alt );
        push @urls, @alternates;
        $log->is_debug &&
            $log->debug( "...has alt URLs [", join( '] [', @alternates ), ']' );
    }
    return \@urls;
}

# Cleanup after ourselves
sub DESTROY {
    my ( $self ) = @_;
    $self->delete_observers;
}

########################################
# SHORTCUTS

sub context  {
    die 'HEY! Change $action->context call at ', join( ' / ', caller );
}

########################################
# FACTORY

sub factory_log {
    my ( $self, @msg ) = @_;
    get_logger( LOG_ACTION )->info( @msg );
}

sub factory_error {
    my ( $self, @msg ) = @_;
    get_logger( LOG_ACTION )->error( @msg );
    die @msg, "\n";
}

1;

__END__

=head1 NAME

OpenInteract2::Action - Represent and dispatch actions

=head1 SYNOPSIS

 # Define an action in configuration to have its content generated by
 # the TT generator (Template Toolkit) and security
 # checked. (Previously you had to subclass SPOPS::Secure.)
 
 [news]
 class             = OpenInteract2::Action::News
 is_secure         = yes
 content_generator = TT
 
 # The tasks 'listing' and 'latest' can be cached, for 600 and 300
 # seconds respectively.
 
 [news cache_expire]
 listing           = 600
 latest            = 300
 
 # Cached content depends on these parameters (multiple ok)
 
 [news cache_param]
 listing           = num_items
 listing           = language
 latest            = num_items
 
 # You can declare security levels in the action configuration, or you
 # can override the method _find_security_level()
 
 [news security]
 default           = write
 show              = read
 listing           = read
 latest            = read
 
 # Same handler class, but mapped to a different action and with an
 # extra parameter, and the 'edit' and 'remove' tasks are marked as
 # invalid.
 
 [newsuk]
 class             = OpenInteract2::Action::News
 is_secure         = no
 news_from         = uk
 content_generator = TT
 task_invalid      = edit
 task_invalid      = remove
 
 [newsuk cache_expire]
 listing           = 600
 latest            = 600
 
 # Future: Use the same code to generate a SOAP response; at server
 # startup this should setup SOAP::Lite to respond to a request at
 # the URL '/SoapNews'.
 
 [news_rpc]
 class             = OpenInteract2::Action::News
 is_secure         = yes
 content_generator = SOAP
 url               = SoapNews
 
 [news_rpc cache_expire]
 listing           = 600
 latest            = 300
 
 [news_rpc security]
 default           = write
 show              = read
 
 # Dispatch a request to the action by looking up the action in the
 # OpenInteract2::Context object:
 
 # ...using the default task
 my $action = CTX->lookup_action( 'news' );
 return $action->execute;
 
 # ...specifying a task
 my $action = CTX->lookup_action( 'news' );
 $action->task( 'show' );
 return $action->execute;
 
 # ...specifying a task and passing parameters
 my $action = CTX->lookup_action( 'news' );
 $action->task( 'show' );
 $action->param( news => $news );
 $action->param( grafs => 3 );
 return $action->execute;
 
 # Dispatch a request to the action by manually creating an action
 # object
 
 # ...using the default task
 my $action = OpenInteract2::Action->new( 'news' );
 
 # ...specifying a task
 my $action = OpenInteract2::Action->new( 'news', { task => 'show' } );
 
 # ...specifying a task and passing parameters
 my $action = OpenInteract2::Action->new( 'news',
                                         { task  => 'show',
                                           news  => $news,
                                           grafs => 3 } );
 
 # Set parameters after the action has been created
 $action->param( news  => $news );
 $action->param( grafs => 3 );
 
 # Run the action and return the content
 return $action->execute;

 # IN AN ACTION
 
 sub change_some_object {
     my ( $self ) = @_;
     # ... do the changes ...
 
     # Clear out cache entries for this action so we don't have stale
     # content being served up
 
     $self->clear_cache;
 }

=head1 DESCRIPTION

The Action object is a core piece of the OpenInteract framework. Every
component in the system and part of an application is represented by
an action. An action always returns content from its primary
interface, the C<execute()> method. This content can be built by the
action directly, constructed by passing parameters to a content
generator, or passed off to another action for generation. (See
L<GENERATING CONTENT FOR ACTION> below.)

=head2 Action Class Initialization

When OpenInteract starts up it will call C<init_at_startup()> on every
configured action class. This is useful for reading static (or rarely
changing) information once and caching the results. Since the
L<OpenInteract2::Context|OpenInteract2::Context> object is guaranteed
to have been created when this is called you can grab a database
handle and slurp all the lookup entries from a table into a lexical
data structure.

Here's an example:

 use Log::Log4perl            qw( get_logger );
 use OpenInteract2::Context   qw( CTX );
 
 # Publishers don't change very often, so keep them local so we don't
 # have to fetch every time
 
 my %publishers = ();
 
 ...
 
 sub init_at_startup {
     my ( $class ) = @_;
     my $log = get_logger( LOG_APP );
     my $publisher_list = eval {
         CTX->lookup_object( 'publisher' )->fetch_group()
     };
     if ( $@ ) {
         $log->error( "Failed to fetch publishers at startup: $@" );
     }
     else {
         foreach my $publisher ( @{ $publisher_list } ) {
             $publishers{ $publisher->name } = $publisher;
         }
     }
 }

=head2 Action Tasks

Each action can be viewed as an associated collection of
tasks. Generally, each task maps to a subroutine in the package of the
action. For instance, the following package defines three tasks that
all operate on 'news' objects:

 package My::News;
 
 use strict;
 use base qw( OpenInteract2::Action );
 
 sub latest  { return "Lots of news in the last week" }
 sub display { return "This is the display task!" }
 sub add     { return "Adding..." }
 
 1;

Here is how you would call them, assuming that this action is mapped
to the 'news' key:

 my $action = CTX->lookup_action( 'news' );
 $action->task( 'latest' );
 print $action->execute;
 # Lots of news in the last week
 
 $action->task( 'display' );
 print $action->execute;
 # This is the display task!
 
 $action->task( 'add' );
 print $action->execute;
 # Adding...

You can also create your own dispatcher by defining the method
'handler' in your action class. For instance:

TODO: This won't work, will it? Won't we just keep calling 'handler'
again and again?

 package My::News;
 
 use strict;
 use base qw( OpenInteract2::Action );
 
 sub handler {
     my ( $self ) = @_;
     my $task = $self->task;
     my $language = CTX->user->language;
     my ( $new_task );
     if ( $task eq 'list' and $language eq 'es' ) {
         $new_task = 'list_spanish';
     }
     elsif ( $task eq 'list' and $language eq 'ru' ) {
         $new_task = 'list_russian';
     }
     elsif ( $task eq 'list' ) {
         $new_task = 'list_english';
     }
     else {
         $new_task = $task;
     }
     return $self->execute({ task => $new_task });
 }
 
 sub list_spanish { return "Lots of spanish news in the last week" }
 sub list_russian { return "Lots of russian news in the last week" }
 sub list_english { return "Lots of english news in the last week" }
 sub show { return "This is the show task!" }
 sub edit { return "Editing..." }
 
 1;

You have control over whether a subroutine in your action class is
exposed as a task. The following tasks will never be run:

=over 4

=item *

Tasks beginning with an underscore.

=item *

Tasks listed in the C<task_invalid> property.

=back

Additionally, if you have defined the C<task_valid> property then only
those tasks will be valid. All others will be forbidden.

To use our example above, assume we have configured the action with
the following:

 [news]
 class        = OpenInteract2::Action::News
 task_valid   = latest
 task_valid   = display

Then the 'add' task will not be valid. You could also explicitly
forbid the 'add' task from being executed with:

 [news]
 class        = OpenInteract2::Action::News
 task_invalid = add

See discussion of C<_find_task()> and C<_check_task_validity()> for more
information.

=head2 Action Types

An action type implements one or more public methods in a sufficiently
generic fashion as to be applicable to different applications. Actions
implemented using action types normally do not need any code: the
action type relies on configuration information and/or parameters to
perform its functions.

To use an action type, you just need to specify it in your
configuration:

 [foo]
 action_type  = lookup
 ...

Each action type has configuration entries it uses. Here's what the
full declaration for a lookup action might be:

 [foo]
 action_type  = lookup
 object_key   = foo
 title        = Foo Listing
 field_list   = foo
 field_list   = bar
 label_list   = A Foo
 label_list   = A Bar
 size_list    = 25
 size_list    = 10
 order        = foo
 url_none     = yes

Action types are declared in the server configuration under the
'action_types' key. OI2 ships with:

 [action_types]
 template_only = OpenInteract2::Action::TemplateOnly
 lookup        = OpenInteract2::Action::LookupEdit

If you'd like to add your own type you just need to add the name and
class to the list. It will be picked up at the next server start. You
can also add them programmatically using C<register_factory_type()>
(inherited from L<Class::Factory|Class::Factory>):

 OpenInteract2::Action->register_factory_type( mytype => 'My::Action::Type' );

=head2 Action Properties vs. Parameters

B<Action Properties> are found in every action. These represent
standard information about the action: name, task, security
information, etc. All properties are described in L<PROPERTIES>.

B<Action Parameters> are extra information attached to the
action. These are analogous in OpenInteract 1.x to the hashref passed
into a handler as the second argument. For instance:

 # OpenInteract 1.x
 
 return $class->show({ object     => $foo,
                       error_msg  => $error_msg,
                       status_msg => $status_msg });
 
 sub show {
     my ( $class, $params ) = @_;
     if ( $params->{error_msg} ) {
         return $R->template->handler( {}, $params,
                                       { name => 'mypkg::error_page' } );
     }
 }

 # OpenInteract 2.x
 
 $action->task( 'show' );
 $action->param( object => $foo );
 $action->param_add( error_msg => $error_msg );
 $action->param_add( status_msg => $status_msg );
 return $action->execute;
 
 # also: assign parameters in one call
 
 $action->task( 'show' );
 $action->param_assign({ object     => $foo,
                         error_msg  => $error_msg,
                         status_msg => $status_msg });
 return $action->execute;
 
 # also: pass parameters in last statement
 
 $action->task( 'show' );
 return $action->execute({ object     => $foo,
                           error_msg  => $error_msg,
                           status_msg => $status_msg });
 
 # also: pass parameters plus a property in last statement
 
 return $action->execute({ object     => $foo,
                           error_msg  => $error_msg,
                           status_msg => $status_msg,
                           task       => 'show' });
 
 sub show {
     my ( $self ) = @_;
     if ( $self->param( 'error_msg' ) ) {
         return $self->generate_content(
                              {}, { name => 'mypkg::error_page' } );
     }
 }

=head1 OBSERVABLE ACTIONS

=head2 What does it mean?

All actions are B<observable>. This means that any number of classes,
objects or subroutines can register themselves with a type of action
and be activated when that action publishes a notification. It's a
great way to decouple an object from other functions that want to
operate on that object's results. The observed object (in this case,
the action) doesn't know how many observers there are, or even if any
exist at all.

=head2 Observable Scenario

That is all very abstract, so here is a scenario:

B<Existing action>: Register a new user

B<Notification published>: When new user confirms registration.

B<Desired outcome>: Add the user name and email address to various
services within the website network. This is done via an asynchronous
message published to each site in the network. The network names are
stored in a server configuration variable 'network_queue_server'.

How to implement:

 package OpenInteract2::NewUserPublish;
 
 use strict;
 
 sub update {
     my ( $class, $action, $notify_type ) = @_;
     if ( $notify_type eq 'register-confirm' ) {
         my $user = $action->param( 'user' );
         my $network_servers = CTX->server_config->{network_queue_server};
         foreach my $server_name ( @{ $network_servers } ) {
             my $server = CTX->queue_connect( $server_name );
             $server->publish( 'new_user', $user );
         }
     }
 }
 
 OpenInteract2::Action::NewUser->add_observer( __PACKAGE__ );

And the action would notify all observers like this:

 package OpenInteract2::Action::NewUser;
 
 # ... other methods here ...
 
 sub confirm_registration {
     my ( $self ) = @_;
     # ... check registration ...
     if ( $registration_ok ) {
         $self->notify_observers( 'register-confirm' );
         return $self->generate_content(
                        {}, { name => 'base_user::newuser_confirm_ok' } );
     }
 }

And in the documentation for the package 'base_user' (since this
action lives there), you would have information about what
notifications are published by the C<OpenInteract2::Action::NewUser>
action.

=head2 Built-in Observations

B<filter>

Filters can register themselves as observers and get passed a
reference to content. A filter can transform the content in any manner
it requires. The observation is posted just before the content is
cached, so if the action's content is cacheable any modifications will
become part of the cache.

Here's an example:

 package OpenInteract2::WikiFilter;
 
 use strict;
 
 sub update {
     my ( $class, $action, $type, $content ) = @_;
     return unless ( $type eq 'filter' );
 
     # Note: $content is a scalar REFERENCE
 
     $class->_transform_wiki_words( $content );
 }

You can register filters via the server-wide C<conf/filter.ini>
file. Here's how you'd register the above filter to work on the 'news'
and 'page' actions.

 [filters wiki]
 class = OpenInteract2::WikiFilter
 
 [filter_action]
 news  = wiki
 page  = wiki

The general configuration to declare a filter is:

 [filters filtername]
 observation-type = value

The observation types are 'class', 'object' and 'sub' (see
L<Class::Observable|Class::Observable> for what these mean and how
they're setup), so you could have:

 [filters foo_obj]
 object = OpenInteract2::FooFilter
 
 [filters foo_sub]
 sub    = OpenInteract2::FooFilter::other_sub
 
 [filter_action]
 news   = foo_obj
 page   = foo_sub

Most of the time you'll likely use 'class' since it's the easiest.

See L<OpenInteract2::Filter|OpenInteract2::Filter> for more
information.

=head1 MAPPING URL TO ACTION

In OI 1.x the name of an action determined what URL it responded
to. This was simple but inflexible. OI 2.x gives you the option of
decoupling the name and URL and allowing each action to respond to
multiple URLs as well.

The default behavior is to respond to URLs generated from the action
name. Unlike OI 1.x it is not strictly case-insensitive. It will
respond to URLs formed from:

=over 4

=item *

Lowercasing the action name

=item *

Uppercasing the action name

=item *

Uppercasing the first letter of the action name, lowercasing the rest.

=back

For example, this action:

 [news]
 class = MyPackage::Action::News

will respond to the following URLs:

 /news/
 /NEWS/
 /News/

This default behavior can be modified and/or replaced by three
properties:

=over 4

=item *

B<url>: Specify a single URL to which this action will respond. This
B<replaces> the default behavior.

=item *

B<url_none>: Tell OI that this action B<cannot> be accessed via URL,
appropriate for box or other template-only actions. This B<replaces>
the default behavior.

=item *

B<url_alt>: Specify a number of additional URLs to which this action
will respond. This B<adds to> the default behavior, and may also be
used in conjunction with B<url> (but not B<url_none>).

=back

Here are some examples to illustrate:

Use 'url' by itself:

 [news]
 class = MyPackage::Action::News
 url   = News

Responds to:

 /News/

Use 'url' with 'url_alt':

 [news]
 class   = MyPackage::Action::News
 url     = News
 url_alt = Nouvelles
 url_alt = Noticias

Responds to:

 /News/
 /Nouvelles/
 /Noticias/

Use default behavior with 'url_alt':

 [news]
 class   = MyPackage::Action::News
 url_alt = Nouvelles
 url_alt = Noticias

Responds to:

 /news/
 /NEWS/
 /News/
 /Nouvelles/
 /Noticias/

Use 'url_none':

 [news_box]
 class    = MyPackage::Action::News
 method   = box
 url_none = yes

Responds to: nothing

Use 'url_none' with 'url_alt':

 [news_box]
 class    = MyPackage::Action::News
 method   = box
 url_none = yes
 url_alt  = NoticiasBox

Responds to: nothing

The actual mapping of URL to Action is done in the
L<OpenInteract2::Context|OpenInteract2::Context> method
C<action_table()>. Whenever the action table is assigned to the
context is iterates through the actions, asks each one which URLs it
responds to and creates a mapping so the URL can be quickly looked up.

One other thing to note about that context method: it also embeds the
B<primary> URL for each action in the information stored in the action
table. Since the information is stored in a key that's not a property
or parameter the action itself doesn't care about this. But it's
useful to note because when you generate URLs based on an action the
B<first> URL is used, as discussed in the examples above.

So, to repeat the examples above, when you have:

 [news]
 class = MyPackage::Action::News
 url   = News

The first URL will be:

 /News/

When you have:

 [news]
 class   = MyPackage::Action::News
 url     = News
 url_alt = Nouvelles
 url_alt = Noticias

The first URL will still be:

 /News/

When you have:

 [news]
 class   = MyPackage::Action::News
 url_alt = Nouvelles
 url_alt = Noticias

The first URL will be:

 /news/

because the default always puts the lowercased entry first.

=head1 GENERATING CONTENT FOR ACTION

Actions B<always> return content. That content might be what's
expected, it might be an error message, or it might be the result of
another action. Normally the content is generated by passing data to
some sort of template processor along with the template to use. The
template processor passes the data to the template and returns the
result. But there's nothing that says you can't just manually return a
string :-)

The template processor is known as a 'content generator', since it
does not need to use templates at all. OpenInteract maintains a list
of content generators, each of which has a class and method associated
with it. (You can grab a content generator from the
L<OpenInteract2::Context|OpenInteract2::Context> object using
C<get_content_generator()>.)

Generally, your handler can just call C<generate_content()>:

 sub show {
     my ( $self ) = @_;
     my $request = $self->request;
     my $news_id = $request->param( 'news_id' );
     my $news_class = CTX->lookup_object( 'news' );
     my $news = $news_class->fetch( $news_id )
                || $news_class->new();
     my %params = ( news => $news );
     return $self->generate_content(
                         \%params, { name => 'mypkg::error_page' } );
 }

And not care about how the object will get displayed. So this action
could be declared in both of the following ways:

 [news]
 class             = OpenInteract2::Action::News
 content_generator = TT
 
 [shownews]
 class             = OpenInteract2::Action::News
 task              = show
 return_parameter  = news
 content_generator = SOAP


If the URL 'http://foo/news/show/?news_id=45' comes in from a browser
we will pass the news object to the Template Toolkit generator which
will display the news object in some sort of HTML page.

However, if the URL 'http://foo/news/shownews/' comes in via SOAP,
with the parameter 'news_id' defined as '45', we will pass the same
news object off to the SOAP content generator, which will take the
'news' parameter and place it into a SOAP response.

=head2 Caching

Another useful feature that comes from having the content generated in
a central location is that your content can be cached
transparently. Caching is done entirely in actions but is sizable
enough to be documented elsewhere. Please see
L<OpenInteract2::Manual::Caching|OpenInteract2::Manual::Caching> for
the lowdown.

=head1 PROPERTIES

You can set any of the properties with a method call. Examples are
given for each.

B<request> (object)

TODO: May go away

The L<OpenInteract2::Request|OpenInteract2::Request> associated with
the current request.

B<response> (object)

TODO: May go away

The L<OpenInteract2::Response|OpenInteract2::Response> associated with
the current response.

B<name> ($)

The name of this action. This is normally used to lookup information
from the action table.

This property is read-only -- it is set by the constructor when you
create a new action, but you cannot change it after the action is
created:

Example:

 print "Action name: ", $action->name, "\n";

B<url> ($)

URL used for this action. This is frequently the same as B<name>, but
you can override it in the action configuration. Note that this is
B<not> the fully qualified URL -- you need the C<create_url()> method
for that.

This property is read-only -- it is set by the constructor when you
create a new action, but you cannot change it after the action is
created:

Setting this property has implications as to what URLs your action
will respond to. See L<MAPPING URL TO ACTION> for more information.

Example:

 print "You requested ", $action->url, " within the application."

B<url_none> (bool)

Set to 'yes' to tell OI that you do not want this action accessible
via a URL. This is often done for boxes and other template-only
actions. See L<MAPPING URL TO ACTION> for more information.

Example:

 [myaction]
 class    = MyPackage::Action::MyBox
 method   = box
 title    = My Box
 weight   = 5
 url_none = yes

B<url_alt> (\@)

A number of other URLs this action can be accessible by. See L<MAPPING
URL TO ACTION> for more information.

Example:

 [news]
 class    = MyPackage::Action::News
 url_alt  = Nouvelles
 url_alt  = Noticias

B<message_name> ($)

Name used to find messages from the
L<OpenInteract2::Request|OpenInteract2::Request> object. Normally you
don't need to specify this and the action name is used. But if you
have multiple actions pointing to the same code this can be useful

Example:

 [news]
 class        = MyPackage::Action::News
 task_default = latest
 
 [latestnews]
 class        = MyPackage::Action::News
 method       = latest
 message_name = news

B<action_type> ($)

The type of action this is. Action types can provide default tasks,
output filters, etc. This is not required.

Example:

 $action->action_type( 'common' );
 $action->action_type( 'directory_handler' );
 $action->action_type( 'template_only' );

See L<Action Types> above for how to specify the action types actions
can use.

B<task> ($)

What task should this action run? Generally this maps to a subroutine
name, but the action can optionally provide its own dispatching
mechanism which maps the task in a different manner. (See L<Action
Tasks> above for more information.)

Example:

 if ( $security_violation ) {
     $action->param( error_msg => "Security violation: $security_violation" );
     $action->task( 'search_form' );
     return $action->execute;
 }

B<content_generator> ($)

Name of a content generator. Your server configuration can have a
number of content generators defined; this property should contain the
name of one.

Example:

 if ( $action->content_generator eq 'TT' ) {
     print "Content for this action will be generated by the Template Toolkit.";
 }

The property is frequently inherited from the default action, so you
may not see it explicitly declared in the action table.

B<template_source> (\%)

You have the option to specify your template source in the
configuration. This is required if using multiple content generators
for the same subroutine. (Actually, this is not true unless all your
content generators can understand the specified template source. This
will probably never happen given the sheer variety of templating
systems on the planet.)

This B<will not work> when an action superclass requires different
parameters to specify content templates. One set of examples are the
subclasses
L<OpenInteract2::Action::Common|OpenInteract2::Action::Common>.

Example, not using 'template_source'. First the action configuration:

 [foo]
 class = OpenInteract2::Action::Foo
 content_generator = TT

Now the action:

 sub mytask {
     my ( $self ) = @_;
     my %params = ( foo => 'bar', baz => [ 'this', 'that' ] );
     return $self->generate_content( \%params,
                                     { name => 'foo::mytask_template' } );
 }

Example using 'template_source'. First the configuration:

 [foo]
 class = OpenInteract2::Action::Foo
 content_generator = TT
 ...
 
 [foo template_source]
 mytask = foo::mytask_template

And now the action:

 sub mytask {
     my ( $self ) = @_;
     my %params = ( foo => 'bar', baz => [ 'this', 'that' ] );
     return $self->generate_content( \%params );
 }

What this gives us is the ability to swap out B<via configuration> a
separate display mechanism. For instance, I could specify the same
class in a different action but use a different content generator:

 [fooprime]
 class = OpenInteract2::Action::Foo
 content_generator = Wimpy
 
 [fooprime template_source]
 mytask = foo::mytask_wimpy_template

So now the following URLs will reference the same code but have the
content generated by separate processes:

 /foo/mytask/
 /fooprime/mytask/

B<is_secure> (bool)

Whether to check security for this action. True is indicated by 'yes',
false by 'no' (or anything else).

The return value is not the same as the value set. It returns a true
value (1) if the action is secured (if set to 'yes'), a false one (0)
if not.

Example:

 if ( $action->is_secure ) {
     my $level = CTX->check_security({ class => ref $action });
     if ( $level < SEC_LEVEL_WRITE ) {
         $action->param_add( error_msg => "Task forbidden due to security" );
         $action->task( 'search_form' );
         return $action->execute;
     }
 }

B<security_required> ($)

If the action is using security, what level is required for the action
to successfully execute.

Example:

 if ( $action->is_secure ) {
     my $level = CTX->check_security({ class => ref $action });
     if ( $level < $action->security_required ) {
         $action->param_add( error_msg => "Task forbidden due to security" );
         $action->task( 'search_form' );
         return $action->execute;
     }
 }

(Note: you will never need to do this since the
C<_find_security_level()> method does this (and more) for you.)

B<security_level> ($)

This is the security level found or set for this action and task. If
you set this beforehand then the action dispatcher will not check it
for you:

Example:

 # Action dispatcher will check the security level of the current user
 # for this action when 'execute()' is called.
 
 my $action = OpenInteract2::Action->new({
                    name           => 'bleeble',
                    task           => 'show' });
 return $action->execute;
 
 # Action dispatcher will use the provided level and not perform a
 # lookup for the security level on 'execute()'.
 
 my $action = OpenInteract2::Action->new({
                    name           => 'bleeble',
                    task           => 'show',
                    security_level => SEC_LEVEL_WRITE });
 return $action->execute;

B<task_valid> (\@)

An arrayref of valid tasks for this action.

Example:

 my $ok_tasks = $action->task_valid;
 print "Tasks for this action: ", join( ', ', @{ $ok_tasks } ), "\n";

B<task_invalid> (\@)

An arrayref of invalid tasks for this action. Note that the action
dispatcher will B<never> execute a task with a leading underscore
(e.g., '_find_records');

Example:

 my $bad_tasks = $action->task_invalid;
 print "Tasks not allowed for action: ", join( ', ', @{ $bad_tasks } ), "\n";

B<cache_expire> (\%)

Mapping of task name to expiration time for cached data, in seconds.

B<cache_param> (\%)

Mapping of task name to zero or more parameters (action/request) used
to identify the cached data. (See
L<OpenInteract2::Manual::Caching|OpenInteract2::Manual::Caching>)

=head1 METHODS

=head2 Class Methods

B<new( [ $name | $action | \%action_info ] [, \%values ] )>

Create a new action. This has three flavors:

=over 4

=item 1.

If passed C<$name> we ask the
L<OpenInteract2::Context|OpenInteract2::Context> to give us the action
information for C<$name>. If the action is not found an exception is
thrown.

Any action properties provided in C<\%values> will override the
default properties set in the action table. And any items in
C<\%values> that are not action properties will be set into the action
parameters, also overriding the values from the action table. (See
C<param()> below.)

=item 2.

If given C<$action> we do a simulated clone: create an empty action
object using the same class as C<$action> and fill it with the
properties and parameters from C<$action>. Then we call C<init()> on
the new object and return it. (TODO: is init() redundant with a
clone-type operation?)

Any values provided in C<\%properties> will override the properties
from the C<$action>. Likewise, any parameters from C<\%properties>
will override the parameters from the C<$action>.

=item 3.

If given C<\%action_info> we create a new action of the type found in
the 'class' key and assign the properties and paramters from the
hashref to the action. We also do a 'require' on the given class to
ensure it's available.

Any values provided in C<\%properties> will override the properties
from C<\%action_info>. Likewise, any parameters from C<\%properties>
will override the parameters from the C<\%action_info>. It's kind of
beside the point since you can just pass them all in the first
argument, but whatever floats your boat.

=back

Returns: A new action object; throws an exception if C<$name> is
provided but not found in the B<Action Table>.

Examples:

 # Create a new action of type 'news', set the task and execute
 
 my $action = OpenInteract2::Action->new( 'news' );
 $action->task( 'show' );
 $action->execute;
 
 # $new_action and $action are equivalent...
 
 my $new_action =
     OpenInteract2::Action->new( $action );

 # ...and this doesn't affect $action at all
 
 $new_action->task( 'list' );
 
 my $action = OpenInteract2::Action->new( 'news' );
 $action->task( 'show' );
 $action->param( soda => 'coke' );
 
 # $new_action and $action are equivalent except for the 'soda'
 # parameter and the 'task' property
 
 my $new_action =
     OpenInteract2::Action->new( $action, { soda => 'mr. pibb',
                                            task => 'list' } );
 
 # Create a new type of action on the fly
 # TODO: will this work?
 
 my $action = OpenInteract2::Action->new(
                    { name         => 'foo',
                      class        => 'OpenInteract2::Action::FooAction',
                      task_default => 'drink',
                      soda         => 'Jolt' } );

=head2 Object Methods

B<init()>

This method allows action subclasses to perform any additional
initialization required. Note that before this method is called from
C<new()> all of the properties and parameters from C<new()> have been
set into the object whether you've created it using a name or by
cloning another action.

If you define this you B<must> call C<SUPER::init()> so that all
parent classes have a chance to perform initialization as well.

Returns: The action object, or undef if initialization failed.

Example:

 package OpenInteract2::Action::MyAction;
 
 use base qw( OpenInteract2::Action );
 
 my %DEFAULTS = ( foo => 'bar', baz => 'quux' );
 sub init {
     my ( $self ) = @_;
     while ( my ( $key, $value ) = each %DEFAULTS ) {
         unless ( $self->param( $key ) ) {
             $self->param( $key, $value );
         }
     }
     return $self->SUPER::init();
 }

B<create_url( \%params )>

Generate a self-referencing URL to this action, using C<\%params> as
an appended query string. Under the covers we use
L<OpenInteract2::URL|OpenInteract2::URL> to do the real work.

Note that you can also override the task set in the current action
using the 'TASK' parameter. So you could be on the form display for a
particular object and generate a URL for the removal task by passing
'remove' in the 'TASK' parameter.

See L<MAPPING URL TO ACTION> for a discussion of how an action is
mapped to multiple URLs and which URL will be chosen as the base for
the URL generated by this method.

Returns: URL for this action

Examples:

 my $action = OpenInteract2::Action->new({ name => 'games',
                                           task => 'explore' });
 my $url = $action->create_url;
 # $url: "/games/explore/"
 my $url = $action->create_url({ edit => 'yes' });
 # $url: "/games/explore/?edit=yes"
 my $url = $action->create_url({ TASK => 'edit', game_id => 42 });
 # $url: "/games/edit/?game_id=42"
 
 <a href="[% action.create_url( edit = 'yes' ) %]">Click me!</a>
 # <a href="/games/explore/?edit=yes">Click me!</a>
 <a href="[% action.create_url( task = 'EDIT', game_id = 42 ) %]">Click me!</a>
 # <a href="/games/edit/?game_id=42">Click me!</a>
 
 CTX->assign_deploy_url( '/Archives' );
 my $url = $action->create_url;
 # $url: "/Archives/games/explore/"
 my $url = $action->create_url({ edit => 'yes' });
 # $url: "/Archives/games/explore/?edit=yes"
 my $url = $action->create_url({ TASK => 'edit', game_id => 42 });
 # $url: "/Archives/games/edit/?game_id=42"
 
 <a href="[% action.create_url( edit = 'yes' ) %]">Click me!</a>
 # <a href="/Archives/games/explore/?edit=yes">Click me!</a>
 <a href="[% action.create_url( task = 'EDIT', game_id = 42 ) %]">Click me!</a>
 # <a href="/Archives/games/edit/?game_id=42">Click me!</a>

B<get_dispatch_urls>

Retrieve an arrayref of the URLs this action is dispatched under. This
may be an empty arrayref if the action is not URL-accessible.

This is normally only called at
L<OpenInteract2::Context|OpenInteract2::Context> startup when it reads
in the actions from all the packages, but it might be informative
elsewhere as well. (For instance, we use it in the management task
'list_actions' to show all the URLs each action responds to.) See
L<MAPPING URL TO ACTION> for how the method works.

Returns: arrayref of URLs this action is dispatched under.

Example:

 my $urls = $action->get_dispatch_urls;
 print "This action is available under the following URLs: \n";
 foreach my $url ( @{ $urls } ) {
     print " *  $url\n";
 }

=head2 Object Execution Methods

B<execute( \%vars )>

Generate content for this action and task. If the task has an error it
can generate error content and C<die> with it; it can also just C<die>
with an error message, but that's not very helpful to your users.

The C<\%vars> argument will set properties and parameters (via
C<property_assign()> and C<param_assign()>) before generating the
content.

TODO: fill in info about caching

Returns: content generated by the action

B<forward( $new_action )>

TODO: may get rid of this

Forwards execution to C<$new_action>.

Returns: content generated by calling C<execute()> on C<$new_action>.

Examples:

 sub edit {
     my ( $self ) = @_;
     # ... do edit ...
     my $list_action = CTX->lookup_action( 'object_list' );
     return $self->forward( $list_action );
 }

B<clear_cache()>

Most caching is handled for you using configuration declarations and
callbacks in C<execute()>. The one part that cannot be easily
specified is when objects change. If your action is using caching then
you'll probably need to call C<clear_cache()> whenever you modify
objects whose content may be cached. "Probably" because your app may
not care that some stale data is served up for a little while.

For instance, if you're caching the latest news items and add a new
one you don't want your 'latest' listing to miss the entry you just
added. So you clear out the old cache entries and let them get rebuilt
on demand.

Since we don't want to create a crazy dependency graph of data that's
eventually going to expire anyway, we just remove all cache entries
generated by this class.

Returns: number of cache entries removed

=head2 Object Content Methods

B<generate_content( \%content_params, [ \%template_source ], [ \%template_params ] )>

This is used to generate content for an action.

The information in C<\%template_source> is only optional if you've
specified the source in your action configuration. See the docs for
property B<template_source> for more information.

Also, note that any view messages you've added via C<view_messages()>
or C<add_view_message()> will be passed to the template in the key
C<action_messages>.

TODO: fill in more: how to id content

=head2 Object Property and Parameter Methods

B<property_assign( \%properties )>

Assigns values from properties specified in C<\%properties>. Only the
valid properties for actions will be set, everything else will be
skipped.

Currently we only set properties for which there is a defined value.

Returns: action object (C<$self>)

See L<PROPERTIES> for the list of properties in each action.

B<property( [ $name, $value ] )>

Get/set action properties. (In addition to direct method call, see
below.) This can be called in three ways:

 my $props   = $action->property;            # $props is hashref
 my $value   = $action->property( $name );   # $value is any type of scalar
 $new_value  = $action->property( $name, $new_value );

Returns: if called without arguments, returns a copy of the hashref of
properties attached to the action (changes made to the hashref will
not affect the action); if called with one or two arguments, returns
the new value of the property C<$name>.

Note that this performs the same action as the direct method call with
the property name:

 # Same
 $action->property( $property_name );
 $action->$property_name();

 # Same
 $action->property( $property_name, $value );
 $action->$property_name( $value );

See L<PROPERTIES> for the list of properties in each action.

B<property_clear( $key )>

Sets the property defined by C<$key> to C<undef>. This is the only way
to unset a property.

Returns: value previously set for the property C<$key>.

See L<PROPERTIES> for the list of properties in each action.

B<param_assign( \%params )>

Assigns all items from C<\%params> that are not valid properties to
the action as parameters.

Currently we only set parameters for which there is a defined value.

Returns: action object (C<$self>)

B<param( [ $key, $value ] )>

Get/set action parameters. This can be called in three ways:

 my $params  = $action->param;             # $params is hashref
 my $value   = $action->param( $name );    # $value is any type of scalar
 $action->param( $name, $new_value );
 my ( @params ) = $action->param( $name ); # ...context senstive

Returns: if called without arguments, returns a copy of the hashref of
parameters attached to the action (changes made to the hashref will
not affect the action); if called with one or two arguments, returns
the context-sensitve new value of the parameter C<$name>.

B<param_add( $key, @values )>

Adds (rather than replaces) the values C<@value> to the parameter
C<$key>. If there is a value already set for C<$key>, or if you pass
multiple values, it's turned into an array reference and C<@values>
C<push>ed onto the end. If there is no value already set and you only
pass a single value it acts like the call to C<param( $key, $value )>.

This is useful for potentially multivalue parameters, such as the
often-used 'error_msg' and 'status_msg'. You can still access the
values with C<param()> in context:

 $action->param( error_msg => "Ooops I..." );
 $action->param_add( error_msg => "did it again" );
 my $full_msg = join( ' ', $action->param( 'error_msg' ) );
 # $full_msg = 'Ooops I... did it again'
 
 $action->param( error_msg => "Ooops I..." );
 $action->param_add( error_msg => "did it again" );
 $action->param( error_msg => 'and again' );
 my $full_msg = join( ' ', $action->param( 'error_msg' ) );
 # $full_msg = 'and again'
 
 $action->param( error_msg => "Ooops I..." );
 $action->param_add( error_msg => "did it again" );
 my $messages = $action->param( 'error_msg' );
 # $messages->[0] = 'Ooops I...'
 # $messages->[1] = 'did it again'

Returns: Context senstive value in of C<$key>

B<param_clear( $key )>

Removes all parameter values defined by C<$key>. This is the only way
to remove a parameter.

Returns: value(s) previously set for the parameter C<$key>,
non-context sensitive.

B<param_from_request( @param_names )>

Sets the action parameter value to the request parameter value for
each name in C<@param_names>.

This will overwrite existing action parameters if they are not already
defined.

Returns: nothing

B<view_messages( [ \%messages ] )>

Returns the message names and associated messages in this
action. These may have been set directly or they may have been
deposited in the request (see C<action_messages()> in
L<OpenInteract2::Request|OpenInteract2::Request>) and picked up at
action instantiation.

Note that these get put in the template's content variable hashref
under the key C<action_messages> as long as the content is generated
using C<generate_content()>.

Returns: hashref of view errors associated with this action; may be an
empty hashref.

B<add_view_message( $msg_name, $msg )>

Assign the view messgate C<$msg_name> as C<$msg> in this action.

=head2 Internal Object Execution Methods

You should only need to know about these methods if you're creating
your own action.

B<_find_task()>

Tries to find a task for the action. In order, the method looks:

=over 4

=item *

In the 'method' property of the action. This means the action is
hardwired to a particular method and cannot be changed, even if you
set 'task' manually.

TODO: This might change... why use 'method' when we could keep with
the task terminology and use something like 'task_concrete' or
'task_only'?

=item *

In the 'task' property of the action: it might already be defined!

=item *

In the 'task_default' property of the action.

=back

If a task is not found we throw an exception.

Returns: name of task.

B<_check_task_validity()>

Ensure that task assigned is valid. If it is not we throw an
L<OpenInteract2::Exception|OpenInteract2::Exception>.

A valid task:

=over 4

=item *

Does not begin with an underscore.

=item *

Is not listed in the C<task_invalid> property.

=item *

Is listed in the C<task_valid> property, if that property is defined.

=back

Returns: nothing, throwing an exception if the check fails.

B<_find_task_method()>

Finds a valid method to call for the action task. If the method
C<handler()> is defined in the action class or any of its parents,
that is called. Otherwise we check to see if the method C<$task()> --
which should already have been checked for validity -- is defined in
the action class or any of its parents. If neither is found we throw
an exception.

You are currently not allowed to have a task of the same name as one
of the action properties. If you try to execute a task by this name
you'll get a message in the error log to this effect.

Note that we cache the returned code reference, so if you do something
funky with the symbol table or the C<@ISA> for your class after a
method has been called, everything will be mucked up.

Returns: code reference to method for task.

B<_check_security()>

Checks security for this action. On failure throws a security
exception, on success returns the security level found (also set in
the action property C<security_level>). Here are the steps we go
through:

=over 4

=item *

First we get the security level for this action. If already set (in
the C<security_level> property) we use that. Otherwise we call
C<_find_security_level> to determine the level. This is set in the
action property C<security_level>.

=item *

If the action isn't secured we short-circuit operations and return the
security level.

=item *

Third, we ensure that the action property C<security> contains a
hashref. If not we throw an exception.

=item *

Next, we determine the security level required for this particular
task. If neither the task nor 'DEFAULT' is defined in the hashref of
security requirements, we assume that C<SEC_LEVEL_WRITE> security is
required.

The level found is set in the action property C<security_required>.

=item *

Finally, we compare the C<security_level> with the
C<security_required>. If the required level is greater we throw a
security exception.

=back

Returns: security level for action if security check okay, exception
if not.

B<_find_security_level()>

Returns the security level for this combination of action, user and
groups. First it looks at the 'is_secure' action property -- if true we
continue, otherwise we return C<SEC_LEVEL_WRITE> so the system will
allow any user to perform the task.

If the action is secured we find the actual security level for this
action and user and return it.

Returns: security level for action given current user and groups.

=head1 TO DO

B<URL handling>

How we respond to URLs and the URLs we generate for ourselves is a
little confusing. We may want to ensure that when a use requests an
alternate URL -- for instance '/Nouvelles/' for '/News/' -- that the
URL generated from 'create_url()' also uses '/Nouvelles/'. Currently
it does not, since we're using OI2::URL to generate the URL for us and
on the method call it's divorced from the action state.

We could get around this with an additional property 'url_requested'
(or something) which would only be set in the constructor if the
'REQUEST_URL' is passed in. Then the 'create_url' would use it and
call the 'create' method rather than 'create_from_action' method in
OI2::URL.

=head1 SEE ALSO

L<OpenInteract2::Context|OpenInteract2::Context>

L<OpenInteract2::URL|OpenInteract2::URL>

L<Class::Observable|Class::Observable>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
