package OpenInteract2::Setup;

# $Id: Setup.pm,v 1.15 2003/06/11 02:43:31 lachoy Exp $

use strict;
use Data::Dumper            qw( Dumper );
use File::Copy              qw( cp );
use File::Basename          qw();
use File::Path              qw();
use OpenInteract2::Config;
use OpenInteract2::Config::Base;
use OpenInteract2::ContentGenerator;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( DEBUG LOG CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Package;
use OpenInteract2::Repository;
use OpenInteract2::Util;
use SPOPS::Initialize;

$OpenInteract2::Setup::VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_TEMP_LIB_DIR => 'templib';

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
    my $base_config = CTX->base_config;
    my $lib_dir = $base_config->temp_lib_dir || DEFAULT_TEMP_LIB_DIR;

    my $full_temp_lib_dir = File::Spec->catdir(
                                $base_config->website_dir, $lib_dir );
    unshift @INC, $full_temp_lib_dir;

    # TODO: global_attribute???
    my $create_option = $params->{temp_lib_create};
    if ( -d $full_temp_lib_dir and $create_option ne 'create' ) {
        DEBUG && LOG( LINFO, "Temp lib dir [$full_temp_lib_dir] exists; ",
                      "option is not 'create' so modules not copied" );
        return [];
    }

    if ( -d $full_temp_lib_dir ) {
        my $num_removed = File::Path::rmtree( $full_temp_lib_dir );
        unless ( $num_removed ) {
            oi_error "Tried to remove directory [$full_temp_lib_dir] but ",
                     "no directories removed. Please check permissions.";
        }
    }
    eval { mkdir( $full_temp_lib_dir, 0777 ) || die $! };
    if ( $@ ) {
        oi_error "Failed to create directory [$full_temp_lib_dir]: $@";
    }

    my $packages = CTX->packages;
    unless ( ref $packages eq 'ARRAY' and scalar @{ $packages } ) {
        oi_error "Property 'packages' must be set in context";
    }

    my ( @all_files );
    foreach my $package ( @{ $packages } ) {
        DEBUG && LOG( LDEBUG, "Trying to copy files for package ",
                      $package->name );
        my $package_dir = $package->directory;
        my $module_files = $package->get_module_files;
        foreach my $module_file_spec ( @{ $module_files } ) {
            my $source_file = File::Spec->catfile( $package_dir,
                                                   @{ $module_file_spec } );
            my $dest_file   = File::Spec->catfile( $full_temp_lib_dir,
                                                   @{ $module_file_spec } );
            my $dest_path = File::Basename::dirname( $dest_file );
            File::Path::mkpath( $dest_path, undef, 0777 );

            eval { cp( $source_file, $dest_file ) || die $! };
            if ( $@ ) {
                oi_error "When creating temporary library, failed to ",
                         "copy [$source_file] to [$dest_file]: $@";
            }
            push @all_files, $dest_file;
        }
    }
    DEBUG && LOG( LDEBUG, "Copied ", scalar @all_files, " modules ",
                  "to [$full_temp_lib_dir]" );
    return \@all_files;
}

########################################
# SESSIONS

sub require_session_classes {
    my ( $self, $session_config ) = @_;
    my @session_classes = ( $session_config->{class},
                            $session_config->{impl_class} );
    return $self->require_module({ class => \@session_classes });
}


########################################
# ACTION TABLE

# Scan all the actions from all the packages and build the action
# table, plugging in defaults from 'action_info->default' where
# appropriate

sub read_action_table {
    my ( $self ) = @_;

    # Grab the default action info from the server config. The local
    # action default info takes precedence, then this

    my $server_config = CTX->server_config;
    my $global_defaults = $server_config->{action_info}{default};

    # This will become the action table

    my %ACTION = ();

    my $packages = CTX->packages;
    foreach my $package ( @{ $packages } ) {
        my $package_id = join( '-', $package->name, $package->version );
        DEBUG && LOG( LDEBUG, "Reading action data from $package_id" );
        my $filenames = $package->get_action_files;
ACTIONFILE:
        foreach my $action_file ( @{ $filenames } ) {
            DEBUG && LOG( LDEBUG, "Action file: $action_file" );
            my $full_action_path = $package->find_file( $action_file );
            my $action_ini = eval {
                OpenInteract2::Config::Ini->new(
                                   { filename => $full_action_path });
            };
            if ( $@ ) {
                LOG( LERROR, "Failed to read [$full_action_path]: $@" );
                next ACTIONFILE;
            }
            foreach my $action_name ( $action_ini->main_sections ) {
                if ( $ACTION{ $action_name } ) {
                    # TODO: Throw an exception if this happens?
                    LOG( LALL, "WARNING - Multiple actions defined for the ",
                         "same name [$action_name]. Overwriting data from ",
                         "[$ACTION{ $action_name }->{package_name}]" );
                    delete $ACTION{ $action_name };
                }
                my $action_assign =
                    $self->_assign_action_info( $action_name,
                                                $action_ini->{ $action_name },
                                                $global_defaults );

                # Set the package name/version this action came from
                $action_assign->{package_name}    = $package->name;
                $action_assign->{package_version} = $package->version;
                $action_assign->{config_file}     = $full_action_path;
                $ACTION{ $action_name } = $action_assign;
            }
        }
    }
    return \%ACTION;
}

sub _assign_action_info {
    my ( $self, $action_name, $action_info, $global_defaults ) = @_;
    my %assign = ();

    # First put the action name inside the action definition

    $assign{name} = $action_name;

    # Then copy over all the action info

    while ( my ( $action_item, $action_value ) =
                              each %{ $action_info } ) {
        $assign{ $action_item } = $action_value;
    }

    # Assign default values; note that we only write the value if the
    # key does not exist -- key existing is a sign the author wanted
    # to override with a blank value

    while ( my ( $action_item, $action_value ) =
                              each %{ $global_defaults } ) {
        next if ( exists $assign{ $action_item } );
        $assign{ $action_item } = $action_value;
    }

    # Translate verbose security levels into SPOPS::Secure constants

    if ( ref $action_info->{security} eq 'HASH' ) {
        foreach my $task ( keys %{ $action_info->{security} } ) {
            my $task_security = uc $action_info->{security}{ $task };
            if ( $task_security =~ /^(NONE|SUMMARY|READ|WRITE)$/ ) {
                $task_security =
                    OpenInteract2::Util->verbose_to_level( $task_security );
            }
            $action_info->{security}{ $task } = int( $task_security );
        }
    }

    return \%assign;
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
# SPOPS

sub read_spops_config {
    my ( $self ) = @_;
    my $server_config = CTX->server_config;

    # This will become the full SPOPS config

    my %SPOPS = ();

    my $packages = CTX->packages;
    foreach my $package ( @{ $packages } ) {
        my $package_id = join( '-', $package->name, $package->version );
        DEBUG && LOG( LDEBUG, "Reading SPOPS data from $package_id" );
        my $filenames = $package->get_spops_files;

SPOPSFILE:
        foreach my $spops_file ( @{ $filenames } ) {
            DEBUG && LOG( LDEBUG, "SPOPS file: $spops_file" );
            my $full_spops_path = $package->find_file( $spops_file );
            my $spops_ini = eval {
                OpenInteract2::Config::Ini->new({ filename => $full_spops_path });
            };
            if ( $@ ) {
                LOG( LERROR, "Failed to read [$full_spops_path]: $@" );
                next SPOPSFILE;
            }

            foreach my $spops_key ( $spops_ini->main_sections ) {
                if ( $SPOPS{ $spops_key } ) {
                    # TODO: Throw an exception if this happens?
                    LOG( LALL, "WARNING - Multiple SPOPS objects defined ",
                         "with the same key [$spops_key]. Overwriting data",
                         "from [$SPOPS{ $spops_key }->{package_name}]" );
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

                $self->_modify_spops_config_by_datasource( \%spops_assign );
                $SPOPS{ $spops_key } = \%spops_assign;
            }
        }
    }
    return \%SPOPS;
}


# TODO: Datasource stuff probably isn't necessary anymore with the
# global config, but we might want to keep the datasource-only
# configuration. (Easier for users.)

# Set the @ISA for the class based on the datasource, security,
# etc. Note that this is done before the normal SPOPS behavior factory
# stuff kicks in, since we haven't started generating classes yet...

sub _modify_spops_config_by_datasource {
    my ( $self, $spops_config ) = @_;
    my $server_config = CTX->server_config;
    my $ds_name = $spops_config->{datasource}
                  || $server_config->{datasource_config}{spops};
    my $ds_info = $server_config->{datasource}{ $ds_name };
    my $ds_type_info = $server_config->{datasource_type}{ $ds_info->{type} };
    my $ds_config_handler = $ds_type_info->{spops_config};
    $ds_config_handler->modify_spops_config( $spops_config );
}


sub activate_spops_classes {
    my ( $self, $spops_config ) = @_;
    $spops_config ||= CTX->spops_config;
    return SPOPS::Initialize->process({ config => $spops_config });
}


########################################
# DATASOURCES

sub check_datasources {
    my ( $self ) = @_;
    my $server_config = CTX->server_config;
    while ( my ( $ds_name, $ds_info ) =
                        each %{ $server_config->{datasource} } ) {
        unless ( ref $ds_info eq 'HASH' ) {
            oi_error "Datasource [$ds_name] does have its configuration ",
                     "defined in the server configuration.";
        }
        my $ds_type_info = $server_config->{datasource_type}{ $ds_info->{type} };
        unless ( ref $ds_type_info eq 'HASH' ) {
            oi_error "Datasource type [$ds_info->{type}] defined in ",
                     "datasource [$ds_name] but no type information ",
                     "defined in the server config under ",
                     "'datasource_type.$ds_info->{type}'";
        }
        my $ds_config_handler = $ds_type_info->{spops_config};
        eval "require $ds_config_handler";
        if ( $@ ) {
            oi_error "Could not include module [$ds_config_handler] ",
                     "to handle SPOPS configuration information: $@";
        }
    }
}


########################################
# ALIASES

# This is different than 1.x -- SPOPS classes don't get automatic
# aliases. So we're just scanning the contents of the 'system_alias'
# key in the server config object.

sub read_aliases {
    my ( $self ) = @_;
    my $server_config = CTX->server_config;
    unless ( ref $server_config->{system_alias} eq 'HASH' ) {
        LOG( LALL, "There are no system aliases defined. This is ",
                   "probably a very bad thing." );
        return {};
    }
    my %aliases = ();
    while ( my ( $alias, $to_class ) =
                      each %{ $server_config->{system_alias} } ) {
        $aliases{system}->{ $alias } = $to_class;
    }
    return \%aliases;
}


########################################
# CONTENT GENERATORS

sub initialize_content_generator {
    my ( $self ) = @_;
    OpenInteract2::ContentGenerator->initialize;
}


########################################
# CACHE

sub create_cache {
    my ( $self ) = @_;
    my $server_config = CTX->server_config;
    my $cache_info = $server_config->{cache_info};
    unless ( $cache_info->{use} ) {
        DEBUG && LOG( LDEBUG, "Cache not configured for usage" );
        return undef;
    }
    my $cache_class = $cache_info->{class};
    DEBUG && LOG( LDEBUG, "Creating cache with class [$cache_class]" );
    eval "require $cache_class";
    if ( $@ ) {
        LOG( LERROR, "Cannot create cache -- error including cache class",
             "[$cache_class]: $@" );
        return undef;
    }
    my $cache = $cache_class->new();
    DEBUG && LOG( LDEBUG, "Cache setup ok" );
    return $cache;
}


########################################
# REQUIRE MULTIPLE MODULES

sub require_module {
    my ( $class, $params ) = @_;
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
            LOG( LALL, sprintf( "require error: %-40s: %s", $in_class, $@ ) );
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
 # Perl modules from the packages used.
 
 my $copied = $setup->create_temp_lib;
 print "Files copied to temp library: ", join( ", ", @{ $copied } );
 
 # Same thing, except only copy modules if the temp lib doesn't exist
 
 CTX->global_attribute( temp_lib_create => 'lazy' );
 my $copied = $setup->create_temp_lib;
 
 # Build the action table and bring in the necessary classes
 
 my $actions = $setup->read_action_table();
 print "Actions in server: ", join( ", ", @{ $actions } );
 my $modules = $setup->require_action_classes( $actions );
 
 # Read the SPOPS configuration and build all the SPOPS classes
 
 my $spops_config = $setup->read_spops_config();
 print "SPOPS object aliases: ", join( ", ", @{ $aliases } );
 my $classes = $setup->activate_spops_classes( $spops_config );
 
 # Build system aliases
 
 my $sys_aliases = $setup->build_aliases;
 
 # Require a bunch of mdules at once
 
 my $required = $setup->require_modules({
                                        class => \@class_list });
 my $required = $setup->require_modules({
                                        filename => 'apache_modules.dat' });
 
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

B<create_temp_dir()>

Copies all .pm files from all packages in a website to a temporary
library directory. If the 'lazy' global attribute in the context is
true and the directory exists, the action will not be performed.

The context must have the packages set before this is run, otherwise
an exception is thrown.

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

B<require_action_classes()>

Scans through all the actions and performs a 'require' on all
referenced classes.

Returns: Arrayref of all classes successfully required.

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

B<read_aliases()>

Just read in all the aliases from the server configuration and return
them based on type. Currently this just reads in all aliases under
'system_aliases' and returns them under the type 'system'.

Returns: hashref of typed aliases.

Example:

 my $aliases = $setup->read_aliases;
 foreach my $type ( keys %{ $aliases } ) {
     while ( my ( $alias, $alias_to ) = each %{ $aliases->{ $type } } ) {
         CTX->alias( $type, $alias, $alias_to );
     }
 }

B<initialize_content_generator()>

Just call
L<OpenInteract2::ContentGenerator::OpenInteract2::ContentGenerator>-E<gt>initialize().

B<create_cache()>

Create a cache object based on the server configuration. The cache
information is held in C<cache_info.data>, and if the C<use> property
of that is not a true value, we do not do anything. Otherwise we
C<require> the C<class> property of the cache information and then
call C<new()> on it, returning the cache object.

Returns: L<OpenInteract2::Cache|OpenInteract2::Cache>-derived object.

B<require_module( \%params )>

Does a C<require> on one or more modules. The modules to be read in
can be specified in the parameter 'class' or they can be in a
filename named in 'filename', one per line.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::Context|OpenInteract2::Context>

L<OpenInteract2::Config|OpenInteract2::Config>

L<OpenInteract2::Config::Base|OpenInteract2::Config::Base>

L<SPOPS::Initialize|SPOPS::Initialize>

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
