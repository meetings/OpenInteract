package OpenInteract2::Manage::Package::CreatePackage;

# $Id: CreatePackage.pm,v 1.9 2003/06/11 02:43:29 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Package );

$OpenInteract2::Manage::Package::CreatePackage::VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'Create a new package, with most of the pieces filled in for you';
}

sub list_param_require  { return [ 'package', 'source_dir' ] }
sub list_param_optional { return [ 'package_dir' ] }
sub list_param_validate { return [ 'package', 'source_dir', 'package_dir' ] }

sub get_validate_sub {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'package_dir' ) {
        return \&_validate_package_dir;
    }
    return $self->SUPER::get_validate_sub( $param_name );
}

sub _validate_package_dir {
    my ( $self, $package_dir ) = @_;
    return () unless ( $package_dir );
    return () if ( -d $package_dir );
    return "If specified 'package_dir' must be a valid directory";
}

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'package' ) {
        return "Name of the package to create";
    }
    elsif ( $param_name eq 'package_dir' ) {
        return "Directory to create package in";
    }
    return $self->SUPER::get_param_description( $param_name );
}

sub setup_task {
    my ( $self ) = @_;
    my $sample_dir = File::Spec->catdir( $self->param( 'source_dir' ),
                                         'sample', 'package' );
    $self->param( sample_dir => $sample_dir );
}

sub run_task {
    my ( $self ) = @_;
    if ( $self->param( 'package_dir' ) ) {
        chdir( $self->param( 'package_dir' ) );
    }
    my $package_name = $self->param( 'package' )->[0];
    my $package = OpenInteract2::Package->create_skeleton(
                         { name       => $package_name,
                           sample_dir => $self->param( 'sample_dir' ) });
    my $msg = sprintf( 'Package %s created ok in %s', $package->name,
                                                      $package->directory );
    $self->_add_status( { is_ok   => 'yes',
                          action  => "Create package $package_name",
                          message => $msg } );
    return;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Package::CreatePackage - Create a sample package

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $package_dir  = '/home/me/work/pkg';
 my $package_name = 'dev_package';
 my $source_dir   = '/home/httpd/OpenInteract-2.0';
 my $task = OpenInteract2::Manage->new(
                      'create_package', { package_dir => $package_dir,
                                          source_dir  => $source_dir,
                                          package     => $package_name } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     print "Action:    $s->{action}\n",
           "Status OK? $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

Create a new package named C<package> in directory C<package_dir>. We
need C<source_dir> defined so we know from where to get the sample
package files.

=head1 STATUS MESSAGES

In addition to the default entries, each status message may include:

=over 4

=item B<filename>

File installed/modified (if applicable)

=back

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
