package OpenInteract::Startup;

# $Id: Startup.pm,v 1.3 2001/02/20 04:12:32 lachoy Exp $

use strict;
use Data::Dumper qw( Dumper );
use OpenInteract::Error;
use OpenInteract::Package;
use OpenInteract::PackageRepository;

@OpenInteract::Startup::ISA     = ();
$OpenInteract::Startup::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

my $REPOS_CLASS = 'OpenInteract::PackageRepository';
my $PKG_CLASS   = 'OpenInteract::Package';

sub main_initialize {
  my ( $class, $p ) = @_;

  # Ensure we can find the base configuration, and use it or read it in

  return undef unless ( $p->{base_config} or $p->{base_config_file} );
  my $bc = $p->{base_config} || 
           $class->read_base_config({ filename => $p->{base_config_file} });

  # Create our main config object

  my $C = $class->create_config({ base_config  => $bc });

  # Initialize OpenInteract::Package -- it's a SPOPS class, but it's
  # different from the rest in that we actually *use* it to create the
  # other classes/modules (bootstrapping thing)

  $REPOS_CLASS->class_initialize( $C );

  # Read in our fundamental modules -- these should be in our @INC
  # already, since the 'request_class' is in 'OpenInteract/OpenInteract'
  # and the 'stash_class' is in 'MyApp/MyApp'

  $class->require_module({ class => [ $bc->{request_class}, $bc->{stash_class} ] });

  # Either use a package list provided or read in all the packages from
  # the website package database

  my $packages = [];
  my $repository = $REPOS_CLASS->fetch( undef, { directory => $bc->{website_dir} } );
  if ( my $package_list = $p->{package_list} ) {
    foreach my $pkg_name ( @{ $p->{package_list} } ) {
      my $pkg_info = $repository->fetch_pacakge_by_name({ name => $pkg_name });
      push @{ $packages }, $pkg_info  if ( $pkg_info );
    }
  }
  else {
    $packages = $repository->fetch_all_packages();
  }

  # We keep track of the package names currently installed and use them
  # elsewhere in the system

  $C->{package_list} = [ map { $_->{name} } @{ $packages } ];
  my %require_class = ();
  foreach my $pkg_info ( @{ $packages } ) {
    my $pkg_require_list = $class->process_package( $pkg_info, $C );
    foreach my $pkg_require_class ( @{ $pkg_require_list } ) {
      $require_class{ $pkg_require_class } = $pkg_info->{name};
    }
  }

  my $successful = $class->require_module({ 
                               class => [ keys %require_class ],
					           pkg_link =>  \%require_class });
  if ( scalar @{ $successful } != scalar keys %require_class ) {
    warn " (Startup/main_initialize): Some classes were not required!\n";
  }

  # The config object should now have all actions and SPOPS definitions 
  # read in, so run any necessary configuration options
  
  my $init_class = $class->finalize_configuration({ config => $C });

  # Store the configuration for later use
  
  my $stash_class = $bc->{stash_class};
  $stash_class->set_stash( 'config', $C );

  # Tell OpenInteract::Request to setup aliases if they haven't already

  my $request_class = $bc->{request_class};
  if ( $p->{alias_init} ) { 
    $request_class->setup_aliases;
  }

 # Initialize all the SPOPS object classes

  if ( $p->{spops_init} ) { 
    $class->initialize_spops({ config => $C, class => $init_class });
  }

 _w( 2, "Contents of INC: @INC" );

  # All done! Return the configuration object so the user can
  # do whatever else is necessary

  return ( $init_class, $C );
}

# Use this if you want to setup the OpenInteract environment outside
# of the web application server -- just pass in the website directory!

sub setup_static_environment {
  my ( $class, $website_dir ) = @_;
  die "Directory ($website_dir) is not a valid directory!\n" unless ( -d $website_dir );

  my $bc = $class->read_base_config({ dir => $website_dir });

  unshift @INC, $website_dir;
  my ( $init, $C ) = $class->main_initialize({ 
                                 base_config => $bc,
                                 alias_init => 1,
                                 spops_init => 1 });
  
  my $REQUEST_CLASS = $C->{request_class};
  my $R = $REQUEST_CLASS->instance;

  $R->{stash_class} = $C->{stash_class};
  $R->stash( 'config', $C );

  my $dbh = OpenInteract::DBI->connect( $C->{db_info} );
  $R->stash( 'db', $dbh );
  
  return $R;
}



# Slimmed down initialization procedure -- just do everything
# necessary to read the config and set various values there

sub create_config {
  my ( $class, $p ) = @_;
  return undef unless ( $p->{base_config} or $p->{base_config_file} );
  my $bc = $p->{base_config} || 
           $class->read_base_config({ filename => $p->{base_config_file} });

  # Create the configuration file and set the base directory as configured;
  # also set other important classes from the config

  my $config_file  = join( '/', $bc->{website_dir}, $bc->{config_dir}, $bc->{config_file} );
  my $config_class = $bc->{config_class};
  $class->require_module({ class => [ $config_class ] });
  my $C = eval { $config_class->instance( $config_file ); };
  if ( $@ ) {
    my $ei = OpenInteract::Error->get;
    die "Cannot read configuration file! Error: $ei->{system_msg}\n";
  }

  # This information will be set for the life of the config object,
  # which should be as long as the apache child is alive if we're using
  # mod_perl, and will be set in the returned config object in any case

  $C->{dir}->{base}      = $bc->{website_dir};
  $C->{dir}->{interact}  = $bc->{base_dir};
  $C->{request_class}    = $bc->{request_class};
  $C->{stash_class}      = $bc->{stash_class};
  $C->{website_name}     = $bc->{website_name};
  return $C;
}



sub read_package_list {
  my ( $class, $p ) = @_;
  return [] unless ( $p->{filename} or $p->{config} );
  my $filename = $p->{filename} || 
                 join( '/', $p->{config}->get_dir( 'config' ), $p->{config}->{package_list} );
  open( PKG, $filename ) || die "Cannot open package list ($filename): $!"; 
  my @packages = ();
  while ( <PKG> ) {
    chomp;
    next if /^\s*\#/;
    next if /^\s*$/;
    s/^\s*//; 
    s/\s*$//; 
    push @packages, $_;   
  }
  close( PKG );
  return \@packages;
}



# simple key-value config file

sub read_base_config {
  my ( $class, $p ) = @_;
  unless ( $p->{filename} ) {
    if ( $p->{dir} ) {
      $p->{filename} = $class->create_base_config_filename( $p->{dir} );
    }
  }
  return undef   unless ( -f $p->{filename} );
  open( CONF, $p->{filename} ) || die "$!\n";
  my $vars = {};
  while ( <CONF> ) {
    chomp;
    _w( 1, "Config line read: $_" );
    next if ( /^\s*\#/ );
    next if ( /^\s*$/ );
    s/^\s*//;
    s/\s*$//;
    my ( $var, $value ) = split /\s+/, $_, 2;
    $vars->{ $var } = $value;
  }
  return $vars;
}

sub create_base_config_filename {
 my ( $class, $dir ) = @_;
 return join( '/', $dir, 'conf', 'base.conf' );
}

# Params:
#  filename - file with modules to read, one per line (skip blanks, commented lines)
#  class    - arrayref of classes to require
# (pick one)

sub require_module {
  my ( $class, $p ) = @_;
  my @success = ();
  if ( $p->{filename} ) {
    _w( 1, "Trying to open file $p->{filename}" );
    return [] unless ( -f $p->{filename} );
    open( MOD, $p->{filename} ) || die "Cannot open $p->{filename}: $!";
    while ( <MOD> ) {
      next if ( /^\s*$/ );
      next if ( /^\s*\#/ );
      chomp;
      _w( 1, "Trying to require $_" );
      eval "require $_";
      if ( $@ ) { _w( 0, sprintf( " --require error: %-40s: %s", $_, $@ ) )  }
      else      { push @success, $_ }
    }
    close( MOD );
  }
  elsif ( ref $p->{class} ) {
    foreach ( @{ $p->{class} } ) {
      _w( 1, "Trying to require class ($_)" );
      eval "require $_";
      if ( $@ ) { _w( 0, sprintf( " --require error%-40s (from %s): %s", $_, $p->{pkg_link}->{$_}, $@ ) ) }
      else      { push @success, $_ }
    }
  }
  return \@success;
}



# Params:
#  config = config object
#  package = name of package
#  package_dir = arrayref of base package directories (optional, read from config if not passed)

sub process_package {
  my ( $class, $pkg_info, $CONF ) = @_;
  return undef unless ( $pkg_info );
  return undef unless ( $CONF );

  my $pkg_name = join( '-', $pkg_info->{name}, $pkg_info->{version} );
  _w( 1, "Trying to process package ($pkg_name)" );

  # Note that app dir should be set earlier in the @INC list then the
  # base dir, since the app can override base

  my @package_dir_list = $PKG_CLASS->add_to_inc( $pkg_info );
  _w( 1, "Included @package_dir_list for $pkg_name" );

  # If we cannot find even one package directory, bail

  unless ( scalar @package_dir_list ) {
    _w( 0, "No package directories found for $pkg_name: was it installed correctly?" ); 
    return undef;
  }

  # Now we want the app dir to be *last*, so reverse the order

  @package_dir_list = reverse @package_dir_list;

  # Plow through the directories and find the module listings (to
  # include), action config (to parse and set) and the SPOPS config (to
  # parse and set)

  my ( %spops, %action );
  foreach my $package_dir ( @package_dir_list ) {
    my $conf_pkg_dir = "$package_dir/conf";
    
    # If the package does not have a 'list_module.dat', that's ok and the
    # 'require_module' class method will simply return an empty list.
    
    $class->require_module({ filename => "$conf_pkg_dir/list_module.dat" });

    # Read in the 'action' information and set in the config object
    
    my @action_tag_list = $class->read_action_definition({ 
                                       filename => "$conf_pkg_dir/action.perl",
                                       config => $CONF,
                                       package => $pkg_info });
    foreach my $action_tag ( @action_tag_list ) {
      $action{ $action_tag }++  if ( $action_tag );
    }

    # Read in the SPOPS information and set in the config object; note
    # that we cannot *process* the SPOPS config yet because we must be
    # able to relate SPOPS objects, which cannot be done until all the
    # definitions are read in. (Yes, we could use 'map' here and above,
    # but it's confusing to people first reading the code)
    
    my @spops_tag_list = $class->read_spops_definition({
                                      filename => "$conf_pkg_dir/spops.perl",
                                      config => $CONF,
                                      package => $pkg_info });
    foreach my $spops_tag ( @spops_tag_list ) {
      $spops{ $spops_tag }++  if ( $spops_tag );
    }
  }

  # Now find all the classes (from both the action list and the spops
  # list) required for this package and return them to the caller

  my ( @class_list );
  foreach my $action_key ( keys %action ) {
    next unless ( $action_key );
    my $action_info = $CONF->{action}->{ $action_key };
    if ( $action_info->{class} ) {
      push @class_list, $action_info->{class};
    }
    if ( ref $action_info->{error} eq 'ARRAY' ) {
      push @class_list, @{ $action_info->{error} };
    }   
  }
  
  foreach my $spops_key ( keys %spops ) {
    next unless ( $spops_key );
    my $spops_info = $CONF->{SPOPS}->{ $spops_key };
    if ( ref $spops_info->{isa} eq 'ARRAY' ) {
      push @class_list, @{ $spops_info->{isa} };
    }
  }
  return \@class_list;
}



# Read in the action config info and set the information in the CONFIG
# object. note that we overwrite whatever information is in the CONFIG
# object -- this is a feature, not a bug, since it allows the base
# installation to define lots of information and the website to only
# override what it needs.

sub read_action_definition {
  my ( $class, $p ) = @_;
  _w( 1, "Reading action definitions from ($p->{filename})" );

  # $CONF is easier to read and more consistent
  my $CONF = $p->{config}; 
  my $action_info = eval { $class->read_perl_file({ filename => $p->{filename} }) };
  return undef  unless ( $action_info );
  my @class_list = ();
  foreach my $action_key ( keys %{ $action_info } ) {
    foreach my $action_conf ( keys %{ $action_info->{ $action_key } } ) {
      $CONF->{action}->{ $action_key }->{ $action_conf } = $action_info->{ $action_key }->{ $action_conf };
    }
    if ( ref $p->{package} ) {
      $CONF->{action}->{ $action_key }->{package_name}    = $p->{package}->{name};
      $CONF->{action}->{ $action_key }->{package_version} = $p->{package}->{version};
    }
  }
  return keys %{ $action_info };
}



# See comments in read_action_definition

sub read_spops_definition {
  my ( $class, $p ) = @_;
  _w( 1, "Reading SPOPS definitions from ($p->{filename})" );

  # $CONF is easier to read and more consistent
  my $CONF = $p->{config}; 
  my $spops_info = eval { $class->read_perl_file({ filename => $p->{filename} }) };
  return undef unless ( $spops_info );
  my @class_list = ();
  foreach my $spops_key ( keys %{ $spops_info } ) {
    foreach my $spops_conf ( keys %{ $spops_info->{ $spops_key } } ) {
      $CONF->{SPOPS}->{ $spops_key }->{ $spops_conf } = $spops_info->{ $spops_key }->{ $spops_conf };
    }
    if ( ref $p->{package} ) {
      $CONF->{SPOPS}->{ $spops_key }->{package_name}    = $p->{package}->{name};
      $CONF->{SPOPS}->{ $spops_key }->{package_version} = $p->{package}->{version};
    }
  }
  return keys %{ $spops_info };
}


# Read in a perl structure (probably generated by Data::Dumper) from a
# file and return the actual structure. We should probably use
# SPOPS::HashFile for this for consistency...

sub read_perl_file {
  my ( $class, $p ) = @_;
  return undef unless ( -f $p->{filename} );
  eval { open( INFO, $p->{filename} ) || die $! };
  if ( $@ ) {
    warn "Cannot open config file for evaluation ($p->{filename}): $@ ";
    return undef;
  }
  local $/ = undef;
  no strict;
  my $info = <INFO>;
  close( INFO );
  my $data = eval $info;
  _w( 0, "Cannot read data structure! from $p->{filename}\nError: $@" ) if ( $@ );
  return $data;
}


# Everything has been read in, now just finalize aliases and so on

sub finalize_configuration {
  my ( $class, $p ) = @_;
  my $CONF = $p->{config};
  my $SPOPS_CONFIG_CLASS = $CONF->{SPOPS_config_class};
  my $REQUEST_CLASS      = $CONF->{request_class};
  my $STASH_CLASS        = $CONF->{stash_class};

  # Create all the packages and subroutines on the fly as necessary

  _w( 1, "Trying to parse with $SPOPS_CONFIG_CLASS" );
  my $init_class = $SPOPS_CONFIG_CLASS->process_config({ 
                                            config => $CONF->{SPOPS} });

  # Setup the default responses, template classes, etc. for all
  # the actions read in.

  $CONF->flatten_action_config;
  _w( 2, "Config: \n", Dumper( $CONF ) );
  _w( 1, "Configuration read into Request ok." );
  
  # We also want to go through each alias in the 'SPOPS' config key
  # and setup aliases to the proper class within our Request class; so
  # $request_alias is just a reference to where we'll actually be storing
  # this stuff

  my $request_alias = $REQUEST_CLASS->ALIAS;
  _w( 1, "Setting up SPOPS aliases" );
  foreach my $init_alias ( keys %{ $CONF->{SPOPS} } ) {
    next if ( $init_alias =~ /^_/ );
    my $info        = $CONF->{SPOPS}->{ $init_alias };
    my $class_alias = $info->{class};
    my @alias_list  = ( $init_alias );
    push @alias_list, @{ $info->{alias} } if ( $info->{alias} );
    foreach my $alias ( @alias_list ) {
      _w( 1, "Tag $alias in $STASH_CLASS to be $class_alias" );
      $request_alias->{ $alias }->{ $STASH_CLASS } = $class_alias;
    }
  }
 
  _w( 1, "Setting up System aliases" );
  foreach my $sys_class ( keys %{ $CONF->{system_alias} } ) {
    next if ( $sys_class =~ /^_/ );
    foreach my $alias ( @{ $CONF->{system_alias}->{ $sys_class } } ) {
      _w( 1, "Tagging $alias in $STASH_CLASS to be $sys_class" );
      $request_alias->{ $alias }->{ $STASH_CLASS } = $sys_class;
    }
  }
  _w( 1, "Setup object and system aliases ok" );
  return $init_class;
}


# Plow through a list of classes and call the class_initialize
# method on each; ok to call OpenInteract::Startup->initialize_spops( ... )
# from the mod_perl child init handler

sub initialize_spops {
  my ( $class, $p ) = @_;
  return undef unless ( ref $p->{class} );
  return undef unless ( ref $p->{config} );
  my @success = ();

 # Just cycle through and initialize each

  foreach my $spops_class ( @{ $p->{class} } ) {
    eval { $spops_class->class_initialize( $p->{config} ); };
    push @success, $spops_class unless ( $@ );
    _w( 1, sprintf( "%-40s: %-30s","init: $spops_class", ( $@ ) ? $@ : 'ok' ) );
  }
  return \@success;
}



sub _w {
  return unless ( DEBUG >= shift );
  my ( $pkg, $file, $line ) = caller;
  my @ci = caller(1);
  warn "$ci[3] ($line) >> ", join( ' ', @_ ), "\n";
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Startup -- Bootstrapper that reads in modules, manipulates @INC, etc.

=head1 SYNOPSIS


 # Startup an OpenInteract environment outside Apache and mod_perl

 use strict;
 use OpenInteract::Startup;

 my $R =  OpenInteract::Startup->setup_static_environment( 
                                      '/home/httpd/MySite' );

 # For usage inside Apache/mod_perl, see OpenInteract::ApacheStartup

=head1 DESCRIPTION

This module has a number of routines that are (hopefully) independent
of the OpenInteract implementation. One of its primary goals is to
make it simple to initialize OpenInteract not only in a mod_perl
context but also a single-use context. For example, when you create a
script to be run as a cron job to do some sort of data checking (or
whatever), you should not be required to put 50 lines of
initialization in your script just to create the framework.

This script should also minimize the modules you have to include
yourself, making it easier to add backward-compatible
functionality. Most of the time, you only need to have a 'use'
statement for this module which takes care of everything else.

=head1 METHODS

All methods use the class method invocation syntax, such as:

 OpenInteract::Startup->require_module( { class => [ $my_class ] } );

B<main_initialize( \%params )>

This will frequently be the only method you call of this class. This
routine goes through a number of common steps:

=over 4

=item 1.

read in the base configuration file

=item 2.

require the config class, request class and stash class

=item 3.

create the config object

=item 4.

process all packages (see L<process_package()> below)

=item 5.

finalize the configuration (see L<finalize_configuration()> below

=item 6.

set the config object into the stash class

=item 7.

create aliases in the request object (optional)

=item 8.

create/initialize all SPOPS object classes (optional)

=back

The return value is a list with two members. The first is an arrayref
of all SPOPS object class names that currently exist. The second is a
fully setup I<OpenInteract::Config> object. Note that his may change in
the future to be a single return value of the config object with the
class names included as a parameter of it.

Parameters:

You B<must> pass in either 'base_config' or 'base_config_file'.

 base_config (\%)
   A hashref with the information from the base configuration file

 base_config_file ($)
   A filename where the base configuration can be found

 alias_init (bool) (optional) 
   A true value will initialize aliases within the request class; the
   default is to not perform the initialization.

 spops_init (bool) (optional)
   A true value will create/initialize all SPOPS classes (see
   SPOPS::Configure for more information); the default is to not
   perform the initialization.

 package_extra (\@) (optional)
   A list of packages not included in the filename of packages to read
   in but you want to include anyway (maybe you are testing a new
   package out). The packages included will be put at the end of the
   packages to be read in, although it is feasible that we break this
   into two extra package listings -- those to be read in before
   everything else (but still after 'base') and those to be read in
   after everything else. See if there is a need...

B<setup_static_environment( $website_dir )>

Sometimes you want to setup OI even when you are not in a web
environment -- for instance, you might need to do data reporting, data
import/export, or other tasks.

With this method, all you need to pass in is the root directory of
your website. It will deal with everything else, including:

=over 4

=item *

Reading in the server configuration

=item *

Reading in all SPOPS and action table configurations -- this includes
setting up @INC properly.

=item *

Setting up all aliases -- SPOPS object and otherwise

=item *

Creating a database handle

=back

The only thing it does not do is setup an authentication environment
for you -- to get around this (right now), you need to pass in a true
value for 'skip_log' and 'skip_security' whenever you modify and/or
retrieve objects.

Returns: A "fully-stocked" C<OpenInteract::Request> object.

Example:

 #!/usr/bin/perl

 use strict;
 use OpenInteract::Startup;

 my $R = OpenInteract::Startup->setup_static_environment( '/home/httpd/my' );

 my $news_list = eval { $R->news->fetch_group({ 
                               where => 'title like ?',
                               value => [ '%iraq%' ],
                               skip_security => 1 }) };
 foreach my $news ( @{ $news_list } ) {
   print "Date:  $news->{posted_on}\n",
         "Title: $news->{title}\n"
         "Story: $news->{news_item}\n";
 }

Easy!

B<read_package_list( \%params )>

Reads in a list of packages from a file, one package per line.

Returns: arrayref of package names.

Parameters:

Choose one or the other

 config
   An OpenInteract::Config object which has 'package_list' as a key; this
   file is assumed to be in the 'config' directory, also found on the
   object.

 filename
   A scalar specifying where the packages can be read from.

B<read_base_config( \%params )>

Reads in the base configuration file, which is a simple per-line
whitespace-separated key-value format.

Returns a hashref with all information.

Parameters:

 filename
   A scalar specifying where the file is located; it must have a
   fully-qualified path.

 dir
   A scalar specifying the website directory which has the file
   'conf/base.conf' under it.

B<require_module( \%params )>

Calls C<require> on one or a number of modules. You can specify a
filename composed of module names (one module per line) and all will
be read in. You can also specify a number of modules to read in.

Returns: arrayref of modules successfully read in.

Parameters:

 filename
   Name of file which has modules to read in; one module per line,
   blank lines and lines beginning with a comment (#) are skipped

 class
   Arrayref of classes to read in

B<process_package( \%params )>

Do initial work to process a particular package. This includes reading
in all external modules and reading both the action configuration and
SPOPS configuration files for inclusion in the config object. We also
include any modules used in the action definition (if you specify a
'class' in a action definition) as well as those in the 'isa' property
of a SPOPS class definition.

We also add the package directory to @INC, which means any 'use' or
'require' statements that need modules within the package will be able
to work. (See the I<OpenInteract Guide to Packages> for more
information on what goes into a package and how it is laid out.)

Note that we do B<not> create/configure the SPOPS classes yet, since
that process requires that all SPOPS classes to be used exist in the
configuration. (See L<SPOPS::Configure> for more details.)

Parameters:

 package ($)
   Name of package to be processed; this should correspond to a
   particular directory in the package directory

 config (obj)
   An OpenInteract::Config object

 package_dir (\@ - optional)
   Directories where this package might be kept; if not passed in, it
   will be found from the config object

B<read_action_definition( \%params )>

Read in a action definition file (a perl data structure) and set its
information in the config object. Multiple actions can be configured,
and we do a 'require' on any actions referenced.

Parameters:

 filename ($)
   File where the action definion is.

 config (obj)
   OpenInteract::Config object where we set the action information.

 package (\%)
   Hashref with information about a package so we can set name/version
   info.

B<read_spops_definition( \%params )>

Read in a module definition file (a perl data structure) and set its
information in the config object. Multiple SPOPS objects can be
configured, and we do a 'require' on any modules referenced.

Parameters:

 filename ($)
   File where the module definion is.

 config (obj)
   OpenInteract::Config object where we set the module information.

 package (obj)
   Hashref with information about a package so we can set name/version
   info.

B<read_perl_file( \%params )>

Simple routine to read in a file generated by or compatible with a
perl data structure and return its value. For instance, your file
could have something like the following:

 $action = {
            'boxes' => { 
                'class'     => 'OpenInteract::Handler::Boxes',
                'security'  => 'no',
            }, ...
 };

And the return value would be the hashref that C<$module> is set
to. The actual name of the variable is irrelevant, just the data
structure assigned to it.

Return value is the data structure in the file, or undef if the file
does not exist or the data structure is formatted incorrectly. If the
latter happens, check your error log (STDERR) and a warning will
appear.

Parameters:

 filename ($)
   File to read data structure from.

Note: we should modify this to use L<SPOPS::HashFile>...

B<finalize_configuration( \%params )>

At this point, all the SPOPS and module information should be read
into the configuration object and we are ready to finish up the
configuration procedure. This means call the final SPOPS
configuration, which creates classes as necessary and puts
configuration information and routines to link the objects
together. We also call the various routines in the 'request_class'
(usually OpenInteract::Request) to create necessary aliases for classes
from both SPOPS and base system elements.

Return value is an arrayref of all SPOPS classes that are
configured. Each one needs to be initialized before use, which can
handily be done for you in the C<initialize_spops> method.

Parameters:

 config (obj)
   An OpenInteract::Config configuration object. Note that the keys
   'request_class', 'SPOPS_config_class' and 'stash_class' must be
   defined in the config object prior to calling this routine.

B<initialize_spops( \%params )>

Call the C<class_initialize> method for each of the SPOPS classes
specified. This must be done before the package can be used.

Returns an arrayref of classes successfully initialized.

Parameters:

 class (\@)
   An arrayref of classes to initialize.

 config (obj)
   An OpenInteract::Config configuration object, needed by the
   C<class_initialize> method within the SPOPS classes.

=head1 TO DO

=head1 BUGS

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
