package OpenInteract2::Package;

# $Id: Package.pm,v 1.36 2004/02/18 05:25:26 lachoy Exp $

use strict;
use base qw( Exporter Class::Accessor::Fast );
use Archive::Zip             qw( :ERROR_CODES );
use Cwd                      qw( cwd );
use Data::Dumper             qw( Dumper );
use Digest::MD5              qw();
use ExtUtils::Manifest       ();
use File::Basename           qw( basename dirname );
use File::Copy               qw( cp );
use File::Path               ();
use File::Spec::Functions    qw( :ALL );
use File::Temp               qw( tempdir );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Config::Package;
use OpenInteract2::Config::PackageChanges;
use OpenInteract2::Config::Readonly;
use OpenInteract2::Config::TransferSample;
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Repository;
use OpenInteract2::Util;

$OpenInteract2::Package::VERSION   = sprintf("%d.%02d", q$Revision: 1.36 $ =~ /(\d+)\.(\d+)/);

my ( $log );
@OpenInteract2::Package::EXPORT_OK = qw( DISTRIBUTION_EXTENSION );

use constant DISTRIBUTION_EXTENSION => 'zip';

# Define the subdirectories present in a default package

my @PKG_SUBDIR = qw(
    conf data doc msg struct template script html html/images
    OpenInteract2 OpenInteract2/Action OpenInteract2/SQLInstall
);

my @FIELDS = qw( package_file directory name version
                 repository installed_date config );
OpenInteract2::Package->mk_accessors( @FIELDS );

########################################
# CONSTRUCTOR

sub new {
    my ( $class, $params ) = @_;
    $log ||= get_logger( LOG_OI );

    my $self = bless( {}, $class );
    my ( $to_read );
    if ( ref $params->{package_config} eq 'OpenInteract2::Config::Package' ) {
        $params->{directory} = $params->{package_config}->package_dir;
    }
    if ( $params->{package_file} ) {
        unless ( -f $params->{package_file} ) {
            oi_error "Cannot initialize package with non-existent package ",
                     "file. (Given [$params->{package_file}])";
        }
        my $full_path = rel2abs( $params->{package_file} );
        $log->is_debug &&
            $log->debug( "Setting full path for package file [$full_path]" );
        $self->package_file( $full_path );
        $to_read++;
    }
    elsif ( $params->{directory} ) {
        unless ( -d $params->{directory} ) {
            oi_error "Cannot initialize package with non-existent package ",
                     "directory. (Given [$params->{directory}])";
        }
        $self->directory( rel2abs( $params->{directory} ) );
        $to_read++;
    }
    $self->_read_package_data if ( $to_read );
    $self->repository( $params->{repository} ) if ( $params->{repository} );
    return $self;
}


sub _read_package_data {
    my ( $self ) = @_;
    if ( $self->directory ) {
        $self->_read_info_from_dir;
    }
    elsif ( $self->package_file ) {
        $self->_read_info_from_file;
    }
    else {
        oi_error "You must have set either 'directory' or 'package_file' ",
                 "to be able to read the package data";
    }
}

# Explode the info into a temp directory, then run _read_info_from_dir
# with the temp dir as a parameter. Note: we cleanup the temp_dir on
# DESTROY.

sub _read_info_from_file {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_OI );

    my $tmp_dir = tempdir( 'OIPKGXXXX', TMPDIR => 1, CLEANUP => 1 );
    unless ( -d $tmp_dir and -w $tmp_dir ) {
        oi_error "Cannot find writeable temp dir";
    }
    my $pwd = cwd();
    chdir( $tmp_dir );

    my $package_file = $self->package_file;
    $log->is_debug &&
        $log->debug( "Reading package info from [$package_file]" );
    eval {
        my $filename = basename( $self->package_file );
        my $ext = '.' . DISTRIBUTION_EXTENSION;
        my ( $subdir ) = $filename =~ /^(.*)$ext$/;
        $self->_extract_archive( $self->package_file );
        my $extracted_dir = catdir( $tmp_dir, $subdir );
        $self->_read_info_from_dir( $extracted_dir );
        $self->_read_manifest( $extracted_dir );
        $self->{_tmp_package_extract_dir} = $tmp_dir;

        # This might seem really weird, but other objects (like
        # OI2::Config::PackageChanges) rely on the package being able
        # to report SOME sort of directory.

        $self->directory( $extracted_dir );
    };
    my $error = $@;
    chdir( $pwd );
    oi_error $error if ( $error );
    return $self;
}


# Read in the cofiguration object and the name, version.

sub _read_info_from_dir {
    my ( $self, $dir ) = @_;
    $log ||= get_logger( LOG_OI );

    $dir ||= $self->directory;
    unless ( -d $dir ) {
        oi_error "Cannot read package information from invalid ",
                 "directory [$dir]";
    }

    $log->is_debug &&
        $log->debug( "Reading package info from [$dir]" );
    $self->config( OpenInteract2::Config::Package->new({ directory => $dir }) );
    $self->name( $self->config->name );
    $self->version( $self->config->version );
    return $self;
}


########################################
# PROPERTIES

sub full_name {
    my ( $self ) = @_;
    return join( '-', $self->name, $self->version );
}

# don't use split here since the package name might have a '-' in it
# (shouldn't happen, but still)

sub parse_full_name {
    my ( $class, $full_name ) = @_;
    my ( $name, $version ) = $full_name =~ /^(.*)\-(.*)$/;
    return ( $name, $version );
}

# Get the changelog

sub get_changes {
    my ( $self ) = @_;
    return OpenInteract2::Config::PackageChanges->new({ package => $self });
}

# Get a list of files from the MANIFEST

sub get_files {
    my ( $self, $force ) = @_;
    $self->{_manifest} ||= [];
    if ( scalar @{ $self->{_manifest} } == 0 or $force ) {
        $self->{_manifest} = $self->_read_manifest;
    }
    return $self->{_manifest};
}


# Return a sorted arrayref of files in MANIFEST

sub _read_manifest {
    my ( $self, $manifest_dir ) = @_;
    unless ( $manifest_dir ) {
        $manifest_dir = $self->directory;
    }
    unless ( -d $manifest_dir ) {
        oi_error "Cannot read files from MANIFEST in [$manifest_dir]: ",
                 "the directory is invalid";
    }
    my $pwd = cwd();
    chdir( $manifest_dir );
    my $file_map = ExtUtils::Manifest::maniread;
    chdir( $pwd );
    return [ sort keys %{ $file_map } ];
}


########################################
# FILES/FILE SPECS

sub get_module_files {
    my ( $self ) = @_;
    my $files = $self->get_files;
    my @module_files = grep /\.pm/, @{ $files };
    my @module_specs = ();
    foreach my $module_file ( @module_files ) {
        my ( $vol, $dirs, $file ) = splitpath( $module_file );
        my @spec = splitdir( $dirs );
        pop @spec;
        push @spec, $file;
        push @module_specs, \@spec;
    }
    return \@module_specs;
}

sub get_spops_files {
    my ( $self ) = @_;
    my $base_files = $self->config->get_spops_files;

    # If none returned, try to find our own
    unless ( scalar @{ $base_files } ) {
        my $files = $self->get_files;
        $base_files = [ grep { m|^conf/spops.*\.ini$| } @{ $files } ];
    }
    my $dir = $self->directory;
    my @spops_files = map { catfile( $dir, $_ ) } @{ $base_files };
    $self->_check_file_validity( \@spops_files );
    return $base_files
}

sub get_action_files {
    my ( $self ) = @_;
    my $base_files = $self->config->get_action_files;

    # If none returned, try to find our own
    unless ( scalar @{ $base_files } ) {
        my $files = $self->get_files;
        $base_files = [
            grep { m|^conf/action.*\.ini$| } @{ $files }
        ];
    }
    my $dir = $self->directory;
    my @action_files = map { catfile( $dir, $_ ) }
                           @{ $base_files };
    $self->_check_file_validity( \@action_files );
    return $base_files
}

sub get_doc_files {
    my ( $self ) = @_;
    my $files = $self->get_files;
    my @base_doc_files = grep { m|^doc| } @{ $files };
    my $dir = $self->directory;
    my @check_files = map { catfile( $dir, $_ ) }
                          @base_doc_files;
    $self->_check_file_validity( \@check_files );
    return \@base_doc_files;
}

sub get_message_files {
    my ( $self ) = @_;
    my $base_files = $self->config->get_message_files;

    # If none returned, try to find our own
    unless ( scalar @{ $base_files } ) {
        my $files = $self->get_files;
        $base_files = [ grep { m|^msg/.*\.msg$| } @{ $files } ];
    }
    my $dir = $self->directory;
    my @full_message_files = map { catfile( $dir, $_ ) } @{ $base_files };
    $self->_check_file_validity( \@full_message_files );
    return $base_files;
}

sub _check_file_validity {
    my ( $self, $files ) = @_;
    foreach my $file ( @{ $files } ) {
        unless ( -f $file ) {
            oi_error "Package file returned [$file] is invalid.";
        }
    }
}

########################################
# INSTALL PACKAGE (CLASS)

sub install {
    my ( $class, $params ) = @_;
    $log ||= get_logger( LOG_OI );

    my $repository = $class->_install_get_repository( $params );
    my $package_file = rel2abs( $params->{package_file} );
    unless ( -f $package_file ) {
        oi_error "Valid package file must be specified in 'package_file'";
    }
    $log->is_debug &&
        $log->debug( "Install info - [File: $package_file] ",
                     "[Website dir: ", $repository->website_dir, "]" );

    my $pwd = cwd();

    # This should unpack the package into a temp dir, and deleting the
    # object (at the end of the method) should run DESTROY which
    # clears out that temp dir

    my $tmp_package = $class->new({ package_file => $package_file });
    my $tmp_config = $tmp_package->config;

    my $name    = $tmp_config->name;
    my $version = $tmp_config->version;
    unless ( $name and $version ) {
        oi_error "Package configuration not read or seems to be in ",
                 "error [Name: $name] [Version: $version]";
    }

    $class->_install_check_modules( $tmp_config );

    my $full_package_dir = 
        $class->_install_check_dest_dir( $tmp_config, $repository );
    chdir( $repository->full_package_dir );

    # Unarchive the package into the current directory; this will
    # create the directory name-version/

    eval { $class->_extract_archive( $package_file ) };
    if ( $@ ) {
        chdir( $pwd );
        $class->_remove_directory_tree( $full_package_dir );
        oi_error "Cannot unpack the distribution into its final ",
                 "directory [$full_package_dir]: $@";
    }
    $log->is_info &&
        $log->info( "Unpacked package into [$full_package_dir] ok" );

    my $installed_package = $class->new({ directory  => $full_package_dir,
                                          repository => $repository });
    $installed_package->installed_date( scalar( localtime ) );
    my $copied_files = $installed_package->_install_copy_files;
    $log->is_info &&
        $log->info( "Copied package files to website ok" );

    $repository->add_package( $installed_package );
    $log->is_info &&
        $log->info( "Saved repository with new package ok." );

    undef $tmp_package;
    chdir( $pwd );
    return $installed_package;
}


########################################
# PACKAGE SKELETON (CLASS)

# Creates a package directories using our base subdirectories
# along with a package.conf file and some other goodies (?)

# Currently we're taking the strategy that exceptions from the action
# subroutines will bubble up to the caller

sub create_skeleton {
    my ( $class, $params ) = @_;
    my $name = $params->{name};
    unless ( $name ) {
        oi_error "Must pass in package name to create in 'name'";
    }

    # Both of these will throw an error on failure

    my $sample_dir = $class->_skel_get_sample_dir( $params );
    $name = $class->_skel_clean_package_name( $name );

    # Ensure the package dir doesn't already exist

    my $full_skeleton_dir = rel2abs( $name );
    if ( -d $full_skeleton_dir ) {
        oi_error "Cannot create package destination directory ",
                 "'$full_skeleton_dir' already exists";
    }

    eval { mkdir( $full_skeleton_dir, 0777 ) || die $! };
    if ( $@ ) {
        oi_error "Failed to create package directory ",
                 "'$full_skeleton_dir': $@";
    }

    eval {
        $class->_skel_create_subdirectories(
            $full_skeleton_dir );
        $class->_skel_copy_sample_files(
            $name, $sample_dir, $full_skeleton_dir );
        $class->_skel_create_changelog(
            $name, $full_skeleton_dir, 'Changes' );
        $class->_skel_create_manifest(
            $full_skeleton_dir );
    };
    if ( $@ ) {
        $class->_remove_directory_tree( $full_skeleton_dir );
        oi_error $@;
    }
    my $created_package = $class->new({ directory => $full_skeleton_dir });
    return $created_package;
}



########################################
# EXPORT PACKAGE

# Dump the package from its directory into a .zip distribution file

sub export {
    my ( $self ) = @_;
    unless ( $self->directory and -d $self->directory ) {
        oi_error "Package must have valid directory set for 'export'";
    }
    $self->config->check_required_fields;
    $self->_export_check_manifest;
    my $archive_filename = eval { $self->_export_archive_package };
    if ( $@ ) {
        oi_error $@;
    }
    return $archive_filename;
}



########################################
# CHECK PACKAGE

sub check {
    my ( $self ) = @_;
    unless ( $self->directory and -d $self->directory ) {
        oi_error "Package must have valid directory set for 'check'";
    }
    my $pwd = cwd();
    chdir( $self->directory );

    my @status = ();

    # This is just a warning...

    my $changes_msg = ( -f 'Changes' )
                        ? 'Package changelog (Changes) exists'
                        : 'Package changelog (Changes) DOES NOT EXIST. ' .
                          'People should know about your changes.';
    push @status, { is_ok    => 'yes',
                    action   => 'Changelog check',
                    filename => 'Changes',
                    message  => $changes_msg };

    my $pkg_files = $self->get_files;

    push @status, $self->_check_manifest;
    push @status, $self->_check_package_config;

    my @ini_files = grep /^conf.*\.ini$/, @{ $pkg_files };
    push @status, $self->_check_ini_files( \@ini_files );

    my @pm_files = grep /\.pm$/, @{ $pkg_files };
    push @status, $self->_check_pm_files( \@pm_files );

    my @data_files = grep /^data\/.*\.dat$/, @{ $pkg_files };
    push @status, $self->_check_data_files( \@data_files );

    my @template_files = grep /^(template\/.*\.tmpl|widget)/, @{ $pkg_files };
    push @status, $self->_check_templates( \@template_files );

    chdir( $pwd );
    return @status;
}


########################################
# REMOVE PACKAGE

# Removes package from repository. Errors should bubble up

sub remove {
    my ( $self, $repository ) = @_;
    my ( $status );
    $repository ||= $self->repository;
    if ( $repository ) {
        eval { $repository->remove_package( $self ) };
        if ( $@ ) {
            $status = "FAILED: $@";
        }
        else {
            $status = 'ok';
        }
    }
    else {
        $status = 'No repository set in package object, so the package ' .
                  'could not be removed from the repository.';
    }
    return { action  => 'Remove Package',
             message => $status };
}


########################################
# FILE/DIR UTILS

sub generate_distribution_digest {
    my ( $class, $package_file ) = @_;
    unless ( -f $package_file ) {
        oi_error "Cannot generate digest: file [$package_file] invalid";
    }
    my $fh = IO::File->new( $package_file );
    $fh->binmode;
    my $digest = Digest::MD5->new->addfile( $fh )->hexdigest;
    $fh->close;
    return $digest;
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
        my $filename = catfile( $self->directory, $base_file );
        return $filename if ( -f $filename );
    }
    return undef;
}


# Slurps the $relative_filename into a variable and returns it
# TODO: Used?

sub read_file {
    my ( $self, $relative_filename ) = @_;
    my $full_file = $self->find_file( $relative_filename );
    return undef unless ( $full_file );
    open( IN, '<', $full_file )
                    || die "Cannot read [$full_file]: $!";
    my @content = <IN>;
    close( IN );
    return join( '', @content );
}


# auxiliary routine to create necessary directories for a file, given
# the file; die on error, otherwise return a true value

sub _create_full_path {
    my ( $class, $filename ) = @_;
    my $dirname = dirname( $filename );
    return 1 if ( -d $dirname );

    # NOTE: At least on 5.6.1, File::Path automatically dies when the
    # operation fails -- you don't need '|| die $!'

    File::Path::mkpath( $dirname, undef, 0755 );
    return 1;

}


# Remove a directory and all files/directories beneath it. Return the
# number of removed files.

sub _remove_directory_tree {
    my ( $class, $dir ) = @_;
    return File::Path::rmtree( $dir, undef, undef );
}


########################################
# INSTALL PACKAGE HELPERS

# When installing a package, there are files in two (so far)
# directories that can be copied up to the main website
# directory. Files placed in 'html/' get copied to $WEBSITE_DIR/html
# and files in 'widget/' get copied to $WEBSITE_DIR/template.

# TODO: See note in POD about html files and page objects

sub _install_get_repository {
    my ( $class, $params ) = @_;
    my ( $repository );
    if ( $params->{website_dir} and -d $params->{website_dir} ) {
        $repository = OpenInteract2::Repository->new(
                         { website_dir => $params->{website_dir} });
    }
    elsif ( $params->{repository} ) {
        $repository = $params->{repository};
    }

    if ( $repository ) {
        my $install_dir = $repository->full_package_dir;
        unless ( -d $install_dir ) {
            oi_error "Specified installation directory [$install_dir] ",
                     "is invalid";
        }
    }
    else {
        oi_error "No 'website_dir' or 'repository' specified -- cannot ",
                 "install package to unknown location.";
    }
    return $repository;
}


# See if the package has specified any modules that are necessary for
# its operation. For now, we will refuse to install a package that
# does not have supporting modules.

sub _install_check_modules {
    my ( $class, $config ) = @_;
    my $module = $config->module;
    return unless ( ref $module eq 'ARRAY' and scalar @{ $module } );
    my @failed_modules = $class->_check_module_install( @{ $module } );
    return unless ( scalar @failed_modules );
    oi_error "Package [", $config->name, "] requires the following ",
             "modules that are not currently installed:\n  ",
             join( ', ', @failed_modules ), "\n",
             "Please install them and then reinstall.";
}

sub _install_check_dest_dir {
    my ( $class, $config, $repository ) = @_;
    my $full_package_name = join( '-', $config->name, $config->version );
    my $full_package_dir = catfile(
                               $repository->full_package_dir,
                               $full_package_name );
    if ( -d $full_package_dir ) {
        oi_error "The directory into which the distribution should be ",
                 "unpacked [$full_package_dir] already exists.";
    }
    return $full_package_dir;
}

sub _install_copy_files {
    my ( $self ) = @_;
    unless ( $self->repository ) {
        my $pkg_dir = rel2abs( $self->directory );
        warn "Cannot copy files from package [", $self->name, "] to ",
             "website because there is no repository set in package. ",
             "You will need to copy the files from [$pkg_dir/html] and ",
             "[$pkg_dir/widget] (if they exist) to the website manually.\n";
        return;
    }

    my %file_map = map { $_ => 1 } @{ $self->get_files };

    my @html_files = grep /^html/, keys %file_map;
    my @html_dest_full = $self->_install_package_files_to_website(
                                   \@html_files );

    my @widget_files = grep /^widget/, keys %file_map;
    my @widget_dest_files = @widget_files;
    s|^widget|template| for ( @widget_dest_files );
    my @widget_dest_full = $self->_install_package_files_to_website(
                                   \@widget_files, \@widget_dest_files );
    return [ @html_dest_full, @widget_dest_full ];
}


sub _install_package_files_to_website {
    my ( $self, $base_files, $dest_files ) = @_;
    $log ||= get_logger( LOG_OI );

    $dest_files ||= [];
    my $website_dir = $self->repository->website_dir;
    my $package_dir = rel2abs( $self->directory );
    my $BACKUP_EXT = 'pkg_install_backup';
    my ( @copy_files );
    eval {
        my $count = 0;
        foreach my $from_base ( @{ $base_files } ) {

            # By default we copy relpath/filename -> relpath/filename
            # from $base_files unless something specified in
            # corresponding \@dest_files entry

            my $to_base = $dest_files->[ $count ] || $from_base;

            my $full_dest_path = catfile( $website_dir, $to_base );
            $self->_create_full_path( $full_dest_path );

            # Yeah, this is slightly inefficient, but (a) it's much
            # simpler than the alternative, (2) there aren't many
            # times where packages have files to copy and (iii) you
            # don't install packages very often...

            my $can_copy = OpenInteract2::Config::Readonly
                              ->is_writeable_file( dirname( $full_dest_path ),
                                                   $full_dest_path );
            next unless ( $can_copy );
            my $full_source_path = catfile(
                                        $package_dir, $from_base );

            # Backup the file if it already exists

            if ( -f $full_dest_path ) {
                rename( $full_dest_path, "$full_dest_path.$BACKUP_EXT" )
                    || die "Cannot backup [$full_dest_path]: $!";
            }
            cp( $full_source_path, $full_dest_path )
                    || die "Cannot copy [$full_source_path] -> [$full_dest_path]: $!";
            chmod( 0666, $full_dest_path ); # let umask work...
            push @copy_files, $full_dest_path;
            $count++;
        }
    };
    if ( $@ ) {
        $log->error( "Caught error copying files to website: $@" );
        foreach my $filename ( @copy_files ) {
            unlink( $filename )
                    || warn "Cannot cleanup '$filename': $!";
            if ( -f "$filename.$BACKUP_EXT" ) {
                rename( "$filename.$BACKUP_EXT", $filename )
                    || warn "Cannot activate backup for '$filename': $!";
                unlink( "$filename.$BACKUP_EXT" )
                    || warn "Cannot remove stale backup for '$filename': $!";
            }
        }
        @copy_files = ();
    }
    return \@copy_files;
}


########################################
# PACKAGE SKELETON HELPERS

# Must specify one of:
#   source_dir = /usr/local/src/OpenInteract-2.01
#   sample_dir = /usr/local/src/OpenInteract-2.01/sample/package

sub _skel_get_sample_dir {
    my ( $class, $params ) = @_;
    my $sample_dir = $params->{sample_dir};
    my $source_dir = $params->{source_dir};

    # If the source_dir is specified and the sample_dir isn't, build
    # the sample dir from the source dir

    if ( $source_dir && -d $source_dir &&
         ( ! $sample_dir || ! -d $sample_dir ) ) {
        $sample_dir = catdir( $source_dir, 'sample', 'package' );
    }
    if ( $sample_dir ) {
        $sample_dir = rel2abs( $sample_dir );
    }
    unless ( $sample_dir && -d $sample_dir ) {
        oi_error "Specified sample directory '$sample_dir' is ",
                 "not a valid directory";
    }
    return $sample_dir;
}

# Ensure a package name is ok and that it can be used as a namespace
# when necessary.
#   - Package name cannot be blank (empty and/or all spaces)
#   - Package name cannot have spaces (s/ /_/)
#   - Package name cannot have dashes (s/-/_/)
#   - Package name cannot start with a number (die)
#   - Package name cannot have nonword characters except '_'

sub _skel_clean_package_name {
    my ( $class, $name ) = @_;
    my ( @failures );

    $name =~ /^\s*$/
        && push @failures, "Name must not be blank";
    $name =~ s/ /_/g 
        && push @failures, "Name must not have spaces";
    $name =~ s/\-/_/g
        && push @failures, "Name must not have dashes";
    $name =~ /^\d/
        && push @failures, "Name must not start with a number";
    $name =~ /\W/
        && push @failures, "Name must not have non-word characters";

    if ( scalar @failures ) {
        oi_error "Package name '$name' unacceptable: \n",
                 join( "\n", @failures ), "\n";
    }
    return $name;
}

# Create subdirectories within a package

sub _skel_create_subdirectories {
    my ( $class, $base_dir ) = @_;
    my @to_create = map { catdir( $base_dir, $_ ) } @PKG_SUBDIR;
    for ( my $i = 0; $i < scalar @to_create; $i++ ) {
        eval { mkdir( "$to_create[ $i ]", 0777 ) || die $! };

        # If we fail, see if we can cleanup our mess

        if ( $@ ) {
            my $error = $@;
            for ( my $j = 0; $j < $i; $j++ ) {
                eval {
                    $class->_remove_directory_tree( "$to_create[ $j ]" )
                };
                warn "In process of cleaning up after failure, also ",
                     "failed to remove directory [$to_create[$j]: $@";
            }
            oi_error "Failed to package subdirectory ",
                     "[$to_create[ $i ]]: $error";
        }
    }
    return \@to_create;
}


# Copies over the sample skeleton files from the sample directory in
# the OI2 source to a new package directory, making some simple
# variable substitutions along the way.

sub _skel_copy_sample_files {
    my ( $class, $name, $sample_dir, $dest_dir ) = @_;
    my $class_name = ucfirst $name;
    $class_name =~ s/_(\w)/\U$1\U/g;
    my %vars = ( package_name => $name,
                 class_name   => $class_name );

    return OpenInteract2::Config::TransferSample
                         ->new( $sample_dir )
                         ->run( $dest_dir, \%vars );
}

# Create a 'Changes' file

sub _skel_create_changelog {
    my ( $class, $package_name, $package_dir, $filename ) = @_;
    my $full_filename = catfile( $package_dir, $filename );
    eval { open( CHANGES, '>', $full_filename ) || die $! };
    if ( $@ ) {
        oi_error "Cannot create changelog [$filename]: $@";
    }
    my $time_stamp = scalar localtime;
    print CHANGES <<INIT;
Revision history for OpenInteract2 package $package_name.

0.01  $time_stamp

      Package skeleton created by OpenInteract2::Package

INIT
    close( CHANGES );
}

# Create a manifest file in the current directory. (Note that the
# 'Quiet' and 'Verbose' parameters won't work properly until
# ExtUtils::Manifest is patched which won't likely be until 5.6.1)

sub _skel_create_manifest {
    my ( $class, $package_dir ) = @_;
    my $pwd = cwd();
    chdir( $package_dir );
    local $SIG{__WARN__} = sub { return undef };
    $ExtUtils::Manifest::Quiet   = 1;
    $ExtUtils::Manifest::Verbose = 0;
    ExtUtils::Manifest::mkmanifest();
    chdir( $pwd );
}


########################################
# EXPORT PACKAGE HELPERS

sub _export_check_manifest {
    my ( $self  ) = @_;
    my $pwd = cwd();
    chdir( $self->directory );
    local $ExtUtils::Manifest::Quiet = 1;
    my @missing = ExtUtils::Manifest::manicheck();
    chdir( $pwd );
    if ( scalar @missing ) {
        oi_error "Files in MANIFEST not found in package: ",
                 join( ', ', @missing );
    }
}


# Create a directory, copy package files to it, zip up the directory
# and then remove the directory. Errors should bubble up from routines
# we call.

sub _export_archive_package {
    my ( $self ) = @_;
    my $package_id = $self->full_name;
    my $export_dir = rel2abs( $package_id );
    if ( -d $export_dir ) {
        oi_error "Directory [$export_dir] already exists. Please ",
                 "remove it before exporting package.";
    }
    eval { mkdir( $export_dir, 0777 ) || die $! };
    if ( $@ ) {
        oi_error "Cannot create directory [$export_dir] used to ",
                 "archive package: $@";
    }

    # NOTE: Use the EU::MM utilities for this, even though we have a
    # 'get_files' method here (manicopy() wants a hashref for the
    # first argument...)

    my $pwd = cwd();
    chdir( $self->directory );
    my $package_files = ExtUtils::Manifest::maniread();
    local $ExtUtils::Manifest::Quiet = 1;
    ExtUtils::Manifest::manicopy( $package_files, $export_dir );
    chdir( $pwd );

    # NOTE: Don't use File::Spec here, since Archive::Zip expects the
    # files to be separated by '/'

    my @archive_files = map { "$package_id/$_" } keys %{ $package_files };
    my $filename = eval {
        $self->_create_archive( $pwd, $package_id, @archive_files )
    };
    my $error = $@;
    $self->_remove_directory_tree( $export_dir );
    oi_error $error if ( $error );
    return $filename;
}


########################################
# ARCHIVE MANIPULATION

# NOTE: We've moved from using Archive::Tar in 1.x to using
# Archive::Zip in 2.x, since the latter is better supported on Win32
# systems.

sub _create_archive {
    my ( $self, $dir, $base_filename, @files ) = @_;
    unless ( -d $dir and $base_filename and scalar @files ) {
        oi_error "Insufficient parameters to create archive ",
                 "[Dir: $dir] [File: $base_filename] [@files]";
    }

    my $zip_filename = catfile( $dir, join( '.', $base_filename, 'zip' ) );
    if ( -f $zip_filename ) {
        oi_error "Cannot create ZIP archive: [$zip_filename] already exists";
    }

    my $zip = Archive::Zip->new();
    $zip->addFile( $_ ) for ( @files );
    my $rv = $zip->writeToFileNamed( $zip_filename );
    unless ( $rv == AZ_OK ) {
        my ( $msg );
        $msg = 'The read stream (or central directory) ended normally.' if ( $rv == AZ_STREAM_END );
        $msg = 'There was some generic kind of error.'                  if ( $rv == AZ_ERROR );
        $msg = 'There is a format error in a ZIP file being read.'      if ( $rv == AZ_FORMAT_ERROR );
        $msg = 'There was an IO error.'                                 if ( $rv == AZ_IO_ERROR );
        $msg ||= 'Unknown error';
        oi_error "Failed to create ZIP archive [$zip_filename]: $msg";
    }
    return $zip_filename;
}


sub _extract_archive {
    my ( $class, $filename ) = @_;
    unless ( -f $filename ) {
        oi_error "Cannot extract archive from [$filename]: invalid file";
    }
    my $zip = Archive::Zip->new( $filename );
    unless ( $zip ) {
        oi_error "Failed to read ZIP file [$filename]";
    }
    my @extracted = ();
    my @errors = ();
    foreach my $to_extract ( $zip->members() ) {
        my $rv = $zip->extractMember( $to_extract );
        my $label = "Error extracting $to_extract";
        if ( $rv == AZ_OK ) {
            push @extracted, $to_extract;
        }
        elsif ( $rv == AZ_STREAM_END ) {
            push @errors, "$label: read stream or central directory " .
                          "ended normally";
        }
        elsif ( $rv == AZ_FORMAT_ERROR ) {
            push @errors, "$label: format error in the ZIP file";
        }
        elsif ( $rv == AZ_IO_ERROR ) {
            push @errors, "$label: I/O error";
        }
        elsif ( $rv == AZ_ERROR ) {
            push @errors, "$label: some generic error";
        }
        else {
            push @errors, "$label: unknown Archive::Zip error ($rv)";
        }
    }
    if ( scalar @errors ) {
        oi_error "Errors unzipping files from [$filename]:\n  - ",
                 join( "\n  - ", @errors );
    }
    return \@extracted;
}


########################################
# CHECK PACKAGE HELPERS

sub _check_ini_files {
    my ( $self, $files ) = @_;
    my @status = ();
    foreach my $ini_file ( sort @{ $files } ) {
        my $s = { action => 'Check ini file', filename => $ini_file };
        eval { OpenInteract2::Config->new( 'ini', { filename => $ini_file } ) };
        if ( $@ ) {
            $s->{is_ok}   = 'no';
            $s->{message} = "Cannot be read: $@";
        }
        else {
            $s->{is_ok}   = 'yes';
            $s->{message} = 'Read ok';
        }
        push @status, $s;
    }
    return @status;
}


# Note that we suppress warnings within this routine

sub _check_pm_files {
    my ( $self, $files ) = @_;
    local $SIG{__WARN__} = sub { return undef };
    my @status = ();
    foreach my $pm_file ( sort @{ $files } ) {
        my $s = { action => 'Check module', filename => $pm_file };

        # Be sure we're not just getting the results of a cached
        # operation
        delete $INC{ $pm_file } if ( $INC{ $pm_file } );

        eval { require "$pm_file" };
        if ( $@ ) {
            $s->{is_ok}   = 'no';
            $s->{message} = "Perl syntax/include check failed: $@";
        }
        else {
            $s->{is_ok}   = 'yes';
            $s->{message} = "Perl syntax/include check ok";
        }
        push @status, $s;
    }
    return @status;
}


sub _check_data_files {
    my ( $self, $files ) = @_;
    my @status = ();
    foreach my $data_file ( sort @{ $files } ) {
        my $s = { action => 'Check data file', filename => $data_file };
        eval { OpenInteract2::Util->read_file_perl( $data_file ) };
        if ( $@ ) {
            $s->{is_ok}   = 'no';
            $s->{message} = "Not a valid Perl structure: $@"
        }
        else {
            $s->{is_ok}   = 'yes';
            $s->{message} = "File is a valid Perl data structure";
        }
        push @status, $s;
    }
    return @status;
}


# See if all the templates pass a basic syntax test -- do not log
# 'plugin not found' or 'no providers for template prefix' errors,
# since we assume those will be ok when it runs in the
# environment. (This could probably use some work, since the 'include'
# errors may happen before basic syntax checking, which is the main
# point of this...)

sub _check_templates {
    my ( $self, $files ) = @_;
    require Template;
    my $template = Template->new();
    my ( $out );
    my @template_errors_ok = ( 'not found',
                               'no providers for template prefix',
                               'file error' );
    my $template_errors_re = '^(' . join( '|', @template_errors_ok ) . ')';
    my @status = ();
    foreach my $template_file ( sort @{ $files } ) {
        my $s = { action => 'Template check', filename => $template_file };
        if ( -f $template_file ) {
            eval {
                $template->process( $template_file, undef, \$out )
                    || die $template->error(), "\n"
                };
            if ( $@ ) {
                if ( $@ =~ /$template_errors_re/ ) {
                    $s->{is_ok}   = 'yes';
                    $s->{message} = "Template '$template_file' syntax seems to be ok";
                }
                else {
                    $s->{is_ok}   = 'no';
                    $s->{message} = $@;
                }
            }
            else {
                $s->{is_ok}   = 'yes';
                $s->{message} = "Template '$template_file' syntax ok";
            }
        }
        else {
            $s->{is_ok}       = 'no';
            $s->{message}     = "Template file '$template_file' does not exist";
        }
        push @status, $s;
    }
    return @status;
}


# Ensure that the package config has all necessary fields

sub _check_package_config {
    my ( $self ) = @_;

    my $config = $self->config;
    my $base_filename = $config->filename;
    my $package_dir   = $config->package_dir;
    $base_filename =~ s|^$package_dir/||;
    my %req_s = ( action   => 'Config required fields',
                  filename => $base_filename );

    eval { $config->check_required_fields( 'author' ) };
    if ( $@ ) {
        $req_s{is_ok}   = 'no';
        $req_s{message} = "$@";
    }
    else {
        $req_s{is_ok}   = 'yes';
        $req_s{message} = 'All required fields in package configuration defined';
    }

    my %module_s = ( action => 'Config defined modules' );
    if ( ref $config->module eq 'ARRAY' and scalar @{ $config->module } ) {
        my @failed_modules = $self->_check_module_install( @{ $config->module } );
        if ( scalar @failed_modules ) {
            $module_s{is_ok}   = 'no';
            $module_s{message} = 'Following modules must be installed: ' .
                                 join( ', ', @failed_modules );
        }
        else {
            my $required = join( ', ', @{ $config->module } );
            $module_s{is_ok}   = 'yes';
            $module_s{message} = "All modules required by package are installed: $required";
        }
    }
    else {
        $module_s{is_ok}   = 'yes';
        $module_s{message} = 'No modules defined, test skipped';
    }
    return ( \%req_s, \%module_s );
}


sub _check_module_install {
    my ( $self, @modules ) = @_;
    my ( @failed_modules );
MODULE:
    foreach my $module ( @modules ) {
        next unless ( $module );
        if ( $module =~ /\|\|/ ) {
            my @alt_modules = split /\s*\|\|\s*/, $module;
            foreach my $alt_module ( @alt_modules ) {
                eval "require $alt_module";
                next MODULE unless ( $@ );
            }
            push @failed_modules, join( ' or ', @alt_modules );
        }
        else {
            eval "require $module";
            push @failed_modules, $module if ( $@ );
        }
    }
    return @failed_modules;
}


# Check to ensure that all files in the MANIFEST exist and that there
# aren't any extra files in the directory -- this is just feedback
# from the EU::Manifest module, but don't let it print out results of
# its findings (Quiet)

sub _check_manifest {
    my ( $self ) = @_;
    local $ExtUtils::Manifest::Quiet = 1;
    my @missing = ExtUtils::Manifest::manicheck();
    my %missing_s = ( action => 'Files missing from MANIFEST' );
    if ( scalar @missing ) {
        $missing_s{is_ok}   = 'no';
        $missing_s{message} = 'Files not found from MANIFEST: ' .
                              join( ", ", @missing );
    }
    else {
        $missing_s{is_ok}   = 'yes';
        $missing_s{message} = 'All files in MANIFEST exist in package';
    }

    my @extra = ExtUtils::Manifest::filecheck();
    my %extra_s = ( action => 'Extra files not in MANIFEST' );
    if ( scalar @extra ) {
        $extra_s{is_ok}   = 'no';
        $extra_s{message} = 'Files not in MAIFEST found: ' .
                            join( ', ', @extra );
    }
    else {
        $extra_s{is_ok}   = 'yes';
        $extra_s{message} = 'No files not in MANIFEST found in package';
    }
    return ( \%missing_s, \%extra_s );
}


# If we were given a file at the beginning and extracted the contents,
# clean it up when this object goes away. (See _read_info_from_file())

sub DESTROY {
    my ( $self ) = @_;
    if ( $self->{_tmp_package_extract_dir} and
             -d $self->{_tmp_package_extract_dir} ) {
        $self->_remove_directory_tree( $self->{_tmp_package_extract_dir} );
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Package - Perform actions on individual packages

=head1 SYNOPSIS

 # Programmatically install a package you've downloaded (for the real
 # world, see C<oi2_manage> and/or
 # L<OpenInteract2::Manage::Website::InstallPackage|OpenInteract2::Manage::Website::InstallPackage).
 # You get back a reference to the installed package.
  
 my $package = OpenInteract2::Package->install(
                         { package_file => '/home/perlguy/trivia-game-1.07.zip',
                           website_dir  => '/home/httpd/mysite' });
  
 # Create a new skeleton package for development (for the real world,
 # see C<oi2_manage>). You get back a reference to the newly created
 # package.
 
 my $package = OpenInteract2::Package->create_skeleton(
                         { name       => 'mynewpackage',
                           sample_dir => '/usr/local/src/OpenInteract-2.00/sample/package' });
 
 # Export package in the given directory for distribution
 
 my $package = OpenInteract2::Package->new({
                    directory => '/home/cwinters/pkg/mynewpackage' });
 my $export_filename = eval { $package->export };
 if ( $@ ) {
     print "Export failed: $@";
 }
 else {
     print "Exported successfully to file [$export_filename]";
 }
 
 # Read information about a package distribution
 
 my $package = OpenInteract2::Package->new({
                    package_file => '/home/cwinters/pkg/mynewpackage-1.02.zip' });
 my $config = $package->config;
 print "Package ", $package->name, " ", $package->version, "\n",
       "Author ", join( ", ", @{ $config->author } ), "\n";
 my $files = $package->get_files;
 foreach my $filename ( @{ $files } ) {
     print "   File - $filename\n";
 }
 
 # Check validity of a package
 
 my $package = OpenInteract2::Package->new({
                    directory => '/home/cwinters/pkg/mynewpackage' });
 my @status = $package->check;
 foreach my $status ( @status ) {
    print "Action: $status->{action}   OK? $status->{is_ok}\n";
 }
 
 # Remove package
 
 my $package = OpenInteract2::Package->new({
                    directory => '/home/cwinters/pkg/mynewpackage' });
 $package->remove;
 
 # Get an object representing the changelog of a package and print out
 # the last version, date and message
 
 my $changes = $package->get_changes;
 my ( $latest_change ) = $changes->latest(1);
 print "$latest_change->{version}  on  $latest_change->{date}\n",
       "$latest_change->{message}\n";

=head1 DESCRIPTION

This module defines actions to be performed on individual
packages. The first argument for many of the methods that

=head1 METHODS

=head2 Class Methods

B<new( \%params )>

Create a new package object. You can specify an archived package
(using C<package_file>) and be able to find out information about the
package, or you can specify a directory (using C<directory>) of an
opened package.

If C<package_file>, C<directory> or a valid C<package_config> are
passed in we read the package information immediately.

Parameters:

=over 4

=item *

B<package_file>: Specify the package file to explore. An example is
C<news-2.11.zip>, although it's smart to specify the full path with
the file.

If the specified file does not exist we throw an exception.

=item *

B<directory>: A package directory to explore. It's smart to specify
the full path with the directory.

If the specified directory does not exist we throw an exception.

=item *

B<package_config>: A
L<OpenInteract2::Config::Package|OpenInteract2::Config::Package>
object. We pull the package directory (C<package_dir> property) from
it.

=item *

B<repository>: The
L<OpenInteract2::Repository|OpenInteract2::Repository> that this
package belongs to.

=back

B<install( \%params )>

Installs the file specified in the parameter C<filename> to the
website specified in the parameter C<website_dir> or retrieved from
the L<OpenInteract2::Repository|OpenInteract2::Repository> object
specified in C<repository>.

If the package already exists in the website repository we first
remove its entry (leaving the old directory). We then unpack the given
package file into the website, copy over any global files (those in
C<html/> and C<widget/>), and then create an entry in the website
repository for the new package.

Paramters:

=over 4

=item *

B<filename>: A valid package file.

=item *

B<website_dir>: Full path to a website we will install the package to.

=item *

B<repository>: A
L<OpenInteract2::Repository|OpenInteract2::Repository> from which we
can take the website directory.

=back

Returns: package created from the new directory. Any failures throw an
exception.

B<create_skeleton( \%params )>

Creates a new package skeleton in the current directory. This is the
recommended way to start developing a new OI2 package, similar to
creating a new perl module using C<h2xs>.

Parameters:

=over 4

=item *

B<name>: Name of your package. It should be all alphanumberic
lower-case with no spaces. If not an exception is thrown.

=item *

B<sample_dir>: The directory from where we pull our skeleton files
from. This is normally in the OpenInteract source distribution
directory, although you may elect to copy these files elsewhere so
developers can have access.

=item *

B<source_dir>: You can use this instead of C<sample_dir> as long as
the directory 'sample/package' exists underneath. (It should unless
you have mucked with the source distribution.)

=back

Returns: package created from the new directory. Any failures throw an
exception.

B<generate_distribution_digest( $package_file )>

Creates an MD5 digest of the contents in C<$package_file>. (See
L<Digest::MD5|Digest::MD5> for what this means.)

B<parse_full_name( $full_name )>

Returns a two-item list of the package name and version found in
C<$full_name>.

=head2 Object Methods

B<full_name()>

Returns a string with the package name and version:

 $package->name( 'foo' );
 $package->version( '1.52' );
 print "Name: ", $package->full_name;
 # Name: foo-1.52

B<get_files( [ $force_read ] )>

Reads list of files from package C<MANIFEST> file. These results are
cached in the object -- if you want to force a read pass a true value
for C<$force_read>.

Returns: arrayref of files in MANIFEST.

B<export( \%params )>

Exports a package to a package distribution file. The name of the file is always:

 {package}-{version}.zip

If a file already exists with that name in the current directory, the
process will throw an exception. Similarly, if a directory of the name:

 {package}-{version}/

already exists in the current directory an exception will be thrown.

Returns: the full path to the distribution file created.

B<check( \%params )>

Checks the validity of a package. We perform the following checks:

=over 4

=item *

Does the changelog exist? (This is not a fatal error, but you will get
a virtual raspberry if you do not have one.)

=item *

Are all the files in MANIFEST in the package directory?

=item *

Are there any extra files in the package directory that are not in
MANIFEST?

=item *

Are all the configuration INI files (C<action.ini>, C<spops.ini>)
parseable?

=item *

Are all the perl modules includable? (A "perl module" includes any
file ending in C<.pm>.)

=item *

Are all the data files valid Perl data structures? (This includes all
files in C<data/> ending in C<.dat>.)

=item *

Are the Template Toolkit templates parseable? (This includes all files
ending in C<.tmpl> in C<template/> and all files in C<widget/>.) The
implementation of parseability can probably be improved, since we have
to ignore certain errors caused by commonly available templates not
being available since the template is not deployed in the full OI2
environment.

=back

Returns a list of hashrefs indicating the status of the various
package elements. Each hashref includes (at a minimum): 'is_ok',
'message' and 'action'. Some also include 'filename' where
appropriate.

B<remove( [ $repository ] )>

Removes a package from its repository. This may fail if you do not
have a repository set in the package object or if you do not pass
C<$repository> into the method. It may also fail for reasons given in
L<OpenInteract2::Repository|OpenInteract2::Repository>.

Returns: array of status hashrefs, with a single member.

B<get_spops_files()>

Retrieves SPOPS configuration files from the package. You can either
specify the files yourself in the package configuration (see
L<OpenInteract2::Config::Package|OpenInteract2::Config::Package>), or
this routine will pick up all files that match C<^conf/spops.*\.ini$>.

Returns: arrayref of relative SPOPS configuration files.

B<get_action_files()>

Retrieves action configuration files from the package. You can either
specify the files yourself in the package configuration (see
L<OpenInteract2::Config::Package|OpenInteract2::Config::Package>), or
this routine will pick up all files that match C<^conf/action.*\.ini$>.

Returns: arrayref of relative action configuration files.

B<get_doc_files()>

Retrieves all documentation from the package. This includes all files
in C<doc/>.

Returns: arrayref of relative documentation files.

B<get_message_files()>

Retrieves message files from the package -- each one specifies i18n
keys and values for use in templates and elsewhere. You can either
specify the files yourself in the package configuration (see
L<OpenInteract2::Config::Package|OpenInteract2::Config::Package>), or
this routine will pick up all files that match
C<^msg/*\.msg$>.

Returns: arrayref of relative message files.

B<get_changes()>

Returns the
L<OpenInteract2::Config::PackageChanges|OpenInteract2::Config::PackageChanges>
object associated with this package.

B<find_file( @relative_files )>

Finds the a file from the list C<@relative_files>.

Returns: the full path to the first existing filename; if no file is
found, C<undef>.

B<read_file( $relative_file )>

Slurps the contents of C<$relative_file> into a variable and returns
it. Finds full path to C<$relative_file> using C<find_file()>.

Returns: contents of C<$relative_file>; if C<$relative_file> does not
exist, returns undef. If there is an error reading C<$relative_file>,
throws exception.

=head1 PROPERTIES

B<name>: Name of this package.

B<version>: Version of this package.

B<package_file>: The distribution (zip) file this package was read
from.

B<directory>: The directory this package was read from. Hopefully
fully-qualified... (TODO: shouldn't it always be?)

B<repository>: The
L<OpenInteract2::Repository|OpenInteract2::Repository> associated with
this package.

B<installed_date>: Date the package was installed. This is typically
stored in the C<repository> associated with the package.

B<config>: The
L<OpenInteract2::Config::Package|OpenInteract2::Config::Package>
object associated with this package.

=head1 TO DO

B<Automatically create objects for HTML pages>

NEW WAY:

In the relevant OI2::Manage class, just run the page scanner after a
package has been installed.

OLD WAY:

For each file copied over to the /html directory, create a 'page'
object in the system for it. Note that we might have to hook this up
with the system that ensures we do not overwrite certain files. So we
might need to either remove it from the _copy_package_files() routine,
or add an argument to that routine that lets us pass in a coderef to
execute with every item copied over.

ACK -- here is the problem. We do not know if we can even create an $R
yet, because (1) the base_page package might not have even been
installed yet (when creating a website) and (2) the user has not yet
configured the database (etc.)

We can get around this whenever we rewrite
Package/PackageRepository/oi_manage, but until then we will tell
people to include the relevant data inserts with packages that include
HTML documents.

Until then, here is what this might look like :-)

 # Now do the HTML files, but also create records for each of the HTML
 # files in the 'page' table

   my $copied = $class->_copy_package_files( "$info->{website_dir}/html",
                                             'html',
                                             $pkg_file_list );
   my @html_locations = map { s/^html//; $_ } @{ $copied };
   foreach my $location ( @html_locations ) {
       my $page = $R->page->fetch( $location, { skip_security => 1 } );
       next if ( $page );
       eval {
           $R->page->new({ location => $location,
                                      ... })
                   ->save({ skip_security => 1 });
       };
   }

=head1 SEE ALSO

L<OpenInteract2::Manual::Packages|OpenInteract2::Manual::Packages>

L<OpenInteract2::Repository|OpenInteract2::Repository>

L<OpenInteract2::Config::Package|OpenInteract2::Config::Package>

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
