package OpenInteract2::Manage::CreateSourceDirectory;

# $Id: CreateSourceDirectory.pm,v 1.1 2003/07/03 03:38:27 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage );
use File::DirSync;
use File::Path  qw( mkpath );
use File::Spec;

$OpenInteract2::Manage::CreateSourceDirectory::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return "Create/update a directory separate from the OpenInteract source " .
           "distribution that contains the packages and sample files " .
           "necessary to create new websites and packages.";
}

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'distribution_dir' ) {
        return "Root directory of the OpenInteract2 source distribution";
    }
    elsif ( $param_name eq 'source_dir' ) {
        return "Directory you want to create with the packages and " .
               "sample files from the distribution. This directory " .
               "may only exist if you're doing an update.";
    }
    return $self->SUPER::get_param_description( $param_name );
}

sub list_param_require {
    return [ 'distribution_dir', 'source_dir' ];
}

sub list_param_validate {
    return [ 'distribution_dir', 'source_dir' ];
}

sub get_validate_sub {
    my ( $self, $param_name ) = @_;
    return \&_validate_dist if ( $param_name eq 'distribution_dir' );
    return \&_validate_src  if ( $param_name eq 'source_dir' );
}

sub _validate_dist {
    my ( $self, $dist_dir ) = @_;
    unless ( -d $dist_dir ) {
        return 'Directory must exist';
    }
    my $pkg_dir = File::Spec->catdir( $dist_dir, 'pkg' );
    my $sample_dir = File::Spec->catdir( $dist_dir, 'sample' );
    unless ( -d $pkg_dir and -d $sample_dir ) {
        return 'Not an OpenInteract distribution directory, must ' .
               'contain pkg/ and sample/';
    }
    return undef;
}

sub _validate_src {
    my ( $self, $src_dir ) = @_;
    my $pkg_dir = File::Spec->catdir( $src_dir, 'pkg' );
    my $sample_dir = File::Spec->catdir( $src_dir, 'sample' );
    if ( -d $src_dir and ( ! -d $pkg_dir || ! -d $sample_dir ) ) {
        return 'Directory must not exist unless you are doing an update';
    }
    return undef;
}

sub run_task {
    my ( $self ) = @_;
    my $dist_dir = $self->param( 'distribution_dir' );
    my $src_dir  = $self->param( 'source_dir' );

    mkpath( $src_dir ) unless ( -d $src_dir );

    # First do the package dir...

    my $dist_pkg_dir = File::Spec->catdir( $dist_dir, 'pkg' );
    my $src_pkg_dir  = File::Spec->catdir( $src_dir, 'pkg' );

    # No indication of error codes (etc.) from docs...

    my $dirsync = File::DirSync->new({ src       => $dist_pkg_dir,
                                       dst       => $src_pkg_dir,
                                       verbose   => 0,
                                       nocache   => 0,
                                       localmode => 0 });
    $dirsync->ignore( 'CVS' );
    $dirsync->dirsync();

    # Then the sample dir

    my $dist_sample_dir = File::Spec->catdir( $dist_dir, 'sample' );
    my $src_sample_dir  = File::Spec->catdir( $src_dir, 'sample' );
    $dirsync->src( $dist_sample_dir );
    $dirsync->dst( $src_sample_dir );
    $dirsync->dirsync();

    $self->_add_status( { is_ok   => 'yes',
                          message => 'Mirrored pkg/ and sample/ directories ok' } );
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::CreateSourceDirectory - Create a source directory from the OI2 distribution

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my %params = ( destination_dir => '/path/to/OpenInteract-2.00',
                source_dir      => '/path/to/source-dir' );
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'create_source_dir', \%params );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 REQUIRED OPTIONS

=over 4

=item B<destination_dir>=/path/to/OpenInteract-2.00

Full path to the OpenInteract 2 source distribution. Must include the
'pkg/' and 'sample/' directories.

=item B<source_dir>=/path/to/source-dir

Full path to the directory that anyone can access to create a new
website or develop a new package. If the directory exists we assume
you're doing an update and check to see that the 'pkg/' and 'sample/'
directories are already there -- if they're not the parameter is
invalid.

=back

=head1 STATUS INFORMATION

Each status hashref includes:

=over 4

=item B<is_ok>

Set to 'yes' if the task succeeded, 'no' if not.

=item B<message>

Success/failure message.

=back

=head1 SEE ALSO

L<File::DirSync|File::DirSync>

=head1 COPYRIGHT

Copyright (C) 2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

