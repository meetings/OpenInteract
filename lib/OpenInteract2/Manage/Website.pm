package OpenInteract2::Manage::Website;

# $Id: Website.pm,v 1.11 2003/06/11 02:43:29 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage );
use File::Spec;
use OpenInteract2::Config::Readonly;
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Package   qw( DISTRIBUTION_EXTENSION );

$OpenInteract2::Manage::Website::VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

sub list_param_require  { return [ 'website_dir' ] }
sub list_param_validate { return [ 'website_dir' ] }

sub setup_task {
    my ( $self ) = @_;
    $self->setup_context;
}


########################################
# COMMON METHODS

# Install all packages from a particular directory

sub _install_packages {
    my ( $self, $dir, $package_names ) = @_;
    my $package_dist = $self->_match_system_packages( $dir );
    my $website_dir = $self->param( 'website_dir' );

    my @files = ();
PACKAGE:
    foreach my $package_name ( @{ $package_names } ) {
        my $package_file = $package_dist->{ $package_name };
        return unless ( $package_file );
        my $install_task = OpenInteract2::Manage->new(
                                        'install_package',
                                        { package_file => $package_file,
                                          website_dir  => $website_dir } );

        # The package install fires a 'progress' observation that it's done
        # installing the package, which is useful for *our* observers
        # to know

        $self->copy_observers( $install_task );

        eval { $install_task->execute };
        if ( $@ ) {
            $self->_add_status(
                    { is_ok   => 'no',
                      action  => 'install package',
                      message => "Failed to install $package_name: $@" } );
        }
        else {
            $self->_add_status( $install_task->get_status );
            push @files, $package_file;
        }
    }
    return @files;
}


# Find all distribution packages in $source_dir/pkg

sub _match_system_packages {
    my ( $self, $dir ) = @_;
    unless ( -d $dir ) {
        oi_error "No valid dir [$dir] to find base packages";
    }

    # Match up the package names in our initial and extra list with
    # the filename of the package distributed

    my $ext = DISTRIBUTION_EXTENSION;
    my $package_dir = File::Spec->catdir( $dir, 'pkg' );
    eval { opendir( PKG, $package_dir ) || die $! };
    if ( $@ ) {
        oi_error "Cannot open package dir [$dir/pkg/] for reading: $@";
    }
    my @package_files = grep /\.$ext$/, readdir( PKG );
    closedir( PKG );
    my %package_match = ();
    foreach my $package_file ( @package_files ) {
        my ( $package_name ) = $package_file =~ /^(.*)\-\d+\.\d+\.$ext$/;
        $package_match{ $package_name } =
            File::Spec->catfile( $package_dir, $package_file );
    }
    return \%package_match;
}


########################################
# WEBSITE TASK REGISTRATION

# Register all of our known subclasses - we do this here rather than
# in the classes themselves to prevent a bootstrapping problem

my %CHILDREN = (
  create_password       => 'OpenInteract2::Manage::Website::CreateSuperuserPassword',
  create_website        => 'OpenInteract2::Manage::Website::Create',
  upgrade_website       => 'OpenInteract2::Manage::Website::Upgrade',
  list_actions          => 'OpenInteract2::Manage::Website::ListActions',
  list_objects          => 'OpenInteract2::Manage::Website::ListObjects',
  list_packages         => 'OpenInteract2::Manage::Website::ListPackages',
  test_db               => 'OpenInteract2::Manage::Website::TestDB',
  test_ldap             => 'OpenInteract2::Manage::Website::TestLDAP',
  dump_theme            => 'OpenInteract2::Manage::Website::ThemeDump',
  install_theme         => 'OpenInteract2::Manage::Website::ThemeInstall',
  install_package       => 'OpenInteract2::Manage::Website::InstallPackage',
  install_sql           => 'OpenInteract2::Manage::Website::InstallPackageSql',
  install_sql_structure => 'OpenInteract2::Manage::Website::InstallPackageStructure',
  install_sql_data      => 'OpenInteract2::Manage::Website::InstallPackageData',
  install_sql_security  => 'OpenInteract2::Manage::Website::InstallPackageSecurity',
  remove_package        => 'OpenInteract2::Manage::Website::RemovePackage',
);

sub register {
    while ( my ( $name, $class ) = each %CHILDREN ) {
        OpenInteract2::Manage->register_factory_type( $name, $class );
    }
}

OpenInteract2::Manage::Website->register();

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website - Parent for website management tasks

=head1 SYNOPSIS

 package My::Manage::Task;

 use strict;
 use base qw( OpenInteract2::Manage::Website );
 use OpenInteract2::Context qw( CTX );

 sub run_task {
     my ( $self ) = @_;
     my $server_config = CTX->server_config;
     ... # CTX is setup automatically in setup_task()
 }

=head1 DESCRIPTION

Provides common initialization and other tasks for managment tasks
operating on a website.

=head1 METHODS

=head2 Task Execution Methods

B<list_param_require()>

Returns C<[ 'website_dir' ]> as a required parameter. If your subclass
has additional parameters required, you should override the method and
either include 'website_dir' as one of the entries or call C<SUPER>
and capture the return.

B<list_param_require()>

Returns C<[ 'website_dir' ]> as a parameter that must be validated,
using the built-in validation from
L<OpenInteract2::Manage|OpenInteract2::Manage>. If your subclass has
additional parameters to be validated, you should override the method
and either include 'website_dir' as one of the entries or call
C<SUPER> and capture the return. You should also implement the method
C<get_validate_sub()> as discussed in
L<OpenInteract2::Manage|OpenInteract2::Manage>.

B<setup_task()>

Call C<setup_context()> from
L<OpenInteract2::Manage|OpenInteract2::Manage> which sets up a
L<OpenInteract2::Context|OpenInteract2::Context> object you can examine
the website.

If your task does not need this, override C<setup_task()> with an
empty method.

=head2 Common Functionality

B<_install_packages( $dir, \@package_names )>

B<_match_system_packages( $dir )>

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::Manage|OpenInteract2::Manage>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
