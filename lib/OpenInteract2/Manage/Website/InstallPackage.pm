package OpenInteract2::Manage::Website::InstallPackage;

# $Id: InstallPackage.pm,v 1.10 2003/08/30 15:36:01 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Repository;

$OpenInteract2::Manage::Website::Install::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'install_package';
}

sub get_brief_description {
    return 'Install a package distribution to a website';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir  => $self->_get_website_dir_param,
        package_file => {
            description =>
                'Package distribution filename to install to website',
            is_required => 'yes',
        },
    };
}

# RUN

sub run_task {
    my ( $self ) = @_;
    my $package_file = $self->param( 'package_file' );
    my %status = (
        action   => 'install package',
        filename => $package_file,
    );
    my $package = OpenInteract2::Package->new(
                      { package_file => $package_file });
    my $repository = CTX->repository;
    my $rep_package = $repository->fetch_package( $package->name );
    if ( $rep_package && $rep_package->version == $package->version ) {
            $status{is_ok} = 'yes';
            $status{package} = $package->name;
            $status{version} = $package->version;
            $status{message} =
                sprintf( 'Package %s-%s not upgraded, ' .
                         'this version already installed',
                         $package->name, $package->version );
    }
    else {
        my $installed_package = eval {
            OpenInteract2::Package->install({
                    package_file => $package_file,
                    repository   => CTX->repository })
        };
        if ( $@ ) {
            $status{is_ok}   = 'no';
            $status{message} = "Error: $@";
        }
        else {
            $status{is_ok}   = 'yes';
            $status{package} = $installed_package->name;
            $status{version} = $installed_package->version;
            $status{message} =
                sprintf( 'Installed package %s-%s to website %s',
                         $installed_package->name, $installed_package->version,
                         $self->param( 'website_dir' ) );
        }
        eval {
            $self->_create_temp_lib_refresh( $installed_package->name )
        };
        if ( $@ ) {
            $status{message} .= "\nNOTE: Could not create temp lib refresh " .
                                  "file, so you may need to delete it manually.";
        }
    }
    $self->notify_observers(
        progress => "Finished with installation of $package_file" );

    $self->_add_status( \%status );
    return;
}

# Let the site know that a new package has been installed by creating
# the 'refresh' file for the temporary library

sub _create_temp_lib_refresh {
    my ( $self, $package_name ) = @_;
    my $temp_lib_dir = CTX->lookup_temp_lib_directory;
    return unless ( -d $temp_lib_dir );      # nothing to refresh!
    my $refresh_file =
        File::Spec->catfile( $temp_lib_dir,
                             CTX->lookup_temp_lib_refresh_filename );
    return if ( -f $refresh_file );          # someone already refreshed!
    open( REFRESH, '>', $refresh_file )
                    || die "Cannot open refresh file: $!";
    print REFRESH "Forced refresh from package '$package_name' ",
                  "installed on ", scalar( localtime );
    close( REFRESH );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::InstallPackage - Install a package distribution to a website

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $package_file = '/home/me/mypkg-1.11.zip';
 my $website_dir  = '/home/httpd/testsite';
 my $task = OpenInteract2::Manage->new(
                      'install_package', { package_file => $package_file,
                                           website_dir => $website_dir } );
 my ( $status ) = $task->execute;
 print "Action:    $s->{action}\n",
       "Status OK? $s->{is_ok}\n",
       "Package:   $s->{package_name} $s->{package_version}\n",
       "$s->{message}\n";
 }

=head1 DESCRIPTION

Installs a package from a distribution to a website. It does B<not>
install data structures, data, security information, or anything
else. See the 'install_sql*' tasks for that.

=head1 STATUS MESSAGES

In addition to the default entries, each status message includes:

=over 4

=item B<filename>

Package file installed

=item B<package>

Name of package installed

=item B<version>

Version of package installed

=back

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
