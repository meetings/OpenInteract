package OpenInteract2::Setup;

# $Id: Setup.pm,v 1.42 2004/03/19 03:09:37 lachoy Exp $

use strict;
use File::Copy               qw( cp );
use File::Basename           qw();
use File::Path               qw();
use File::Spec::Functions    qw( :ALL );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Config;
use OpenInteract2::Config::Initializer;
use OpenInteract2::Config::Base;
use OpenInteract2::ContentGenerator;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Filter;
use OpenInteract2::I18N::Initializer;
use OpenInteract2::Manage;
use OpenInteract2::Package;
use OpenInteract2::Repository;
use OpenInteract2::Util;
use SPOPS::Initialize;

$OpenInteract2::Setup::VERSION = sprintf("%d.%02d", q$Revision: 1.42 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub new {
    my ( $class ) = @_;
    return bless( {}, $class );
}


########################################
# SERVER CONFIG

# Just grab the config and set the runtime info.

sub read_server_config {
    my ( $self ) = @_;
    my $base_config = CTX->base_config;
    unless ( ref $base_config eq 'OpenInteract2::Config::Base' ) {
        oi_error "'base_config' property of context not set properly";
    }
    my $server_config_file = $base_config->get_server_config_file;
    unless ( $server_config_file ) {
        oi_error "Cannot read server configuration: file not defined ",
                 "in base config";
    }
    my $server_conf = OpenInteract2::Config->new(
                            $base_config->config_type,
                            { filename => $server_config_file } );
    $server_conf->{dir}{website} = $base_config->website_dir;
    $server_conf->translate_dirs;
    return $server_conf;
}


########################################
# PACKAGES

# Open up the package repository and return it. We may do additional
# initialization here.

sub read_repository {
    my ( $self ) = @_;
    my $base_config = CTX->base_config;
    unless ( ref $base_config eq 'OpenInteract2::Config::Base' ) {
        oi_error "'base_config' property of context not set properly";
    }
    return OpenInteract2::Repository->new( $base_config );
}


sub read_packages {
    my ( $self ) = @_;
    my $repos = CTX->repository;
    unless ( ref $repos eq 'OpenInteract2::Repository' ) {
        oi_error "Cannot retrieve packages for a website without first ",
                 "opening and assigning a repository to the context.";
    }
    return $repos->fetch_all_packages;
}


########################################
# TEMPORARY LIBRARY

# Method to copy all .pm files from all packages in a website to a
# separate directory -- if it currently exists we clear it out first.

sub create_temp_lib {
    my ( $self, $params ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $full_temp_lib_dir = CTX->lookup_temp_lib_directory;
    unshift @INC, $full_temp_lib_dir;

    my $create_option = $params->{temp_lib_create};
    my $do_create = ( $create_option and $create_option eq 'create' );
    if ( -d $full_temp_lib_dir and ! $do_create ) {
        my $refresh_file =
            catfile( $full_temp_lib_dir,
                     CTX->lookup_temp_lib_refresh_filename );
        unless ( -f $refresh_file ) {
            $log->is_info &&
                $log->info( "Temp lib dir '$full_temp_lib_dir' exists; ",
                            "option is not 'create' and there is no ",
                            "'refresh' file so modules not copied" );

            # Picks up management tasks from packages (move this to Context?)
            OpenInteract2::Manage->find_management_tasks( $full_temp_lib_dir );
            return [];
        }
    }

    if ( -d $full_temp_lib_dir ) {
        my $num_removed = File::Path::rmtree( $full_temp_lib_dir );
        unless ( $num_removed ) {
            oi_error "Tried to remove directory '$full_temp_lib_dir' but ",
                     "no directories removed. Please check permissions.";
        }
    }
    eval { mkdir( $full_temp_lib_dir, 0777 ) || die $! };
    if ( $@ ) {
        oi_error "Failed to create directory '$full_temp_lib_dir': $@";
    }

    my $packages = CTX->packages;
    unless ( ref $packages eq 'ARRAY' and scalar @{ $packages } ) {
        oi_error "Property 'packages' must be set in context";
    }

    my ( @all_files );
    foreach my $package ( @{ $packages } ) {
        $log->is_debug &&
            $log->debug( "Trying to copy files for package ",
                         $package->name );
        my $package_dir = $package->directory;
        my $module_files = $package->get_module_files;
        foreach my $module_file_spec ( @{ $module_files } ) {
            my $source_file = catfile( $package_dir,
                                       @{ $module_file_spec } );
            my $dest_file   = catfile( $full_temp_lib_dir,
                                       @{ $module_file_spec } );
            my $dest_path = File::Basename::dirname( $dest_file );
            File::Path::mkpath( $dest_path, undef, 0777 );

            eval { cp( $source_file, $dest_file ) || die $! };
            if ( $@ ) {
                oi_error "When creating temporary library, failed to ",
                         "copy '$source_file' to '$dest_file': $@";
            }
            push @all_files, $dest_file;
        }
    }

    # Now change permissions so all the files and directories are
    # world-everything, letting the process's umask kick in

    chmod( 0666, @all_files );

    my %tmp_dirs = map { $_ => 1 }
                       map { File::Basename::dirname( $_ ) } @all_files;
    chmod( 0777, ( keys %tmp_dirs, $full_temp_lib_dir ) );

    # Picks up management tasks from packages (move this to Context?)
    OpenInteract2::Manage->find_management_tasks( $full_temp_lib_dir );

    $log->is_debug &&
        $log->debug( "Copied ", scalar @all_files, " modules ",
                     "to '$full_temp_lib_dir'" );
    return \@all_files;
}

########################################
# SESSIONS

sub require_session_classes {
    my ( $self, $session_config ) = @_;
    $log ||= get_logger( LOG_INIT );
    my @session_classes = ( $session_config->{class},
                            $session_config->{impl_class} );
    $log->info( "Requiring session classes: ",
                join( ', ', @session_classes ) );
    return $self->require_module({ class => \@session_classes });
}


########################################
# ACTION TABLE

# Scan all the actions from all the packages and build the action
# table, plugging in defaults from 'action_info->default' where
# appropriate

sub read_action_table {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );

    # This will become the action table

    my %ACTION = ();

    my $initializer = OpenInteract2::Config::Initializer->new;

    my $packages = CTX->packages;
    foreach my $package ( @{ $packages } ) {
        my $package_id = join( '-', $package->name, $package->version );
        $log->is_debug &&
            $log->debug( "Reading action data from $package_id" );
        my $filenames = $package->get_action_files;

ACTIONFILE:
        foreach my $action_file ( @{ $filenames } ) {
            my $full_action_path = $package->find_file( $action_file );
            $log->is_debug &&
                $log->debug( "Action file: $full_action_path" );
            my $action_ini = eval {
                OpenInteract2::Config::Ini->new(
                                   { filename => $full_action_path });
            };
            if ( $@ ) {
                $log->error( "Failed to read '$full_action_path': $@" );
                next ACTIONFILE;
            }
            foreach my $action_name ( $action_ini->main_sections ) {
                if ( $ACTION{ $action_name } ) {

                    # TODO: Throw an exception if this happens?
                    $log->error( "WARNING - Multiple actions defined for ",
                                 "the same name '$action_name'. Overwriting ",
                                 "data from '$ACTION{ $action_name }->{package_name}'" );
                    delete $ACTION{ $action_name };
                }

                my %action_assign = ();
                $action_assign{name} = $action_name;
                while ( my ( $action_item, $action_value ) =
                                            each %{ $action_ini->{ $action_name } } ) {
                    $action_assign{ $action_item } = $action_value;
                }

                # Set the package name/version this action came from
                $action_assign{package_name}    = $package->name;
                $action_assign{package_version} = $package->version;
                $action_assign{config_file}     = $full_action_path;
                $ACTION{ $action_name } = \%action_assign;
            }
        }
    }

    my $override_file = catfile( CTX->lookup_directory( 'config' ),
                                 CTX->lookup_override_action_filename );
    if ( -f $override_file ) {
        my $overrider = OpenInteract2::Config::GlobalOverride->new(
                                        { filename => $override_file } );
        $overrider->apply_rules( \%ACTION );
    }

    foreach my $action_config ( values %ACTION ) {
        $log->info( "Notifying observers of config for action ",
                    "'$action_config->{name}'" );
        $initializer->notify_observers( 'action', $action_config );
    }

    return \%ACTION;
}


# Requires the action table to have already been built; scan through
# the classes and build a unique list of all classes referenced in the
# actions

sub require_action_classes {
    my ( $self, $action_table ) = @_;
    return [] unless ( ref $action_table eq 'HASH' );
    my @classes = ();
    foreach my $action_info ( values %{ $action_table } ) {
        if ( ref $action_info->{isa} eq 'ARRAY' ) {
            push @classes, grep { defined $_ } @{ $action_info->{isa} };
        }
        if ( ref $action_info->{rules_from} eq 'ARRAY' ) {
            push @classes, grep { defined $_ } @{ $action_info->{rules_from} };
        }
    }
    my %uniq_classes = map { $_ => 1 } @classes;
    return $self->require_module({ class => [ keys %uniq_classes ] });
}


sub initialize_action_classes {
    my ( $self, $action_classes ) = @_;
    $log ||= get_logger( LOG_INIT );
    return [] unless ( ref $action_classes eq 'ARRAY' );

    my @success = ();
    foreach my $action_class ( @{ $action_classes } ) {
        $log->is_debug &&
            $log->debug( "Initializing action class '$action_class'" );
        eval { $action_class->init_at_startup() };
        if ( $@ ) {
            $log->error( "Caught error initializing action class ",
                         "'$action_class': $@" );
        }
        else {
            $log->is_info &&
                $log->info( "Initialized action class '$action_class' ok" );
            push @success, $action_class;
        }
    }
    return \@success;
}

sub register_action_types {
    my ( $self ) = @_;
    my $action_types = CTX->server_config->{action_types};
    return [] unless ( ref $action_types eq 'HASH' );
    my @classes = ();
    while ( my ( $type, $class ) = each %{ $action_types } ) {
        OpenInteract2::Action->register_factory_type( $type, $class );
        push @classes, $class;
    }
    return \@classes;
}

########################################
# INITIALIZE OBSERVERS

# sets the filter registry in CTX, adds config watchers to
# OI2::Config::Initializer

sub initialize_observers {
    my ( $self ) = @_;

    # Filters
    OpenInteract2::Filter->initialize;

    # Configuration watchers
    OpenInteract2::Config::Initializer->read_observers;
}

########################################
# SPOPS

sub read_spops_config {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $server_config = CTX->server_config;

    # This will become the full SPOPS config
    my %SPOPS = ();

    my $initializer = OpenInteract2::Config::Initializer->new;

    my $default_datasource = CTX->lookup_default_datasource_name;
    $log->info( "Using default datasource '$default_datasource'" );

    my $packages = CTX->packages;
    foreach my $package ( @{ $packages } ) {
        my $package_id = join( '-', $package->name, $package->version );
        $log->is_debug &&
            $log->debug( "Reading SPOPS data from $package_id" );
        my $filenames = $package->get_spops_files;

SPOPSFILE:
        foreach my $spops_file ( @{ $filenames } ) {
            $log->is_debug &&
                $log->debug( "SPOPS file: $spops_file" );
            my $full_spops_path = $package->find_file( $spops_file );
            my $spops_ini = eval {
                OpenInteract2::Config::Ini->new({ filename => $full_spops_path });
            };
            if ( $@ ) {
                $log->error( "Failed to read '$full_spops_path': $@" );
                next SPOPSFILE;
            }

            foreach my $spops_key ( $spops_ini->main_sections ) {
                if ( $SPOPS{ $spops_key } ) {

                    # TODO: Throw an exception if this happens?
                    $log->error( "WARNING - Multiple SPOPS objects defined ",
                                 "with the same key '$spops_key'. Overwriting data ",
                                 "from '$SPOPS{ $spops_key }->{package_name}'" );
                    delete $SPOPS{ $spops_key };
                }

                # Put the alias inside the SPOPS object
                my %spops_assign = ( key => $spops_key );

                # Then copy over all the object definition info

                while ( my ( $key, $value ) =
                                each %{ $spops_ini->{ $spops_key } } ) {
                    $spops_assign{ $key } = $value;
                }

                # Set the package name/version this object came from

                $spops_assign{package_name}    = $package->name;
                $spops_assign{package_version} = $package->version;
                $spops_assign{config_file}     = $full_spops_path;

                # Set the default datasource if it's not already

                $spops_assign{datasource} ||= $default_datasource;


                $SPOPS{ $spops_key } = \%spops_assign;
                $log->is_info &&
                    $log->info( "Read in SPOPS config for object ",
                                "[$spops_key: $spops_ini->{ $spops_key }{class}]" );
            }
        }
    }

    my $override_file = catfile( CTX->lookup_directory( 'config' ),
                                 CTX->lookup_override_spops_filename );
    if ( -f $override_file ) {
        my $overrider = OpenInteract2::Config::GlobalOverride->new(
                                        { filename => $override_file } );
        $overrider->apply_rules( \%SPOPS );
    }

    foreach my $spops_config ( values %SPOPS ) {
        $initializer->notify_observers( 'spops', $spops_config );
        $log->is_info &&
            $log->info( "Notified observers of config for SPOPS ",
                        "[$spops_config->{key}: $spops_config->{class}]" );
    }

    return \%SPOPS;
}

sub activate_spops_classes {
    my ( $self, $spops_config ) = @_;
    $log ||= get_logger( LOG_INIT );

    $spops_config ||= CTX->spops_config;
    my $classes = SPOPS::Initialize->process({ config => $spops_config });
    if ( ref $classes eq 'ARRAY' and scalar @{ $classes } ) {
        $log->is_info &&
            $log->info( "Initialized the following SPOPS classes: \n  ",
                        join( "\n  ", @{ $classes } ) );
        my @alias_classes = ();
        for ( keys %{ $spops_config } ) {
            my $alias_class = $spops_config->{$_}{alias_class};
            push @alias_classes, $alias_class if ( $alias_class );
        }
        $self->require_module({ class => \@alias_classes });
    }
    else {
        $log->error( "No SPOPS classes initialized!" );
    }
    return $classes;
}

########################################
# LOCALIZED MESSAGES

sub read_localized_messages {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $initializer = OpenInteract2::Config::Initializer->new;

    my $i18n_init = OpenInteract2::I18N::Initializer->new;
    $i18n_init->locate_global_message_files();

    my $packages = CTX->packages;
    foreach my $package ( @{ $packages } ) {
        my $package_id = join( '-', $package->name, $package->version );
        my $package_dir = $package->directory;
        my $filenames = $package->get_message_files;
        $log->is_debug &&
            $log->debug( "Got message files from $package_id: ",
                         join( ', ', @{ $filenames } ) );
        my @full_filenames = map { catfile( $package_dir, $_ ) }
                                 @{ $filenames };
        $i18n_init->add_message_files( @full_filenames );
    }
    my $classes = $i18n_init->run;
    $log->is_info &&
        $log->info( "Created the following message classes: ",
                    join( ', ', @{ $classes } ) );
    foreach my $msg_class ( @{ $classes } ) {
        $initializer->notify_observers( 'localization', $msg_class );
        $log->is_info &&
            $log->info( "Notified observers of config for localization ",
                        "class '$msg_class' " );
    }
    return $classes;
}


########################################
# DATASOURCES

sub check_datasources {
    my ( $self ) = @_;
    my $server_config = CTX->server_config;
    while ( my ( $ds_name, $ds_info ) =
                        each %{ $server_config->{datasource} } ) {
        unless ( ref $ds_info eq 'HASH' ) {
            oi_error "Datasource '$ds_name' does have its configuration ",
                     "defined in the server configuration.";
        }
        my $ds_type_info = $server_config->{datasource_type}{ $ds_info->{type} };
        unless ( ref $ds_type_info eq 'HASH' ) {
            oi_error "Datasource type '$ds_info->{type}' defined in ",
                     "datasource '$ds_name' but no type information ",
                     "defined in the server config under ",
                     "'datasource_type.$ds_info->{type}'";
        }
        my $ds_config_handler = $ds_type_info->{spops_config};
        eval "require $ds_config_handler";
        if ( $@ ) {
            oi_error "Could not include module '$ds_config_handler' ",
                     "to handle SPOPS configuration information: $@";
        }
    }
}


########################################
# CONTROLLERS

sub initialize_controller {
    my ( $self ) = @_;
    my $controllers = CTX->lookup_controller_config;
    while ( my ( $name, $info ) = each %{ $controllers } ) {
        OpenInteract2::Controller->register_factory_type( $name => $info->{class} );
    }
    OpenInteract2::Controller->initialize_default_actions;
}

########################################
# CONTENT GENERATORS

sub initialize_content_generator {
    my ( $self ) = @_;
    OpenInteract2::ContentGenerator->initialize_all_generators;
}


########################################
# CACHE

sub create_cache {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );

    my $cache_config = CTX->lookup_cache_config;
    unless ( lc $cache_config->{use} eq 'yes' ) {
        $log->is_debug &&
            $log->debug( "Cache not configured for usage" );
        return undef;
    }

    my $cache_class = $cache_config->{class};
    $log->is_debug &&
        $log->debug( "Creating cache with class '$cache_class'" );
    eval "require $cache_class";
    if ( $@ ) {
        $log->error( "Cannot create cache -- error including cache ",
                     "class '$cache_class': $@" );
        return undef;
    }
    my $cache = $cache_class->new( $cache_config );
    $log->is_debug &&
        $log->debug( "Cache setup ok" );

    if ( $cache_config->{cleanup} eq 'yes' ) {
        $cache->purge;
    }

    return $cache;
}

########################################
# SYSTEM CLASSES

sub read_system_classes {
    my ( $self ) = @_;
    my $system_classes = CTX->lookup_class;
    return $self->require_module({ class => [ values %{ $system_classes } ] });
}


########################################
# REQUIRE MULTIPLE MODULES

sub require_module {
    my ( $class, $params ) = @_;
    $log ||= get_logger( LOG_INIT );

    my @success = ();
    my $classes = [];
    if ( $params->{filename} ) {
        return [] unless ( -f $params->{filename} );
        $classes = OpenInteract2::Util->read_file_lines(
                                             $params->{filename} );
    }
    elsif ( $params->{class} ) {
        $classes = ( ref $params->{class} eq 'ARRAY' )
                     ? $params->{class} : [ $params->{class} ];
    }
    else {
        oi_error "Must specify 'filename' or 'class' as parameter";
    }

    foreach my $in_class ( @{ $classes } ) {
        next unless ( $in_class );
        eval "require $in_class";
        if ( $@ ) {
            $log->error( sprintf( "require error from '%s': %-40s: %s",
                                  join( ' @ ', (caller)[0,2] ), $in_class, $@ ) );
        }
        else {
            push @success, $in_class;
        }
    }
    return \@success;
}

1;

__END__

=head1 NAME

OpenInteract2::Setup - Setup an OpenInteract2::Context object

=head1 SYNOPSIS

 # Note: This is normally done ONLY in OpenInteract2::Context

 use OpenInteract2::Setup;
 
 # Just used for less typing...
 
 my $setup = OpenInteract2::Setup->new;
 
 # Grab server configuration
 
 my $config = $setup->read_server_config({
                              website_dir => '/path/to/mysite' });
 
 my $config = $setup->read_server_config({
                              base_config => $base_config });
 
 # Create a temporary library -- a single directory where we copy all
 # Perl modules from the packages used. (The 'create' option clears
 # out the old directory and replaces it.)
 
 my $copied = $setup->create_temp_lib({ temp_lib_create => 'create' });
 print "Files copied to temp library: ", join( ", ", @{ $copied } );
 
 # Same thing, except only copy modules if the temp lib doesn't exist
 # and if the refresh file (CTX->lookup_temp_lib_refresh_filename)
 # doesn't exist
 
 my $copied = $setup->create_temp_lib;
 
 # Build the action table and bring in the necessary classes
 
 my $actions = $setup->read_action_table();
 print "Actions in server: ", join( ", ", @{ $actions } );
 my $modules = $setup->require_action_classes( $actions );
 my $initialized = $setup->initialize_action_classes( $modules );
 
 # Read the SPOPS configuration and build all the SPOPS classes
 
 my $spops_config = $setup->read_spops_config();
 print "SPOPS object aliases: ", join( ", ", @{ $aliases } );
 my $classes = $setup->activate_spops_classes( $spops_config );
 
 # Require a bunch of mdules at once
 
 my $required = $setup->require_module({ class => \@class_list });
 my $required = $setup->require_module({ filename => 'apache_modules.dat' });
 
=head1 DESCRIPTION

=head1 METHODS

B<read_server_config()>

The C<base_config> property of the context must be defined before this
is called. Reads in the server configuration, sets information from
the base configuration (website name and directory) and calls
C<translate_dirs()> on the server config object.

Throws an exception if it cannot read the server configuration file or
on any errors found in creating the
L<OpenInteract2::Config|OpenInteract2::Config> object.

Returns: L<OpenInteract2::Config|OpenInteract2::Config>-derived object

B<read_repository()>

Opens up a package repository and stores it. Must have the
C<base_config> property defined before calling or an exception is
thrown.

Returns: The L<OpenInteract2::Repository|OpenInteract2::Repository>
object

B<read_packages()>

Retrieve all packages currently in a website. You must first assign a
L<OpenInteract2::Repository|OpenInteract2::Repository> object (run
C<read_repository()>) to the context or this method will throw an
exception.

Returns: an arrayref of L<OpenInteract2::Package|OpenInteract2::Package>
objects.

B<create_temp_dir( \%params )>

Optionally copies all .pm files from all packages in a website to a
temporary library directory. Unlike OI 1.x the default is to leave the
directory as-is if it already exists and only overwrite it on
demand. So if the directory exists and the refresh file doesn't exist
(more below), no files will be copied unless the 'temp_lib_create' key
in C<\%params> is set to 'create'.

The context must have the packages set before this is run, otherwise
an exception is thrown.

The refresh file is created by certain OI2 management tasks and
signals that the library directory needs to be refreshed. One such
task is installing a new package, the assumption being that you'll
only need to refresh the temporary library directory when the
libraries actually change.

Returns: Arrayref of all files copied

B<read_action_table()>

Reads in all available action configurations from all installed
packages. While we read in each action configuration we perform a few
other tasks, listed below.

Note that when copying default information, we only copy the
information if the action B<key> (not just the value) is
undefined. This ensures you can define empty action keys and not worry
about any default information overwriting it at server startup.

=over 4

=item *

Install the action name in the keys 'key' and 'name' (One of these
will probably be chosen before release.)

=item *

Copy the package name and version into the action using the keys
'package_name' and 'package_version'.

=item *

Copy the filename from which we read the information into the key
'config_file'.

=item *

Copy default action information from the global defaults (found in the
server configuration key 'action_info.default').

=item *

Copy default action information from the local defaults, found in the
action 'DEFAULT' in each configuration file. (This is optional.)

=back

Returns: Action table (hashref)

Example:

 action.ini
 ----------------------------------------
 [DEFAULT]
 author       = Chris Winters E<lt>chris@cwinters.comE<gt>
 
 [user]
 class        = OpenInteract2::Handler::User
 security     = no
 default_task = search_form
 
 [newuser]
 class        = OpenInteract2::Handler::NewUser
 error        = OpenInteract2::Error::User
 security     = no
 default_task = show
 ----------------------------------------

This would result in an action table:

 user => {
    class        => 'OpenInteract2::Handler::User',
    security     => 'no',
    default_task => 'search_form',
    key          => 'user',
    name         => 'user',
    package_name => 'base_user',
    package_version => 1.45,
    config_file  => '/home/httpd/mysite/pkg/base_user-1.45/conf/action.ini',
    author       => 'Chris Winters E<lt>chris@cwinters.comE<gt>',
 },
 newuser => {
    class        => 'OpenInteract2::Handler::NewUser',
    error        => 'OpenInteract2::Error::User',
    security     => 'no',
    default_task => 'show'
    key          => 'newuser',
    name         => 'newuser',
    package_name => 'base_user',
    package_version => 1.45,
    config_file  => '/home/httpd/mysite/pkg/base_user-1.45/conf/action.ini',
    author       => 'Chris Winters E<lt>chris@cwinters.comE<gt>',
 },

B<require_action_classes( \%action_table )>

Scans through all the actions and performs a 'require' on all
referenced classes.

Returns: Arrayref of all classes successfully required.

B<initialize_action_classes( \@action_classes )>

Calls C<init_at_startup()> on each class in
C<\@action_classes>. Catches any exceptions thrown and logs them but
continues with the process. A class is considered successfully
initialized if it doesn't throw an exception.

Returns: Arrayref of all classes successfully initialized.

B<initialize_observers()>

Initializes the filter observers from the server and packages (see
L<OpenInteract2::Filter|OpenInteract2::Filter>), reads the
configuration observers from the server and packages (see
L<OpenInteract2::Config::Initializer|OpenInteract2::Config::Initializer>).

Returns: nothing

B<read_spops_config()>

Reads in all available SPOPS class configurations from all installed
packages. When we read in each configuration we perform a few
additional tasks (most of them done in
L<OpenInteract2::SPOPS|OpenInteract2::SPOPS> and
L<OpenInteract2::SPOPS::DBI|OpenInteract2::SPOPS::DBI>.

=over 4

=item *

Put the name of the SPOPS configuration into the key 'key'

=item *

Copy the package name and version into the action using the keys
'package_name' and 'package_version'.

=item *

Copy the filename from which we read the information into the key
'config_file'.

=item *

Modify the 'isa' field depending on whether the 'use_security' key is
set to 'yes'

=item *

Modify the 'isa' field based on the datasource used.

=item *

Modify the 'creation_security' field to resolve group names into the
ID values. (For instance, you can use 'site_admin_group' as an
identifier and it will resolve to the ID found in the server
configuration key 'default_objects.site_admin_group'.)

=back

Returns: Hashref with SPOPS configuration information in all packages.

B<activate_spops_process()>

Extremely thin wrapper around L<SPOPS::Initialize|SPOPS::Initialize>
which does all the work toward creating and initializing SPOPS classes.

Returns: Arrayref of SPOPS classes properly read and initialized.

B<initialize_controller()>

Reads in all controllers from server configuration and registers them
with L<OpenInteract2::Controller|OpenInteract2::Controller>.

B<initialize_content_generator()>

Just call
L<OpenInteract2::ContentGenerator::OpenInteract2::ContentGenerator>-E<gt>initialize().

B<create_cache()>

Create a cache object based on the server configuration. The cache
information is held in C<cache>, and if the C<use> property
of that is not a true value, we do not do anything. Otherwise we
C<require> the C<class> property of the cache information and then
call C<new()> on it, returning the cache object.

Returns: L<OpenInteract2::Cache|OpenInteract2::Cache>-derived object.

B<require_module( \%params )>

Does a C<require> on one or more modules. The modules to be read in
can be specified in the parameter 'class' or they can be in a
filename named in 'filename', one per line.

=head1 SEE ALSO

L<OpenInteract2::Context|OpenInteract2::Context>

L<OpenInteract2::Config|OpenInteract2::Config>

L<OpenInteract2::Config::Base|OpenInteract2::Config::Base>

L<SPOPS::Initialize|SPOPS::Initialize>

=head1 COPYRIGHT

Copyright (c) 2001-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
