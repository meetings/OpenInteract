package OpenInteract2::Manage::CreateSourceDirectory;

# $Id: CreateSourceDirectory.pm,v 1.4 2004/02/17 04:30:20 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage );
use File::DirSync;
use File::Path  qw( mkpath );
use File::Spec;

$OpenInteract2::Manage::CreateSourceDirectory::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'create_source_dir';
}

sub get_brief_description {
    return "Create/update a directory separate from the OpenInteract source " .
           "distribution that contains the packages and sample files " .
           "necessary to create new websites and packages.";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        distribution_dir => {
               description =>
                       'Root directory of the OpenInteract2 source distribution',
               is_required => 'yes',
        },
        source_dir => {
               description =>
                       "Directory you want to create with the packages and " .
                       "sample files from the distribution. This directory " .
                       "may only exist if you're doing an update.",
               is_required => 'yes',
        },
    };
}

# VALIDATE

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'distribution_dir' ) {
        return $self->_validate_dist( $value );
    }
    if ( $name eq 'source_dir' ) {
        return $self->_validate_src( $value );
    }
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

# TASK

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
    $self->_add_status( $self->_create_sync_status( $dirsync, 'pkg/' ) );

    # Then the sample dir

    my $dist_sample_dir = File::Spec->catdir( $dist_dir, 'sample' );
    my $src_sample_dir  = File::Spec->catdir( $src_dir, 'sample' );
    $dirsync->src( $dist_sample_dir );
    $dirsync->dst( $src_sample_dir );
    $dirsync->dirsync();
    $self->_add_status( $self->_create_sync_status( $dirsync, 'sample/' ) );
}

sub _create_sync_status {
    my ( $self, $dirsync, $dir ) = @_;
    my %status = ();
    my @failed = $dirsync->entries_failed;
    if ( scalar @failed ) {
        %status = ( is_ok   => 'no',
                    message => "Following files from $dir had failures: " .
                               join( ', ', @failed ) );
    }
    else {
        %status = ( is_ok   => 'yes',
                    message => "Mirrored $dir directory ok" );
    }
    my @updated = $dirsync->entries_updated;
    if ( scalar @updated ) {
        $status{updated} = "Updated items: " . join( ', ', @updated );
    }
    else {
        $status{updated} = 'No items updated';
    }

    my @removed = $dirsync->entries_removed;
    if ( scalar @removed ) {
        $status{removed} = "Removed items: " . join( ', ', @removed );
    }
    else {
        $status{removed} = 'No items removed';
    }

    my @skipped = $dirsync->entries_skipped;
    if ( scalar @skipped ) {
        $status{skipped} = "Skipped items: " . join( ', ', @skipped );
    }
    else {
        $status{skipped} = 'No items skipped';
    }
    return \%status;
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::CreateSourceDirectory - Create a source directory from the OI2 distribution

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my %params = ( distribution_dir => '/path/to/OpenInteract-2.00',
                source_dir      => '/path/to/source-dir' );
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'create_source_dir', \%params );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n",
           "($s->{updated} updated) ($s->{removed} removed) ",
           "($s->{skipped} skipped)\n";
 }

=head1 REQUIRED OPTIONS

=over 4

=item B<distribution_dir>=/path/to/OpenInteract-2.00

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

=item B<updated>

Message with files updated

=item B<removed>

Message with files removed

=item B<skipped>

Message with files skipped

=back

=head1 SEE ALSO

L<File::DirSync|File::DirSync>

=head1 COPYRIGHT

Copyright (C) 2003-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

