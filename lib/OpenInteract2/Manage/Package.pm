package OpenInteract2::Manage::Package;

# $Id: Package.pm,v 1.10 2003/06/11 02:43:29 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Manage;

$OpenInteract2::Manage::Package::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

########################################
# INTERFACE

sub setup_task       {}
sub tear_down_task   {}


########################################
# PACKAGE PARAMETER CHECKS

sub get_validate_sub {
    my ( $self, $name ) = @_;
    return \&_check_package      if ( $name eq 'package' );
    return \&_check_package_dir  if ( $name eq 'package_dir' );
    return $self->SUPER::get_validate_sub( $name );
}


sub _check_package_dir {
    my ( $self, $package_dir ) = @_;
    unless ( -d $package_dir ) {
        return "Value 'package_dir' must be valid directory";
    }
    return $self->_package_in_dir( $package_dir );
}


sub _check_package {
    my ( $self, $package ) = @_;
    unless ( ref $package eq 'ARRAY' and scalar @{ $package } ) {
        return "Value 'package' must contain one or more values";
    }
    return;
}


# Test whether directory $package_dir is actually a package directory
# - returns message on error, nothing otherwise.

sub _package_in_dir {
    my ( $self, $package_dir ) = @_;
    eval { opendir( PKGDIR, $package_dir ) || die $! };
    if ( $@ ) {
        return "Cannot open directory [$package_dir]: $@";
    }
    my %pkg_files = map { $_ => 1 }
                    grep { -f File::Spec->catfile( $package_dir, $_ ) }
                    readdir( PKGDIR );
    unless ( $pkg_files{'package.conf'} ) {
        return "Directory [$package_dir] does not contain a package";
    }
    return;
}


########################################
# PACKAGE TASK REGISTRATION

# Register all of our known subclasses

my %CHILDREN = (
  check_package         => 'OpenInteract2::Manage::Package::Check',
  create_package        => 'OpenInteract2::Manage::Package::CreatePackage',
  export_package        => 'OpenInteract2::Manage::Package::Export',
);

sub register {
    while ( my ( $name, $class ) = each %CHILDREN ) {
        OpenInteract2::Manage->register_factory_type( $name, $class );
    }
}

OpenInteract2::Manage::Package->register();

1;

__END__

=head1 NAME

OpenInteract2::Manage::Package - Parent for all package management tasks

=head1 SYNOPSIS

 package My::Manage::Task;
 
 use strict;
 use base qw( OpenInteract2::Manage::Package );

=head1 DESCRIPTION

=head1 METHODS

B<read_package_file( $filename )>

Reads in package names from the file C<$filename>.

Returns: arrayref of package names.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
