package OpenInteract::Package;

# $Id: Package.pm,v 1.50 2001/02/01 06:27:31 cwinters Exp $

use strict;
use vars qw( $PKG_DB_FILE );

use Archive::Tar       ();
use Cwd                qw( cwd );
use Data::Dumper       qw( Dumper );
use ExtUtils::Manifest ();
use File::Basename     ();
use File::Copy         qw( cp );
use File::Find         ();
use File::Path         ();
use File::Spec         ();
use SPOPS::GDBM        ();
use SPOPS::Utility     ();
use SPOPS::HashFile    ();
require Exporter;

@OpenInteract::Package::ISA       = qw( Exporter  SPOPS::Utility  SPOPS::GDBM );
$OpenInteract::Package::VERSION   = sprintf("%d.%02d", q$Revision: 1.50 $ =~ /(\d+)\.(\d+)/);
@OpenInteract::Package::EXPORT_OK = qw( $PKG_DB_FILE );

# Define our SPOPS configuration information. All should be pretty
# easy to understand, although note that 'gdbm_info' gets filled in
# when the package is initialized

$OpenInteract::Package::C        = {
   class        => 'OpenInteract::Package',
   field_list   => [ qw/ name version author url description notes dependency 
                         script_install script_upgrade script_uninstall sql_installer
                         installed_on installed_by last_updated_on last_updated_by
                         base_dir website_dir package_dir website_name / ],
   create_id    => sub { return join '-', $_[0]->{name}, $_[0]->{version} },
   display      => { url => '/Package/show/' },
   name         => sub { return join '-', $_[0]->{name}, $_[0]->{version} },
   gdbm_info    => {}, 
};
$OpenInteract::Package::RULESET  = {};

$PKG_DB_FILE = 'conf/package_install.gdbm';

sub CONFIG  { return $OpenInteract::Package::C };
sub RULESET { return $OpenInteract::Package::RULESET };

use constant DEBUG => 0;

# Define the subdirectories present in a package

my @PKG_SUBDIR        = qw( conf data doc struct template script html html/images );

# Name of the package configuration file, always found in the
# package's root directory

my $DEFAULT_CONF_FILE = 'package.conf';

# Define the keys in 'package.conf' that can be a list, meaning you
# can have multiple items defined:
#
#  author  Larry Wall <larry@wall.org>
#  author  Chris Winters <chris@cwinters.com>

my %CONF_LIST_KEYS    = map { $_ => 1 } 
                        qw( author script_install script_upgrade script_uninstall );

# Define the keys in 'package.conf' that can be a hash, meaning that
# you can have multiple items defined as key-value pairs:
#
#  dependency base_linked 1.09
#  dependency static_page 1.18

my %CONF_HASH_KEYS    = map { $_ => 1 } 
                        qw( dependency );

# For exporting a package, the following variables are required in
# 'package.conf'

my @EXPORT_REQUIRED   = qw( name version );

# Global for holding Archive::Tar errors

my $ARCHIVE_ERROR     = undef;

# Fields NOT to copy over in conf/spops.perl when creating package in
# website from base installation (the first three are ones we
# manipulate by hand)

my %SPOPS_CONF_KEEP   = map { $_ => 1 } qw( class has_a links_to);

# Normal SPOPS initialization. Called by SPOPS.pm when you do:
#
#  OpenInteract::Package->class_initialize;

sub _class_initialize { 
  my ( $class, $CONFIG ) = @_;
  my $count = 1;
  my $C = $class->CONFIG;
  $C->{field} = {};
  foreach my $field ( @{ $C->{field_list} } ) {
    $C->{field}->{ $field } = $count;
    $count++;
  }

  # Define a default package database file -- the one for the root
  # interact install

  if ( ref $CONFIG ) {
    my $default_db_file = join( '/', $CONFIG->{dir}->{interact}, $PKG_DB_FILE );
    $C->{gdbm_info}->{directory} = $CONFIG->{dir}->{interact};
    $C->{gdbm_info}->{filename}  = $default_db_file, 
  }

  # Define the 'file fragment' -- used when the user passes in a
  # directory to use

  $C->{gdbm_info}->{file_fragment} = $PKG_DB_FILE;
}



# Ensure that the base_dir, name and version properties are defined for
# this package

sub pre_save_action {
  my ( $self, $p ) = @_;
  unless ( -d $self->{base_dir} ) {
    _w( 0, "Cannot save package: the OpenInteract base installation ",
           "directory is not specified or does not exist!" );
   return undef;
  }
  unless ( $self->{name} and $self->{version} ) {
    _w( 0, "Cannot save package: both the package 'name' and 'version' ",
           "must be specified before saving.\n" );
    return undef;
  }
  return 1;
}



# Retrieves the newest package given only a name; so if there are
# three packages installed:
#
#   FirstPackage-1.14
#   FirstPackage-1.16
#   FirstPackage-1.80
#
# This method will return the last, since it's the latest (higher
# version) You can, however, pass in a version; if it matches a
# package version exactly, that gets returned; otherwise it's still
# the highest
#
# Note that you should pass in either 'directory', 'filename' or other
# SPOPS::GDBM variable used for finding a GDBM file (directory is the
# most common, since we've defined the filename we're going to use
# above)

sub fetch_by_name {
  my ( $class, $p ) = @_;
  my $name = lc $p->{name};
  delete $p->{name};
  _w( 1, "Trying to retrieve package $name" );
  my $pkg_list = $class->fetch_group( $p );
  _w( 1, "Found: ", Dumper( $pkg_list ) );
  my @match = ();
  foreach my $pkg ( @{ $pkg_list } ) {
    _w( 1, "Found package $pkg->{name}-$pkg->{version}; try to match up with package $name" );
    push @match, $pkg  if ( lc $pkg->{name} eq $name );
  }
  my $final = undef;
  my $ver   = 0;
  foreach my $pkg ( @match ) {
    if ( $pkg->{version} > $ver ) {
      $final = $pkg;
      $ver   = $pkg->{version};
    }
    _w( 1, "Current version for matching $pkg->{name}: $ver" );
    return $pkg   if ( $p->{version} and $pkg->{version} == $p->{version} );
  }
  
  # If we wanted an exact match and didn't find it, return nothing
  return undef  if ( $p->{version} ); 

  return $final;
}



# Find a file that exists in either the website directory or the base
# installation directory. @file_list defines a number of choices
# available for the file to be named.
#
# Returns: the full path and filename of the first match

sub find_file {
  my ( $self, @file_list ) = @_;
  return undef unless ( scalar @file_list );
  foreach my $base_file ( @file_list ) {
    if ( $self->{website_dir} ) {
      my $filename = join( '/', $self->{website_dir}, $self->{package_dir}, $base_file );   
      _w( 1, "Created filename <<$filename>> using the website directory" );
      return $filename if ( -f $filename );
    }
    my $filename = join( '/', $self->{base_dir}, $self->{package_dir}, $base_file );
    _w( 1, "Created filename <<$filename>> using the base installation directory" );
    return $filename if ( -f $filename );
  }
  _w( 1, "No existing filename found matching @file_list" );
  return undef;
}



# Given a package object, we create an entirely new one in the
# interact base dir; note that we must have a few fields defined
# before we're able to do this; it would probably be best that the
# package is saved first as well... but we won't require that for now

sub create_new {
  my ( $self, $p ) = @_;

 # Ensure that our directories exist

  unless ( $self->{base_dir} and $self->{name} and $self->{version} ) {
    die "Please define the fields: 'base_dir', 'name', and 'version' before continuing.\n";
  }
  unless ( -d $self->{base_dir} and -d "$self->{base_dir}/pkg" ) {
    die "Please ensure that the directories $self->{base_dir} and $self->{base_dir}/pkg exist\n";
  }
  
  my $pkg_dir = "$self->{base_dir}/pkg/" . join( '-', $self->{name}, $self->{version} );
  if ( -d $pkg_dir ) {
    die "Cannot continue: package directory $pkg_dir already exists.\n";
  }
  
  $self->create_package_dirs( $pkg_dir );
  $self->{installed_on}   = $self->now;
  $self->{installed_by} ||= 'system';
  return $pkg_dir  if ( eval { $self->save( $p ) } );
  return undef;
}


# Create subdirectories for a package.

sub create_package_dirs {
  my ( $class, $dir, $main_class ) = @_;
  $main_class ||= 'OpenInteract';
  return undef unless ( -d $dir );
  foreach my $sub_dir ( @PKG_SUBDIR, $main_class, 
                        "$main_class/Handler", 
                        "$main_class/SQLInstall" ) {
    mkdir( "$dir/$sub_dir", 0775 ) || die "Cannot create package subdirectory $dir/$sub_dir: $!";
  }
  return 1;
}



# Creates a package directories using our base subdirectories 
# along with a package.conf file and some other goodies (?)

sub create_package_skeleton {
  my ( $class,  $name, $base_dir ) = @_;
  my $pwd = cwd;

  # Check directories

  unless ( -d $base_dir ) {
    die "Cannot create package skeleton: no existing base installation directory specified!";
  }
  if ( -d $name ) {
    die "Cannot create package skeleton: directory ($name) already exists!";
  }
  mkdir( $name, 0775 ) || die "Cannot create package directory $name: $!";
  chdir( $name );

  # Then create the subdirectories for the package
  
  $class->create_package_dirs( '.' );
  
  # This does a replacement so that 'static_page' becomes StaticPage
  
  my $uc_first_name = ucfirst $name;
  $uc_first_name =~ s/_(\w)/\U$1\U/g;
  
  # Copy over files from the samples (located in the base OpenInteract
  # directory), doing replacements as necessary
  
  $class->replace_and_copy( { from_file => "$base_dir/conf/sample-package.conf",
                              to_file   => "package.conf",
                              from_text => [ '%%NAME%%', '%%UC_FIRST_NAME%%' ],
                              to_text   => [ $name, $uc_first_name ] } );
  
  $class->replace_and_copy( { from_file => "$base_dir/conf/sample-package.pod",
                              to_file   => "doc/$name.pod",
                              from_text => [ '%%NAME%%' ],
                              to_text   => [ $name ] } );
  
  $class->replace_and_copy( { from_file => "$base_dir/conf/sample-doc-titles",
                              to_file   => "doc/titles",
                              from_text => [ '%%NAME%%' ],
                              to_text   => [ $name ] } );
  
  $class->replace_and_copy( { from_file => "$base_dir/conf/sample-SQLInstall.pm",
                              to_file   => "OpenInteract/SQLInstall/$uc_first_name.pm",
                              from_text => [ '%%NAME%%', '%%UC_FIRST_NAME%%' ],
                              to_text   => [ $name, $uc_first_name ] } );
  
  $class->replace_and_copy( { from_file => "$base_dir/conf/sample-Handler.pm",
                              to_file   => "OpenInteract/Handler/$uc_first_name.pm",
                              from_text => [ '%%NAME%%', '%%UC_FIRST_NAME%%' ],
                              to_text   => [ $name, $uc_first_name ] } );

  cp( "$base_dir/conf/sample-spops.perl", "conf/spops.perl" ) 
     || _w( 0, "Cannot copy sample (conf/spops.perl): $!" );
  cp( "$base_dir/conf/sample-action.perl", "conf/action.perl" )
     || _w( 0, "Cannot copy sample (conf/action.perl): $!" );
  cp( "$base_dir/conf/sample-MANIFEST.SKIP", "MANIFEST.SKIP" )
     || _w( 0, "Cannot copy sample (MANIFEST.SKIP): $!" );
  cp( "$base_dir/conf/sample-dummy-template.meta", "template/dummy.meta" )
     || _w( 0, "Cannot copy sample (template/dummy.meta): $!" );
  cp( "$base_dir/conf/sample-dummy-template.tmpl", "template/dummy.tmpl" )
     || _w( 0, "Cannot copy sample (template/dummy.tmpl): $!" );

 # Create a 'Changes' file 
  
  eval {  open( CHANGES, "> Changes" ) || die $! };
  if ( $@ ) {
    _w( 0, "Cannot open 'Changes' file ($!). Please create your own so people can follow your progress." );
  }
  else {
    my $time_stamp = scalar( localtime );
    print CHANGES <<INIT;
Revision history for OpenInteract package $name.

0.01  $time_stamp

      Package skeleton created by oi_manage

INIT
    close( CHANGES );
  }

  # Create a MANIFEST from the pwd

  $class->_create_manifest();

  # Go back to the original dir and return the name
  
  chdir( $pwd );
  return $name; 
}



# Takes a package file and installs the package to the base
# OpenInteract directory.

sub install_package {
  my ( $class, $p ) = @_;
  my $old_pwd = cwd;
  
  unless ( -f $p->{package_file} ) {
    die "Package file for installation ($p->{package_file}) does not exist\n";
  }
  
  my $base_package_file = File::Basename::basename( $p->{package_file} );
  my ( $package_base ) = $base_package_file =~ /^(.*)\.tar\.gz$/;
  
  # Unpack the distribution into a tmp directory -- note, we should
  # probably switch to using the CPAN module File::Temp here, but
  # I'm not sure it works on Win32 (as this will eventually have to do)
  
  my $random = int( rand(4073) );
  
  # Be sure to remove this at all points before we die/exit
  
  my $root_tmp_dir = File::Spec->tmpdir();
  my $tmp_dir = join( '/', $root_tmp_dir, "OI-$random" );
  mkdir( $tmp_dir, 0775 ) 
      || die "Cannot create temp directory ($tmp_dir) for unpacking distribution: $!";

  # Be sure to remove this at all points before we die/exit

  my $tmp_filename = join( '/', $root_tmp_dir, "$random.tar.gz" );
  cp( $p->{package_file}, $tmp_filename ) 
      || die "Cannot copy package file to temp dir ($tmp_filename)! $!";
  _w( 1, "Copied file to ($tmp_filename)" );

  chdir( $tmp_dir );
  my $rv = $class->_extract_archive( $tmp_filename );
  unless ( $rv ) {
    my $msg = "Failure! Error found trying to unpack the distribution in a temp " .
              "directory ($tmp_dir)! Error: " . $ARCHIVE_ERROR;
    chdir( $old_pwd );
    my $removed_files = $class->_remove_directory_tree( $tmp_dir );
    unlink( $tmp_filename );
    _w( 1, $msg );
    die $msg;
  }
 
 # Read in the package config and grab the name/version

  chdir( "$tmp_dir/$package_base" );
  _w( 1, "Trying to find config file in ($tmp_dir/$package_base)" );
  my $conf_file = $p->{package_conf_file} || $DEFAULT_CONF_FILE;
  my $conf    = $class->read_package_config( $conf_file );
  my $name    = $conf->{name};
  my $version = $conf->{version};
  chdir( $old_pwd );
  
  # We're all done with the temp stuff, so get rid of it.
  
  my $removed_files = $class->_remove_directory_tree( $tmp_dir, undef, undef );
  
  # Check to see if the package/version already exists
  
  my $error_msg = undef;
  my $pkg = OpenInteract::Package->fetch_by_name({
                              name => $name, version => $version,
                              directory => $p->{base_dir} });
  if ( $pkg ) {
    unlink( $tmp_filename );
    die "Failure! Cannot install since package $name-$version already seems " .
        "to exist in the installation package database. (It was installed on " .
        "$pkg->{installed_on}).\n\nAborting package installation.\n";
  }

  # Create some directory names and move to the base package directory
  # -- the directory that holds all of the package definitions

  my $new_pkg_dir  = join( '/', 'pkg', "$name-$version" );
  my $full_pkg_dir = join( '/', $p->{base_dir}, $new_pkg_dir );
  my $root_pkg_dir = join( '/', $p->{base_dir}, 'pkg' );
  chdir( $root_pkg_dir );

 # Unarchive the package; note that since the archive creates a
 # directory name-version/blah we don't need to create the directory
 # ourselves and then chdir() to it; After we unarchive the tmp file
 # here, we don't need it anymore
  
  my $extract_rv = $class->_extract_archive( $tmp_filename );
  unlink( $tmp_filename );
  unless ( $extract_rv ) {
    chdir( $p->{base_dir} );
    $class->_remove_directory_tree( $full_pkg_dir );
    die "Failure! Cannot unpack the distribution into its final " .
        "directory ($full_pkg_dir)! Error: " . $ARCHIVE_ERROR;
  }

 # Create the package and try to save; if we're successful, return the
 # package object.
  
  $pkg                 = $class->new( $conf );
  $pkg->{base_dir}     = $p->{base_dir};
  $pkg->{package_dir}  = $new_pkg_dir;
  $pkg->{installed_on} = $pkg->now;
  eval { $pkg->save( { directory => $p->{base_dir} } ) };
  if ( $@ ) {
    chdir( $p->{base_dir} );
    $class->_remove_directory_tree( $full_pkg_dir );
    my $ei = SPOPS::Error->get;
    die "Failure! Could not save data to installed package database. " .
        "Error returned: $@ (System msg: $ei->{system_msg}). " .
        "Aborting package installation.";
  }
  chdir( $old_pwd );
  return $pkg;
}


# Install a package from the base OpenInteract directory to a website
# directory. This is known in 'oi_manage' terms as 'applying' a
# package.

sub install_to_website {
  my ( $self ) = @_;

 # Be sure to have the website directory, website name, and package directory set
  
  die "Website name not set in package object.\n"        unless ( $self->{website_name} );
  die "Website directory not set in package object\n"    unless ( $self->{website_dir} );
  die "Package directory not set in package object.\n"   unless ( $self->{package_dir} );
  
  # First ensure that our base package directory exists
  
  my $interact_pkg_dir = join( '/', $self->{base_dir}, $self->{package_dir} );
  unless ( -d $interact_pkg_dir ) { die "Package directory ($interact_pkg_dir) does not exist\n" }
  
  # Then create package directory within the website directory
  
  my $pkg_dir = join( '/', $self->{website_dir}, $self->{package_dir} );
  if ( -d $pkg_dir ) { die "Package directory $pkg_dir already exists.\n" }
  mkdir( $pkg_dir, 0775 ) || die "Cannot create $pkg_dir : $!";
  
  # Next move to the base package directory (we return to the original
  # directory just before the routine exits)
  
  my $pwd = cwd;
  chdir( $interact_pkg_dir );
  
  # ...then ensure that it has all its files
  
  my @missing = ExtUtils::Manifest::manicheck;
  if ( scalar @missing ) {
    die "Cannot install package $self->{name}-$self->{version} to website ",
        "-- the base package has files that are specified in MANIFEST missing ",
        "from the filesystem: @missing. Please fix the situation.\n";
  }

 # ...and get all the filenames from MANIFEST
  
  my $BASE_FILES = ExtUtils::Manifest::maniread;
  
  # Now create the subdirectories
  
  $self->create_package_dirs( $pkg_dir, $self->{website_name} );
  
  $self->_copy_spops_config_file();
  
  $self->_copy_action_config_file();
  
  # Now copy over the struct/, data/, template/, html/, html/images/
  # and doc/ files -- intact with no translations, as long as they
  # appear in the MANIFEST file (read in earlier)
  #
  # The value of the subdir key is the root where they will be copied

  my %subdir_match = (
      struct        => $pkg_dir,
      data          => $pkg_dir,
      template      => $pkg_dir,
      doc           => $pkg_dir,
      html          => $self->{website_dir},
  );

  foreach my $sub_dir ( sort keys %subdir_match ) {
    $self->_copy_package_files( $subdir_match{ $sub_dir }, 
                                $sub_dir, 
                                [ keys %{ $BASE_FILES } ] );
  }

  # Now copy the MANIFEST.SKIP file and package.conf, so we can run
  # 'check_package' on the package directory (once complete) as well as
  # generate a MANIFEST once we're done copying files
  
  foreach my $root_file ( 'MANIFEST.SKIP', 'package.conf' ) {
    cp( $root_file, "$pkg_dir/$root_file" )
         || _w( 0, "Cannot copy $root_file to $pkg_dir/$root_file : $!" );
  }

  $self->_copy_handler_files( $BASE_FILES );
 
  # Now go to our package directory and create a new MANIFEST file
  
  chdir( $pkg_dir );
  $self->_create_manifest();

  chdir( $pwd );
  return $pkg_dir;
}



# Dump the package from the current directory into a tar.gz
# distribution file 

sub export_package {
  my ( $class, $p ) = @_;
  $p ||= {};
  
  # If necessary, Read in the config and ensure that it has all the
  # right information
  
  my $config_file = $p->{config_file} || $DEFAULT_CONF_FILE;
  my $config = $p->{config} || eval { $class->read_package_config( $config_file ) };
  if ( $@ ) {
    die "Failure! Package configuration file cannot be opened -- \n" ,
        "are you chdir'd to the package directory? (Reported reason \n",
        "for failure: $@\n";
  }
  _w( 2, "Package config read in: ", Dumper( $config ) );

 # Check to ensure that all required fields have something in them; we
 # might do a 'version' check in the future, but not until it proves
 # necessary
  
  my @missing_fields = ();
  foreach my $required_field ( @EXPORT_REQUIRED ) {
    push @missing_fields, $required_field unless ( $config->{ $required_field } );
  } 
  if ( scalar @missing_fields ) {
    die "Failure! Configuration file exists but is missing the following fields: (" .
        join( ', ', @missing_fields ) . "). Please add these fields and try again.\n";
  }

 # Now, do a check on this package's MANIFEST - are there files in
 # MANIFEST that don't exist?
  
  warn "Package $config->{name}: checking MANIFEST for discrepancies\n";
  my @missing = ExtUtils::Manifest::manicheck();
  if ( scalar @missing ) {
    warn "\nIf the files specified do not need to be in MANIFEST any longer,\n",
          "please remove them from MANIFEST and re-export the package. Otherwise\n",
          "users installing the package will get a warning.\n";
  }
  else {
    warn "Looks good\n\n";
  }
 
  # Next see if there are files NOT in the MANIFEST

  warn "Package $config->{name}: checking filesystem for files not in MANIFEST\n";
  my @extra = ExtUtils::Manifest::filecheck();
  if ( scalar @extra ) {
    warn "\nBuilding a package without these files is OK, but you can also\n",
         "add them as necessary to the MANIFEST and re-export the package.\n";
  }
  else {
    warn "Looks good\n\n";
  }
  my $cwd = cwd;
  _w( 1, "Current directory exporting from: ($cwd)" );

  # Read in the MANIFEST

  my $package_files = ExtUtils::Manifest::maniread();
  _w( 2, "Package info read in:\n", Dumper( $package_files ) );

  # Now, create a directory of this name-version and copy the files

  my $package_id = join( '-', $config->{name}, $config->{version} );
  mkdir( $package_id, 0777 ) 
       || die "Cannot create directory used to archive the package! Error: $!";
  {
    local $ExtUtils::Manifest::Quiet = 1;
    ExtUtils::Manifest::manicopy( $package_files, "$cwd/$package_id" );
  }

  # And prepend the directory name to all the files so they get
  # un-archived in the right way

  my @archive_files = map { "$package_id/$_" } keys %{ $package_files };

  # Create the tardist

  my $filename = "$cwd/$package_id.tar.gz";
  my $rv = Archive::Tar->create_archive( $filename, 9, @archive_files );

  # And remove the directory we just created
  
  $class->_remove_directory_tree( "$cwd/$package_id" );
  
  # Return the filename and the name/version information for the
  # package distribution we just created
  
  if ( $rv ) {
    warn "\n";
    return { name    => $config->{name}, 
             version => $config->{version},
             file    => "$filename" };
  }
  die "Failure! Cannot create distribution ($filename). Error: ", Archive::Tar->error(), "\n";
}


# Ensure that a list of packages actually exists in whichever context
# is specified.

sub verify_packages {
  my ( $class, $p, @package_names ) = @_;
  my @pkg_exist = ();
  foreach my $pkg_name ( @package_names ) {
    my $pkg = $class->fetch_by_name( { name => $pkg_name, directory => $p->{directory} } );   
    _w( 1, sprintf( "Verify package status %-20s: %s", 
                    $pkg_name,  ( $pkg ) ? "exists (Version $pkg->{version})" : 'does not exist' ) );
    push @pkg_exist, $pkg  if ( $pkg );
  }
  return \@pkg_exist;
}



sub read_package_config {
  my ( $item, $file )  = @_;
  return {} unless ( $file or ref $item );
  unless ( $file ) {
    my $main_dir = $item->{website_dir} || $item->{base_dir};   
    $file = "$main_dir/$item->{package_dir}//package.conf";
  }
  unless ( -f $file ) {
    die "Package configuration file ($file) does not exist.\n";
  }
  open( CONF, $file ) || die "Error opening $file: $!";
  my $config = {};
  while ( <CONF> ) {   
    next if ( /^\s*\#/ );
    next if ( /^\s*$/ );
    chomp;
    s/\r//g;
    my ( $k, $v ) = split /\s+/, $_, 2;
    last if ( $k eq 'description' );
    
    # If there are multiple values possible, make a list
    
    if ( $CONF_LIST_KEYS{ $k } ) {
      push @{ $config->{ $k } }, $v;
    }
    
    # Otherwise, if it's a key -> key -> value set; add to list
    
    elsif ( $CONF_HASH_KEYS{ $k } ) {
      my ( $sub_key, $sub_value ) = split /\s+/, $v, 2;
      $config->{ $k }->{ $sub_key } = $sub_value;
    }
    
    # If not all that, then simple key -> value
    
    else {
      $config->{ $k } = $v;
    }
  }
  
  # Once all that is done, read the description in all at once
  { 
    local $/ = undef;
    $config->{description} = <CONF>; 
  }
  chomp $config->{description};
  close( CONF );
  return $config;
}


# Put the package dir(s) into @INC

sub include_package_dir {
  my ( $self ) = @_;
  my @my_inc = ();
  my $base_package_dir = join( '/', $self->{base_dir}, $self->{package_dir} );
  unshift @my_inc, $base_package_dir  if ( -d $base_package_dir );
  if ( $self->{website_dir} ) {
    my $app_package_dir = join( '/', $self->{website_dir}, $self->{package_dir} );
    unshift @my_inc, $app_package_dir if ( -d $app_package_dir );
  }
  unshift @INC, @my_inc;
  return @my_inc;
}

# Read in a file (parameter 'from_file') and write it to a file
# (parameter 'to_file'), doing replacements on keys along the way. The
# keys are found in the list 'from_text' and the replacements are
# found in the list 'to_text'.

sub replace_and_copy {
  my ( $class, $p ) = @_;
  unless ( $p->{from_text} and $p->{to_text} and $p->{from_file} and $p->{to_file} ) {
    die "Not enough params for copy/replace! ", Dumper( $p ), "\n";
  }
  cp( $p->{from_file}, "$p->{to_file}.old" ) || die "No copy $p->{from_file} -> $p->{to_file}.old: $!";
  open( OLD, "$p->{to_file}.old" ) || die "Cannot open copied file: $!";
  open( NEW, "> $p->{to_file}" )   || die "Cannot open new file: $!";
  while ( <OLD> ) {
    my $line = $_;
    for ( my $i = 0; $i < scalar @{ $p->{from_text} }; $i++ ) {
      $line =~ s/$p->{from_text}->[ $i ]/$p->{to_text}->[ $i ]/g;
    }
    print NEW $line;
  }
  close( NEW );
  close( OLD );
  unlink( "$p->{to_file}.old" ) || 
       warn qq/Cannot erase temp file (you should do a 'rm -f `find . -name "*.old"`' after this is done): $!\n/;
}


# Copy the spops.perl file from the base install package directory to
# the website package directory Note that we have changed this
# recently (Jan 01) to keep only certain configuration variables
# *behind* -- all others are copied over to the website

sub _copy_spops_config_file {
  my ( $self, $p ) = @_;
  my $interact_pkg_dir = join( '/', $self->{base_dir}, $self->{package_dir} );
  my $pkg_dir          = join( '/', $self->{website_dir}, $self->{package_dir} );
  
  my $spops_conf = 'conf/spops.perl';
  unless ( -f "$interact_pkg_dir/$spops_conf" ) {
    return undef;
  }
  my $spops_base  = eval { SPOPS::HashFile->new({ 
                                                 filename => "$interact_pkg_dir/$spops_conf" 
                                                }) };
  if ( $@ ) {
    _w( 0, "Cannot eval spops.perl file in ($self->{name}-$self->{version}): $@" );
    return undef;
  }
  my $new_config_file = "$pkg_dir/$spops_conf";
  my $spops_pkg = SPOPS::HashFile->new({ 
                             filename => $new_config_file, 
                             perm => 'new' });

  foreach my $spops_key ( keys %{ $spops_base } ) {
    
    # Change the class if it exists (it better!)
    
    if ( my $old_class = $spops_base->{ $spops_key }->{class} ) {
      $spops_pkg->{ $spops_key }->{class} = $self->_change_class_name( $old_class );
    }
    
    # Both the has_a and links_to use class names as keys to link
    # objects; change the class names from 'OpenInteract' to this
    # website name
    
    if ( my $old_has_a = $spops_base->{ $spops_key }->{has_a} ) {
      foreach my $old_class ( keys %{ $old_has_a } ) {
        my $new_class = $self->_change_class_name( $old_class );
        $spops_pkg->{ $spops_key }->{has_a}->{ $new_class } = $old_has_a->{ $old_class };
      }
    }
    
    if ( my $old_links_to = $spops_base->{ $spops_key }->{links_to} ) {
      foreach my $old_class ( keys %{ $old_links_to } ) {
        my $new_class = $self->_change_class_name( $old_class );
        $spops_pkg->{ $spops_key }->{links_to}->{ $new_class } = $old_links_to->{ $old_class };
      }
    }
    
    # Copy over all the fields verbatim except those specified in the
    # global %SPOPS_CONF_KEEP. Note that it's ok we're copying
    # references here since we're going to dump the information to a
    # file anyway
    
    foreach my $to_copy ( keys %{ $spops_base->{ $spops_key } } ) {
      next if ( $SPOPS_CONF_KEEP{ $to_copy } );
      $spops_pkg->{ $spops_key }->{ $to_copy } = $spops_base->{ $spops_key }->{ $to_copy };
    }
  }
  
  eval { $spops_pkg->save( { dumper_level => 1 } ) };
  die "Cannot save package spops file: $@\n"  if ( $@ );
  return $new_config_file;
}


# Copy the conf/action.perl file over from the base installation to
# the website. This is somewhat easier because there are no nested
# classes we need to modify

sub _copy_action_config_file {
  my ( $self, $p ) = @_;
  my $interact_pkg_dir = join( '/', $self->{base_dir}, $self->{package_dir} );
  my $pkg_dir          = join( '/', $self->{website_dir}, $self->{package_dir} );
  
  my $action_conf = 'conf/action.perl';
  my $action_base = eval { SPOPS::HashFile->new({ 
                                                 filename => "$interact_pkg_dir/$action_conf" 
                                                }) };
  if ( $@ ) {
    _w( 1, "No action info for $self->{name}-$self->{version} (generally ok: $@)" );
    return undef;
  }
  
  my $new_config_file = "$pkg_dir/$action_conf";
  my $action_pkg = SPOPS::HashFile->new({ 
                              filename => $new_config_file, 
                              perm => 'new' });
  
  # Go through all of the actions and all of the keys and copy them
  # over to the new file. The only modification we make is to a field
  # named 'class', if it exists, where we modify it to fit in the
  # website's namespace.
  
  foreach my $action_key ( keys %{ $action_base } ) {
    foreach my $action_item_key ( keys %{ $action_base->{ $action_key } } ) {
      my $value = $action_base->{ $action_key }->{ $action_item_key };
      if ( $action_item_key eq 'class' ) {
        $value = $self->_change_class_name( $value );
      }
      $action_pkg->{ $action_key }->{ $action_item_key } = $value;
    }
  }
  
  eval { $action_pkg->save( { dumper_level => 1 } ) };
  die "Cannot save package action file: $@\n"  if ( $@ );
  return $new_config_file;
}


# Copy files from the current directory into a website's directory

sub _copy_package_files {
  my ( $self, $root_dir, $sub_dir, $file_list ) = @_;
  my @copy_file_list = grep /^$sub_dir/, @{ $file_list };
  foreach my $sub_dir_file ( @copy_file_list ) {   
    my $new_name = join( '/', $root_dir, $sub_dir_file );
    my $dirname = File::Basename::dirname( $new_name );
    File::Path::mkpath( $dirname ) unless ( -d $dirname );
    cp( $sub_dir_file, "$new_name" )
         || _w( 0, "Cannot copy $sub_dir_file to $new_name : $!" );
  }
  return \@copy_file_list;
}

# Copy handlers from the base installation to the website directory --
# first read them in and then replace any instances of
#   'OpenInteract::Handler::xxx' 
# with
#  '$self->{website_name}::Handler::xxx'
# before writing them out to the website directory.


sub _copy_handler_files {
  my ( $self, $base_files ) = @_;
  my $pkg_dir = join( '/', $self->{website_dir}, $self->{package_dir} );
  my @handler_file_list = grep /^OpenInteract\/Handler/, keys %{ $base_files };
  foreach my $handler_file ( @handler_file_list ) {
    my $new_filename = $self->_change_class_name( "$pkg_dir/$handler_file" );
    open( OLDHAND, $handler_file )     || die "Cannot read handler ($handler_file): $!";
    open( NEWHAND, "> $new_filename" ) || die "Cannot write to handler ($new_filename): $!";
    my $handler_class = $handler_file;
    $handler_class  =~ s|/|::|g;
    $handler_class  =~ s/\.pm$//;
    my $new_handler_class = $self->_change_class_name( $handler_class );
    _w( 1, "Old name: $handler_class; New name: $new_handler_class" );
    while ( <OLDHAND> ) {        
      s/$handler_class/$new_handler_class/g;
      print NEWHAND;
    }
    close( OLDHAND );
    close( NEWHAND );
  }
  return \@handler_file_list;
}


# Used to accommodate earlier versions of Archive::Tar (such as those
# shipped with ActivePerl, sigh)
# --NOTE: you should already be chdir'd to the directory where this will
# be unpacked
# --NOTE: I'm not sure if the version reference below is correct -- I
# *think* it might be 0.20, but I'm not entirely sure.

sub _extract_archive {
  my ( $class, $filename ) = @_;
  return undef unless ( -f $filename );
  my $rv = undef;
  if ( $Archive::Tar::VERSION >= 0.20 ) {
    $rv = Archive::Tar->extract_archive( $filename );
    unless ( $rv ) { $ARCHIVE_ERROR = Archive::Tar->error() }
  }
  else {
    my $tar = Archive::Tar->new( $filename, 1 );
    my @files = $tar->list_files();
    $tar->extract( @files );
    if ( $Archive::Tar::error ) { 
      $ARCHIVE_ERROR = "Possible errors: $Archive::Tar::error / $@ / $!";
    }
    else {
      $rv++;
    }
  }
  return $rv;
}

# Create a manifest file in the current directory. (Note that the
# 'Quiet' and 'Verbose' parameters won't work properly until
# ExtUtils::Manifest is patched which won't likely be until 5.6.1)

sub _create_manifest {
  my ( $class ) = @_;
  local $SIG{__WARN__} = sub { return undef };
  $ExtUtils::Manifest::Quiet   = 1;
  $ExtUtils::Manifest::Verbose = 0;
  ExtUtils::Manifest::mkmanifest();
}


# Remove a directory and all files/directories beneath it. Return the
# number of removed files.

sub _remove_directory_tree {
  my ( $class, $dir ) = @_; 
  my $removed_files = File::Path::rmtree( $dir, undef, undef );
  _w( 1, "Removed ($removed_files) from ($dir)" );
  return $removed_files;
}


# Modify the first argument by replacing 'OpenInteract' with either
# the second argument or the property 'website_name' of the zeroth
# argument.

sub _change_class_name {
  my ( $item, $old_class, $new_name ) = @_;
  if ( ref $item and ! $new_name ) {
    $new_name = $item->{website_name};
  }
  $old_class =~ s/OpenInteract/$new_name/g;
  return $old_class;
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

OpenInteract::Package - Operations to represent, install, remove and otherwise manipulate packages

=head1 SYNOPSIS

 # Simple: Create a new package, set some properties and save

 my $pkg = OpenInteract::Package->new;
 $pkg->{name} = 'MyPackage';
 $pkg->{version} = 3.13;
 $pkg->{author}  = 'Arthur Dent <arthurd@earth.org>';
 $pkg->{base_dir} = '/path/to/installed/OpenInteract';
 $pkg->{package_dir} = 'pkg/mypackage-3.13';
 eval { $pkg->save };

 # Retrieve the latest version

 my $pkg = eval { OpenInteract::Package->fetch_by_name({ 
               name => 'MyPackage'
           }) };
 unless ( $pkg ) {
   die "No package found with that name!";
 }

 # Retrieve a specific version

 my $pkg = eval { OpenInteract::Package->fetch_by_name({ 
               name => 'MyPackage',
               version => 3.12
           }) };
 unless ( $pkg ) {
   die "No package found with that name and version!";
 }

 # Install a package

 my $pkg = eval { OpenInteract::Package->install_package({ 
               base_dir => $OPT_base_dir,
               package_file => $OPT_package_file 
           }) };
 if ( $@ ) {
   print "Could not install package! Error: $@";
 }
 else {
   print "Package $pkg->{name}-$pkg->{version} installed ok!";
 }

 # Install to website (apply package)

 my $pkg = eval { OpenInteract::Package->fetch_by_name({ 
               name => 'MyPackage',
               version => 3.12
           }) };
 $pkg->{website_dir}  = "/home/MyWebsiteDir";
 $pkg->{website_name} = "MyApp";
 $pkg->{installed_on} = $pkg->now;
 eval { $pkg->install_to_website() };
 if ( $@ ) {
   print "Cannot install $pkg->{name}-$pkg->{version} to ",
         "website! Error: $@";
 }

 # Create a package skeleton (for when you are developing a new
 # package)

 eval { OpenInteract::Package->create_package_skeleton(
            $package_name, $base_directory
 ) };

 # Export a package into a tar.gz distribution file

 chdir( '/home/MyWebsiteDir' );
 my $status = OpenInteract::Package->export_package();
 print "Package: $status->{name}-$status->{version} ",
       "saved in $status->{file}";
 
 # Find a file in a package

 my $filename = $pkg->find_file( 'template/mytemplate.tmpl' );
 open( TMPL, $filename ) || die "Cannot open $filename: $!";
 while ( <TMPL> ) { ... }

=head1 DESCRIPTION

This is a different type of module than many others in the
C<OpenInteract::> hierarchy. Instead of being created from scratch,
the configuration information is in the class rather than in a
configuration file. It does not use a SQL database for a back end. It
does not relate to any other objects.

Instead, all we do is represent Package objects. An OpenInteract
Package is a means of distributing Perl object and handler code,
configuration, SQL structures and data, templates and anything else
necessary to implement a discrete set of functionality.

A package can exist in two places: in the base installation and in a
website. Website packages have the property 'website_dir' defined.

=head1 METHODS

Note that every method with \%params can pass a tied GDBM database
handle under the 'db' key, a filename where a GDBM database can be
found under the 'filename' key, or a 'directory' in which is found the
$PKG_DB_FILE filename.

B<_class_initialize( $CONFIG )>

When we initialize the class we want to use the OpenInteract
installation directory for the default package database location.

B<pre_save_action>

Ensure that before we add a package to a database it has the
'base_dir' property.

B<fetch_by_name( \%params )>

Retrieve a package by name and/or version. If you ask for a specific
version and that version does not exist, you will get nothing back. If
you do not ask for a version, you will get the latest one available.

Parameters:

 name ($)
   Package name to retrieve

 version ($ - optional)
   Version of package to retrieve; if you specify a version then
   *only* that version can be returned.

Example:

 my $pkg = $pkg_class->fetch_by_name( { name => 'zigzag' } );
 if ( $pkg ) {
   print "Latest installed version of zigzag: $pkg->{version}\n";
 }

B<find_file( @file_list )>

Pass in one or more possible variations on a filename that you wish to
find within a package. If you pass multiple files, each will be
checked in order. Note that the name must include any directory prefix
as well. For instance:

   $pkg->find_file( 'template/mytemplate', 'template/mytemplate.tmpl' );

Returns a full filename of an existing file, undef if no existing file
found matching any of the filenames passed in.

B<create_new( \%params )>

Creates a new package in the 'base_dir' given the necessary
information. You need to ensure that 'base_dir', 'name' and 'version'
already exist in your package object before calling this. Also, if the directory: 

 base_dir/pkg/pkgname-version 

already exists the method will die.

B<create_package_dirs( $root_dir, $main_class )>

Creates subdirectories in a package directory -- currently the list of
subdirectories is held in the package lexical @PKG_SUBDIR, plus we
also create the directories:

 $main_class
 $main_class/Handler
 $main_class/SQLInstall

If there is no $main_class passed in, 'OpenInteract' is assumed.

B<create_package_skeleton( $package_name, $base_install_dir )>

Creates the skeleton for a package in the current directory. The
skeleton can then be used to for a fully functioning package.

The skeleton creates the directories found in @PKG_SUBDIR and copies a
number of files from the base OpenInteract installation to the
skeleton. These include:

 Changes
 package.conf
 MANIFEST
 MANIFEST.SKIP
 conf/spops.perl
 conf/action.perl
 doc/package.pod
 doc/titles
 template/dummy.meta
 template/dummy.tmpl
 <PackageName>/SQLInstall/<PackageName>.pm
 <PackageName>/Handler/<PackageName>.pm

We fill in as much default information as we know in the files above,
and several of the files have helpful hints about the type information
that goes in each.

B<install_package>

Install a package distribution file to the base OpenInteract
installation. We do not need to do any localization work here since we
are just putting the distribution in the base installation, so the
operation is fairly straightforward.

More work and testing likely needs to be done here to ensure it works
on Win32 systems as well as Unix systems. The use of L<File::Spec> and
L<File::Path> should help with this, but there are still issues with
the version of L<Archive::Tar> shipped with ActiveState Perl.

B<install_to_website( \%params )>

Installs a package from the base OpenInteract installation to a
website. The package B<must> already have defined 'website_name',
'website_dir' and 'package_dir' object_properties. Also, the
directory:

 website_dir/pkg/pkg-version

should not exist, otherwise the method will die.

Note that we use the routines C<_copy_spops_config_file()> and
C<_copy_action_config_file()>, which localize the C<spops.perl> and
C<action.perl> configuration files for the website. The localization
consists of changing the relevant class names from 'OpenInteract' to
'MyWebsiteName'.

B<export_package( \%params )>

Exports the package whose root directory is the current directory into
a distribution file in tarred-gzipped format, also placed into the
current directory.

Returns: Information about the new package in hashref format with the
following keys:

 name
   Name of package

 version
   Version of package

 file
   Full filename of distribution file created

Parameters:

 config_file ($) (optional)
   Name of configuration file for package.

 config (\%) (optional)
   Hashref of package configuration file information. 

B<verify_packages( \%params, @package_names ) >

Verify that each of the packages listed in @package_names exists, in
whatever context is specified in \%params -- given a particular
'directory' or 'filename' parameter to specify a GDBM file.

Returns: List reference of package objects that match up with
@package_names.

B<read_package_config( $filename )>

Reads in a package configuration file. This file is in a simple
name-value format, although the file supports lists and hashes as
well. Whether a parameter supports a list or a hash is defined in the
package lexical variables %CONF_LIST_KEYS and %CONF_HASH_KEYS. The
reading goes like this:

If a key is not in %CONF_LIST_KEYS or %CONF_HASH_KEYS, it is just a
simple key/value pair; a key in %CONF_LIST_KEYS gets the value pushed
onto a stack, and a key found in %CONF_HASH_KEYS has its value split
on whitespace again and that assigned to the hashref indexed by the
original key. Once we hit the 'description' key, the rest of the file
is read in at once and assigned to the description. Note that comments
and blank lines are skipped until we get to the description when it is
all just slurped in.

Returns: hashref of configuration information with the configuration
keys as hashref keys.

B<include_package_dir>

Put both the base package dir and the website package_dir into
@INC. Both directories are put onto the front of @INC, the website
directory first and then the base directory. (This enables packages
found in the app to override the base.) Both directories are first
tested to ensure they actually exist.

Returns: directories that were C<unshift>ed onto @INC, in the same order.

Parameters: none

B<replace_and_copy( \%params )>

Copy a file from one place to another and in the process do a
search-and-replace of certain keys.

Parameters:

 from_file ($)
   File from which we should read text.

 to_file ($)
   File to which we write changed text.

 from_text (\@)
   List of keys to replace

 to_text (\@)
   Replacement values for each of the keys in 'from_text'

=head1 HELPER METHODS

B<_extract_archive( $archive_filename )>

This method is a wrapper around L<Archive::Tar> to try and account for
some of the differences between versions of the module. Errors found
during extraction will be found in the package lexical
C<$ARCHIVE_ERROR>.

Note that before calling this you should already be in the directory
where the archive will be extracted.

B<_create_manifest>

Creates a MANIFEST file in the current directory. This file follows
the same rules as found in L<ExtUtils::Manifest> since we use the
C<mkmanifest()> routine from that module. 

Note that we turn on the 'Quiet' and turn off the 'Verbose' parameters
in hopes that the operation will be silent (too confusing), but the
current version of ExtUtils::Manifest does not make its sub-operations
silent. The version shipped with 5.6.1 should take care of this.

B<_remove_directory_tree( $dir )>

Remove a directory and all files/directories beneath it. Return the
number of removed files.

B<_change_class_name( $old_class, $new_name )>

Changes the name from 'OpenInteract' to $new_name within
$old_class. For instance:

 my $old_class = 'OpenInteract::Handler::FormProcess';
 my $new_class = $class->_change_class_name( $old_class, 'MyWebsiteName' );
 print "New class is: $new_class\n";

 >> New class is: MyWebsiteName::Handler::FormProcess

If the method is called from an object and the second argument
($new_name) is not given, we default it to:
C<$object-E<gt>{website_name}>.

=head1 TO DO

B<Move to text-based storage>

Storing in GDBM files can be a PITA, although it does discourage
people tampering with the information by hand. Using L<DBD::RAM> for
XML-based file storage would be cool, but representing multivalued
fields (author) and fields with both keys and values (description)
might be problematic.

We will most likely move to a text-based Perl data structure to store
packages, probably in the very near future. So do not expend too much
effort on revising this :-)

=head1 BUGS

=head1 SEE ALSO

OpenInteract documentation: I<Packages in OpenInteract>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

Christian Lemburg <lemburg@aixonix.de> suffered through early versions
of the package management system and offered insightful feedback,
including a pointer to L<ExtUtils::Manifest> and the advice (as yet
unfollowed) to move to a text-based storage system.

=cut
