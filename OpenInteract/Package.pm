package OpenInteract::Package;

# $Id: Package.pm,v 1.7 2001/02/22 12:45:57 lachoy Exp $

# This module manipulates information from individual packages to
# perform some action in the package files. 

use strict;

use Archive::Tar       ();
use Cwd                qw( cwd );
use Data::Dumper       qw( Dumper );
use ExtUtils::Manifest ();
use File::Basename     ();
use File::Copy         qw( cp );
use File::Path         ();
use SPOPS::HashFile    ();
use SPOPS::Utility     ();

@OpenInteract::Package::ISA       = qw();
$OpenInteract::Package::VERSION   = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

# Define the subdirectories present in a package

my @PKG_SUBDIR        = qw( conf data doc struct template script html html/images );

# Fields in our package/configuration

my @PKG_FIELDS = qw( name version author url description notes 
                     dependency script_install script_upgrade 
                     script_uninstall sql_installer installed_on 
                     installed_by last_updated_on last_updated_by
                     base_dir website_dir package_dir website_name );


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

my %CONF_HASH_KEYS    = map { $_ => 1 } qw( dependency );

# For exporting a package, the following variables are required in
# 'package.conf'

my @EXPORT_REQUIRED   = qw( name version );

# Global for holding Archive::Tar errors

my $ARCHIVE_ERROR     = undef;

# Fields NOT to copy over in conf/spops.perl when creating package in
# website from base installation (the first three are ones we
# manipulate by hand)

my %SPOPS_CONF_KEEP   = map { $_ => 1 } qw( class has_a links_to);

use constant DEBUG => 0;

# Create subdirectories for a package.

sub create_subdirectories {
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

sub create_skeleton {
  my ( $class, $repository, $name ) = @_;
  my $pwd = cwd;

  # Check directories

  unless ( $repository ) {
    die "Cannot create package skeleton: no existing base installation repository specified!\n";
  }

  my $base_dir = $repository->{META_INF}->{base_dir};

  if ( -d $name ) {
    die "Cannot create package skeleton: directory ($name) already exists!\n";
  }
  mkdir( $name, 0775 ) || die "Cannot create package directory $name: $!\n";
  chdir( $name );

  # Then create the subdirectories for the package
  
  $class->create_subdirectories( '.' );
  
  # This does a replacement so that 'static_page' becomes StaticPage
  
  my $uc_first_name = ucfirst $name;
  $uc_first_name =~ s/_(\w)/\U$1\U/g;
  
  # Copy over files from the samples (located in the base OpenInteract
  # directory), doing replacements as necessary
  
  $class->replace_and_copy({ from_file => "$base_dir/conf/sample-package.conf",
                             to_file   => "package.conf",
                             from_text => [ '%%NAME%%', '%%UC_FIRST_NAME%%' ],
                              to_text   => [ $name, $uc_first_name ] });
  
  $class->replace_and_copy({ from_file => "$base_dir/conf/sample-package.pod",
                             to_file   => "doc/$name.pod",
                             from_text => [ '%%NAME%%' ],
                             to_text   => [ $name ] });
  
  $class->replace_and_copy({ from_file => "$base_dir/conf/sample-doc-titles",
                             to_file   => "doc/titles",
                             from_text => [ '%%NAME%%' ],
                             to_text   => [ $name ] });
  
  $class->replace_and_copy({ from_file => "$base_dir/conf/sample-SQLInstall.pm",
                             to_file   => "OpenInteract/SQLInstall/$uc_first_name.pm",
                             from_text => [ '%%NAME%%', '%%UC_FIRST_NAME%%' ],
                             to_text   => [ $name, $uc_first_name ] });
  
  $class->replace_and_copy({ from_file => "$base_dir/conf/sample-Handler.pm",
                             to_file   => "OpenInteract/Handler/$uc_first_name.pm",
                             from_text => [ '%%NAME%%', '%%UC_FIRST_NAME%%' ],
                             to_text   => [ $name, $uc_first_name ] });

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

sub install_distribution {
  my ( $class, $p ) = @_;
  my $old_pwd = cwd;
  
  unless ( -f $p->{package_file} ) {
    die "Package file for installation ($p->{package_file}) does not exist\n";
  }
  unless ( $p->{package_file} =~ /^\// ) {
    $p->{package_file} = join( '/', $old_pwd, $p->{package_file} );
  }

  # This is the repository we'll be using

  my $repos = $p->{repository} ||
              eval { OpenInteract::Package->fetch( 
                              undef, 
                              { directory => $p->{base_dir}, perm => 'write' } ) };
  unless ( $repos ) { die "Cannot open repository: $@\n" }
  my $base_dir = $repos->{META_INF}->{base_dir};
  
  my $base_package_file = File::Basename::basename( $p->{package_file} );
  my ( $package_base ) = $base_package_file =~ /^(.*)\.tar\.gz$/;
  _w( 1, "Package base: $package_base" );

  my $rv = $class->_extract_archive( $p->{package_file} );
  unless ( $rv ) {
    my $msg = "Failure! Error found trying to unpack the distribution! " .
              "Error: " . $ARCHIVE_ERROR;
    my $removed_files = $class->_remove_directory_tree( $package_base );
    die $msg;
  }
 
 # Read in the package config and grab the name/version

  chdir( $package_base );
  _w( 1, "Trying to find config file in ($package_base/)" );
  my $conf_file = $p->{package_conf_file} || $DEFAULT_CONF_FILE;
  my $conf    = $class->read_config( { file => $conf_file } );
  die "No valid package config read!\n" unless ( scalar keys %{ $conf } );
  my $name    = $conf->{name};
  my $version = $conf->{version};
  chdir( $old_pwd );
  
  # We're all done with the temp stuff, so get rid of it.
  
  my $removed_files = $class->_remove_directory_tree( $package_base );
  _w( 1, "Removed extracted tree so we could get the config file." );

  # Check to see if the package/version already exists
  
  my $error_msg = undef;
  my $exist_info = $repos->fetch_package_by_name({ name => $name, 
                                                   version => $version });
  if ( $exist_info ) {
    die "Failure! Cannot install since package $name-$version already " .
        "exists in the base installation repository. (It was installed on " .
        "$exist_info->{installed_on}).\n\nAborting package installation.\n";
  }
  _w( 1, "Package does not currently exist in repository." );

  # Create some directory names and move to the base package directory
  # -- the directory that holds all of the package definitions

  my $new_pkg_dir  = join( '/', 'pkg', "$name-$version" );
  my $full_pkg_dir = join( '/', $base_dir, $new_pkg_dir );
  if ( -d $full_pkg_dir ) {
    die "Failure! The directory into which the distribution should be unpacked ",
        "($full_pkg_dir) already exists. Please remove it and try again.\n";
  }
  chdir( join( '/', $base_dir, 'pkg' ) );

 # Unarchive the package; note that since the archive creates a
 # directory name-version/blah we don't need to create the directory
 # ourselves and then chdir() to it.
  
  my $extract_rv = $class->_extract_archive( $p->{package_file} );
  unless ( $extract_rv ) {
    chdir( $base_dir );
    $class->_remove_directory_tree( $full_pkg_dir );
    die "Failure! Cannot unpack the distribution into its final " .
        "directory ($full_pkg_dir)! Error: " . $ARCHIVE_ERROR;
  }
  _w( 1, "Unpackaged package into $base_dir/pkg ok" );

 # Create the package info and try to save; if we're successful, return the
 # package info.

  my $info = {
       base_dir     => $base_dir,
       package_dir  => $new_pkg_dir,
       installed_on => $repos->now,
  };
  foreach my $conf_field ( keys %{ $conf } ) {
    $info->{ $conf_field } = $conf->{ $conf_field };
  }
  _w( 1, "Trying to save package info: ", Dumper( $info ) );
  
  $repos->save_package( $info );
  eval { $repos->save() };
  if ( $@ ) {
    chdir( $base_dir );
    $class->_remove_directory_tree( $full_pkg_dir );
    die "Failure! Could not save data to installed package database. " .
        "Error returned: $@ " .
        "Aborting package installation.";
  }
  _w( 1, "Saved repository ok." );
  chdir( $old_pwd );
  return $info;
}


# Install a package from the base OpenInteract directory to a website
# directory. This is known in 'oi_manage' terms as 'applying' a
# package. 

sub install_to_website {
  my ( $class, $base_repository, $website_repository, $info ) = @_;

  # Be sure to have the website directory, website name, and package directory set
    
  die "Website name not set in package object.\n"        unless ( $info->{website_name} );
  my $package_name_version = "$info->{name}-$info->{version}";
  $info->{website_dir} ||= $website_repository->{META_INF}->{base_dir};
  $info->{package_dir} ||= join( '/', 'pkg', $package_name_version );
  
  # Then create package directory within the website directory
  
  my $pkg_dir = join( '/', $info->{website_dir}, $info->{package_dir} );
  if ( -d $pkg_dir ) { die "Package directory $pkg_dir already exists.\n" }
  mkdir( $pkg_dir, 0775 ) || die "Cannot create $pkg_dir : $!";
  
  # Next move to the base package directory (we return to the original
  # directory just before the routine exits)
  
  my $pwd = cwd;
  chdir( "$info->{base_dir}/pkg/$package_name_version" );
  
  # ...then ensure that it has all its files
  
  my @missing = ExtUtils::Manifest::manicheck;
  if ( scalar @missing ) {
    die "Cannot install package $info->{name}-$info->{version} to website ",
        "-- the base package has files that are specified in MANIFEST missing ",
        "from the filesystem: @missing. Please fix the situation.\n";
  }

 # ...and get all the filenames from MANIFEST
  
  my $BASE_FILES = ExtUtils::Manifest::maniread;
  
  # Now create the subdirectories
  
  $class->create_subdirectories( $pkg_dir, $info->{website_name} );
  
  $class->_copy_spops_config_file( $info );
  
  $class->_copy_action_config_file( $info );

  # Now copy over the struct/, script/, data/, template/, html/,
  # html/images/ and doc/ files -- intact with no translations, as
  # long as they appear in the MANIFEST file (read in earlier)

  # The value of the subdir key is the root where they will be copied

  my %subdir_match = (
      struct        => $pkg_dir,
      data          => $pkg_dir,
      template      => $pkg_dir,
      doc           => $pkg_dir,
      script        => $pkg_dir,     
      html          => $info->{website_dir},
  );

  foreach my $sub_dir ( sort keys %subdir_match ) {
    $class->_copy_package_files( $subdir_match{ $sub_dir }, 
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

  $class->_copy_handler_files( $info, $BASE_FILES );
 
  # Now go to our package directory and create a new MANIFEST file
  
  chdir( $pkg_dir );
  $class->_create_manifest();

  # Finally, save this package information to the site
  $website_repository->save_package( $info );
  $website_repository->save();

  chdir( $pwd );
  return $pkg_dir;
}



# Dump the package from the current directory (or the directory
# specified in $p->{directory} into a tar.gz distribution file

sub export {
  my ( $class, $p ) = @_;
  $p ||= {};

  my $old_pwd = cwd;
  chdir( $p->{directory} ) if ( -d $p->{directory} );

  my $cwd = cwd;
  _w( 1, "Current directory exporting from: ($cwd)" );
  
  # If necessary, Read in the config and ensure that it has all the
  # right information
  
  my $config_file = $p->{config_file} || $DEFAULT_CONF_FILE;
  my $config = $p->{config} || eval { $class->read_config( { file => $config_file } ) };
  if ( $@ ) {
    die "Failure! Package configuration file cannot be opened -- \n" ,
        "are you chdir'd to the package directory? (Reported reason \n",
        "for failure: $@\n";
  }
  _w( 1, "Package config read in: ", Dumper( $config ) );

 # Check to ensure that all required fields have something in them; we
 # might do a 'version' check in the future, but not until it proves
 # necessary
  
  my @missing_fields = ();
  foreach my $required_field ( @EXPORT_REQUIRED ) {
    push @missing_fields, $required_field unless ( $config->{ $required_field } );
  } 
  if ( scalar @missing_fields ) {
    die "Failure! Configuration file exists ($cwd/$DEFAULT_CONF_FILE) ",
        "but is missing the following fields: (",
        join( ', ', @missing_fields ), "). Please add these fields and try again.\n";
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
  
  chdir( $old_pwd );
  if ( $rv ) {
    warn "\n";
    return { name    => $config->{name}, 
             version => $config->{version},
             file    => "$filename" };
  }
  die "Failure! Cannot create distribution ($filename). Error: ", Archive::Tar->error(), "\n";
}


#
# check_package
# 
# What we check for:
#   package.conf      -- has name, version and author defined
#   conf/*.perl       -- pass an 'eval' test (through SPOPS::HashFile)
#   OpenInteract/*.pm -- pass a 'require' test
#   MyApp/*.pm        -- pass a 'require' test
#
# Parameters:
#   package_dir
#   package_name
#   website_name (optional)

sub check {
  my ( $class, $p ) = @_;
  my $status = { ok => 0 };
  if ( ! $p->{package_dir} and $p->{info} ) {
    my $main_dir = $p->{info}->{website_dir} || $p->{info}->{base_dir};
    $p->{package_dir} = join( '/', $main_dir, $p->{info}->{package_dir} );
    $p->{website_name} = $p->{info}->{website_name};
  }
  unless ( -d $p->{package_dir} ) {
    die "No valid package dir to check! (Given: $p->{package_dir})";
  }
  my $pwd = cwd;
  chdir( $p->{package_dir} );

 # First ensure all the directories and the config exist

  unless ( -d "conf/" )         { $status->{msg} .= "\n-- Config directory (conf/) does not exist in package!" }
  unless ( -d "OpenInteract/" ) { $status->{msg} .= "\n-- Module directory (OpenInteract/) does not exist in package!" }
  unless ( -f "package.conf" )  { $status->{msg} .= "\n-- Package config (package.conf) does not exist in package!" }
  if ( $p->{website_name} and ! -d "$p->{website_name}/" ) {
    $status->{msg} .= "\n-- Website directory ($p->{website_name}/) does not exist in package!";
  }
  return $status if ( $status->{msg} );

  # Set this after we do the initial sanity checks

  $status->{ok}++;

 # This is just a warning

  if ( -f 'Changes' ) {
    $status->{msg} .= "\n++ File (Changes) to show package Changelog: ok" ;
  }   
  else {
    $status->{msg} .= "\n-- File (Changes) to show package Changelog: NOT EXISTING" ;
  }

  my $pkg_files = ExtUtils::Manifest::maniread();
  
  # Now, first go through the config perl files

  my @perl_files = grep /^conf.*\.perl$/, keys %{ $pkg_files };
  foreach my $perl_file ( @perl_files ) {
    my $filestatus = 'ok';
    my $obj = eval { SPOPS::HashFile->new( { filename => $perl_file } ) };
    my $sig = '++';
    if ( $@ ) {
      $status->{ok} = 0;
      $filestatus = "cannot be read in. $@";
      $sig = '--';
    }
    $status->{msg} .= "\n$sig File ($perl_file) $filestatus";
  }

  # Next all the .pm files -- note that we suppress warnings within
  # this block

  {
    local $SIG{__WARN__} = sub { return undef };
    my @pm_files = grep /\.pm$/, keys %{ $pkg_files };
    foreach my $pm_file ( @pm_files ) {
      my $filestatus = 'ok';
      my $sig = '++';
      eval { require "$pm_file" };     
      if ( $@ ) {
        $status->{ok} = 0;
        $filestatus = "cannot be require'd.\n$@";
        $sig = '--';
      }
      $status->{msg} .= "\n$sig File ($pm_file) $filestatus";
    }
  }

  # Now open up the package.conf and check to see that name, version
  # and author exist

  my $config = $class->read_config({ directory => $p->{package_dir} });
  $status->{name} = $config->{name};
  my $conf_msg = '';
  unless ( $config->{name} )    { $conf_msg .= "\n-- package.conf: required field 'name' is not defined." }
  unless ( $config->{version} ) { $conf_msg .= "\n-- package.conf: required field 'version' is not defined." }
  unless ( $config->{author} )  { $conf_msg .= "\n-- package.conf: required field 'author' is not defined." }
  if ( $conf_msg ) {
    $status->{msg} .= $conf_msg;
    $status->{ok}   = 0;
  }
  else {
    $status->{msg} .= "\n++ package.conf: ok";
  }

  # Now do the check to ensure that all files in the MANIFEST exist --
  # just get feedback from the manifest module, don't let it print out
  # results of its findings (Quiet)

  $ExtUtils::Manifest::Quiet = 1;
  my @missing = ExtUtils::Manifest::manicheck();
  if ( scalar @missing ) {
    $status->{msg} .= "\n-- MANIFEST files not all in package. Following not found: \n     " .
                      join( "\n     ", @missing );
  }
  else {
    $status->{msg} .= "\n++ MANIFEST files all exist in package: ok";
  }

 # Now do the check to see if any extra files exist than are in the MANIFEST

  my @extra = ExtUtils::Manifest::filecheck();
  if ( scalar @extra ) {
    $status->{msg} .= "\n-- Files in package not in MANIFEST:\n     " .
                      join( "\n     ", @extra );
  }
  else {
    $status->{msg} .= "\n++ All files in package also in MANIFEST: ok";
  }

  $status->{msg} .= "\n";

  chdir( $pwd );
  return $status;
}


sub remove {
  my ( $class, $repository, $info, $opt ) = @_;
  $repository->remove_package( $info );
  $repository->save();
  my $base_dir = $info->{website_dir} || $info->{base_dir};
  my $full_dir = join( '/', $base_dir, $info->{package_dir} );
  if ( $opt eq 'directory' ) {
    return $class->_remove_directory_tree( $full_dir );
  }
  return 1;
}


sub read_config {
  my ( $class, $p )  = @_;
  if ( ( $p->{info} or $p->{directory} ) and ! $p->{file} ) {
    my $dir = $p->{directory};
    unless ( -d $dir ) {
      $dir = $p->{info}->{website_dir} || $p->{info}->{base_dir};
      $dir = join( '/', $dir, $p->{info}->{package_dir} );
    }
    $p->{file} = join( '/', $dir, $DEFAULT_CONF_FILE );
  }
  unless ( -f $p->{file} ) {
    die "Package configuration file ($p->{file}) does not exist.\n";
  }
  open( CONF, $p->{file} ) || die "Error opening $p->{file}: $!";
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


# Find a file that exists in either the website directory or the base
# installation directory. @file_list defines a number of choices
# available for the file to be named.
#
# Returns: the full path and filename of the first match

sub find_file {
  my ( $class, $info, @file_list ) = @_;
  return undef unless ( scalar @file_list );
  foreach my $base_file ( @file_list ) {
    if ( $info->{website_dir} ) {
      my $filename = join( '/', $info->{website_dir}, $info->{package_dir}, $base_file );   
      _w( 1, "Created filename <<$filename>> using the website directory" );
      return $filename if ( -f $filename );
    }
    my $filename = join( '/', $info->{base_dir}, $info->{package_dir}, $base_file );
    _w( 1, "Created filename <<$filename>> using the base installation directory" );
    return $filename if ( -f $filename );
  }
  _w( 1, "No existing filename found matching @file_list" );
  return undef;
}


# Put the base and website package directories into @INC

sub add_to_inc {
  my ( $class, $info ) = @_;
  my @my_inc = ();
  my $base_package_dir = join( '/', $info->{base_dir}, $info->{package_dir} );
  unshift @my_inc, $base_package_dir  if ( -d $base_package_dir );
  if ( $info->{website_dir} ) {
    my $app_package_dir = join( '/', $info->{website_dir}, $info->{package_dir} );
    unshift @my_inc, $app_package_dir if ( -d $app_package_dir );
  }
  unshift @INC, @my_inc;
  return @my_inc;
}


# Used to accommodate earlier versions of Archive::Tar (such as those
# shipped with ActivePerl, sigh)

# * You should already be chdir'd to the directory where this will be
# unpacked

# * I'm not sure if the version reference below is correct -- I
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


# Copy the spops.perl file from the base install package directory to
# the website package directory Note that we have changed this
# recently (Jan 01) to keep only certain configuration variables
# *behind* -- all others are copied over to the website

sub _copy_spops_config_file {
  my ( $class, $info ) = @_;
  my $interact_pkg_dir = join( '/', $info->{base_dir}, $info->{package_dir} );
  my $website_pkg_dir  = join( '/', $info->{website_dir}, $info->{package_dir} );
  
  my $spops_conf = 'conf/spops.perl';
  unless ( -f "$interact_pkg_dir/$spops_conf" ) {
    return undef;
  }
  my $spops_base  = eval { SPOPS::HashFile->new({ 
                             filename => "$interact_pkg_dir/$spops_conf" }) };
  if ( $@ ) {
    _w( 0, "Cannot eval spops.perl file in ($info->{name}-$info->{version}): $@" );
    return undef;
  }
  my $new_config_file = "$website_pkg_dir/$spops_conf";
  my $spops_pkg = SPOPS::HashFile->new({ 
                             filename => $new_config_file, 
                             perm => 'new' });

  foreach my $spops_key ( keys %{ $spops_base } ) {
    
    # Change the class to reflect the website name
    
    if ( my $old_class = $spops_base->{ $spops_key }->{class} ) {
      $spops_pkg->{ $spops_key }->{class} = $class->_change_class_name( $info, $old_class );
    }

    # Both the has_a and links_to use class names as keys to link
    # objects; change the class names from 'OpenInteract' to the
    # website name

    if ( my $old_has_a = $spops_base->{ $spops_key }->{has_a} ) {
      foreach my $old_class ( keys %{ $old_has_a } ) {
        my $new_class = $class->_change_class_name( $info, $old_class );
        $spops_pkg->{ $spops_key }->{has_a}->{ $new_class } = $old_has_a->{ $old_class };
      }
    }
    
    if ( my $old_links_to = $spops_base->{ $spops_key }->{links_to} ) {
      foreach my $old_class ( keys %{ $old_links_to } ) {
        my $new_class = $class->_change_class_name( $info, $old_class );
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
  
  eval { $spops_pkg->save({ dumper_level => 1 }) };
  die "Cannot save package spops file: $@\n"  if ( $@ );
  return $new_config_file;
}


# Copy the conf/action.perl file over from the base installation to
# the website. This is somewhat easier because there are no nested
# classes we need to modify

sub _copy_action_config_file {
  my ( $class, $info  ) = @_;
  my $interact_pkg_dir = join( '/', $info->{base_dir}, $info->{package_dir} );
  my $website_pkg_dir          = join( '/', $info->{website_dir}, $info->{package_dir} );
  _w( 1, "Coping action info from ($interact_pkg_dir) to ($website_pkg_dir)" );

  my $action_conf = 'conf/action.perl';
  my $base_config_file = "$interact_pkg_dir/$action_conf";
  my $action_base = eval { SPOPS::HashFile->new({ 
                              filename => $base_config_file }) };
  if ( $@ ) {
    _w( 1, "No action info for $info->{name}-$info->{version} (generally ok: $@)" );
    return undef;
  }
  
  my $new_config_file = "$website_pkg_dir/$action_conf";
  my $action_pkg  = eval { SPOPS::HashFile->new({ 
                              filename => $new_config_file, 
                              perm => 'new' }) };

  # Go through all of the actions and all of the keys and copy them
  # over to the new file. The only modification we make is to a field
  # named 'class': if it exists, we modify it to fit in the website's
  # namespace.

  foreach my $action_key ( keys %{ $action_base } ) {
    foreach my $action_item_key ( keys %{ $action_base->{ $action_key } } ) {
      my $value = $action_base->{ $action_key }->{ $action_item_key };
      if ( $action_item_key eq 'class' ) {
        $value = $class->_change_class_name( $info, $value );
      }
      $action_pkg->{ $action_key }->{ $action_item_key } = $value;
    }
  }
  
  eval { $action_pkg->save({ dumper_level => 1 }) };
  die "Cannot save package action file: $@\n"  if ( $@ );
  return $new_config_file;
}


# Copy files from the current directory into a website's directory

sub _copy_package_files {
  my ( $class, $root_dir, $sub_dir, $file_list ) = @_;
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
#  '$info->{website_name}::Handler::xxx'
# before writing them out to the website directory.

sub _copy_handler_files {
  my ( $class, $info, $base_files ) = @_;
  my $website_pkg_dir = join( '/', $info->{website_dir}, $info->{package_dir} );
  my @handler_file_list = grep /^OpenInteract\/Handler/, keys %{ $base_files };
  foreach my $handler_file ( @handler_file_list ) {
    my $new_filename = $class->_change_class_name( $info, "$website_pkg_dir/$handler_file" );
    open( OLDHANDLER, $handler_file )     || die "Cannot read handler ($handler_file): $!";
    open( NEWHANDLER, "> $new_filename" ) || die "Cannot write to handler ($new_filename): $!";
    my $handler_class = $handler_file;
    $handler_class  =~ s|/|::|g;
    $handler_class  =~ s/\.pm$//;
    my $new_handler_class = $class->_change_class_name( $info, $handler_class );
    _w( 1, "Old name: $handler_class; New name: $new_handler_class" );
    while ( <OLDHANDLER> ) {        
      s/$handler_class/$new_handler_class/g;
      print NEWHANDLER;
    }
    close( OLDHANDLER );
    close( NEWHANDLER );
  }
  return \@handler_file_list;
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
  _w( 1, "Removed ($removed_files) files/directories from ($dir)" );
  return $removed_files;
}


# Modify the first argument by replacing 'OpenInteract' with either
# the second argument or the property 'website_name' of the zeroth
# argument.

sub _change_class_name {
  my ( $class, $info, $old_class, $new_name ) = @_;
  if ( ref $info and ! $new_name ) {
    $new_name = $info->{website_name};
  }
  $old_class =~ s/OpenInteract/$new_name/g;
  return $old_class;
}


sub _w {
  my $lev = shift;
  return unless ( DEBUG >= $lev );
  my ( $pkg, $file, $line ) = caller;
  my @ci = caller(1);
  warn "$ci[3] ($line) >> ", join( ' ', @_ ), "\n";
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Package - Perform actions on individual packages

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

B<create_subdirectories( $root_dir, $main_class )>

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

B<install_distribution>

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

B<read_config( \%params )>

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

Parameters:

 file
   Full filename of package file to be read in

 info
   Hashref of package information to read package config from

 directory
   Directory from which to read the package config.

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

=head1 BUGS

=head1 SEE ALSO

L<OpenInteract::Package>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
