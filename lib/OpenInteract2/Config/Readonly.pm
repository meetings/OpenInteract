package OpenInteract2::Config::Readonly;

# $Id: Readonly.pm,v 1.5 2003/06/24 03:35:38 lachoy Exp $

use strict;
use File::Basename           qw( basename );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Text::Wrap               qw( wrap );

$OpenInteract2::Config::Readonly::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

# Name of the file that specifies which files we shouldn't overwrite
# when copying

my $READONLY_FILE = '.no_overwrite';

sub is_writeable_file {
    my ( $class, $readonly, $filename ) = @_;
    my $writeable = $class->get_writeable_files( $readonly, [ $filename ] );
    return ( $filename eq $writeable->[0] );
}

sub get_writeable_files {
    my ( $class, $readonly, $to_check ) = @_;

    # If $readonly is a scalar treat as a directory name
    unless ( ref $readonly ) {
        $readonly = $class->read_config( $readonly );
    }

    # If $to_check isn't valid then we're saying nothing is writeable
    unless ( ref $to_check eq 'ARRAY' and scalar @{ $to_check } ) {
        return [];
    }

    # Only return files not in the readonly hash
    my %ro = map { $_ => 1 } @{ $readonly };
    return [ grep { ! $ro{ basename( $_ ) } } @{ $to_check } ];
}

# Read in the file that tells us what files in $dir should not be
# overwritten

sub read_config {
    my ( $class, $dir ) = @_;
    my $log = get_logger( LOG_CONFIG );
    my $overwrite_check_file = $class->_create_readonly_file( $dir );
    return [] unless ( -f $overwrite_check_file );
    my ( @no_write );
    eval { open( NOWRITE, '<', $overwrite_check_file ) || die $! };
    if ( $@ ) {
        $log->error( "Cannot read readonly file [$overwrite_check_file]: $@" );
        return [];
    }
    while ( <NOWRITE> ) {
        chomp;
        next if ( /^\s*$/ );
        next if ( /^\s*\#/ );
        s/^\s+//;
        s/\s+$//;
        push @no_write, $_;
    }
    close( NOWRITE );
    return \@no_write;
}


sub write_config {
    my ( $class, $dir, $to_write ) = @_;
    my ( $comment, $files );
    if ( ref $to_write eq 'HASH' ) {
        $comment = $to_write->{comment};
        $files   = $to_write->{file};
    }
    elsif ( ref $to_write eq 'ARRAY' ) {
        $comment = undef;
        $files   = $to_write;
    }
    unless ( ref $files eq 'ARRAY' and scalar @{ $files } ) {
        return undef;
    }
    my $overwrite_check_file = $class->_create_readonly_file( $dir );
    eval { open( NOWRITE, '>', $overwrite_check_file ) || die $! };
    if ( $@ ) {
        oi_error "Failed to create file [$overwrite_check_file]: $@";
    }
    if ( $comment ) {
        local $Text::Wrap::columns = 60;
        print NOWRITE wrap( '# ', '# ', $comment );
        print NOWRITE "\n\n";
    }
    print NOWRITE join( "\n", map { basename( $_ ) } @{ $files } );
    close( NOWRITE );
    return $overwrite_check_file;
}


sub _create_readonly_file {
    my ( $class, $dir ) = @_;
    return File::Spec->catfile( File::Spec->rel2abs( $dir ),
                                $READONLY_FILE );
}

1;

__END__

=head1 NAME

OpenInteract2::Config::Readonly - Simple read/write for readonly files

=head1 SYNOPSIS

 use OpenInteract2::Config::Readonly;
 
 # See if some files are writeable in $dir
 
 my @files_to_write = ( 'blah.html', 'bleh.txt' );
 my $files_writeable = OpenInteract2::Config::Readonly
                         ->get_writeable_files( $dir, \@files_to_write );
 
 # Same thing, but read the nonwriteable files first
 
 my $readonly_files = OpenInteract2::Config::Readonly->read_config( $dir );
 my @files_to_write = ( 'blah.html', 'bleh.txt' );
 my $files_writeable = OpenInteract2::Config::Readonly
                         ->get_writeable_files( $readonly_files, \@files_to_write );
 
 # See if a single file is writeable
 
 my $original_path = '/path/to/distribution/foo.html';
 my $can_write = OpenInteract2::Config::Readonly
                         ->is_file_writeable( $dir, $original_path );
 if ( $can_write ) {
     cp( $original_path,
         File::Spec->catfile( $dir, basename( $original_path ) ) );
 }
 
 # Write a set of readonly files with a comment...
 
 OpenInteract2::Config::Readonly->write_config(
                         $dir,
                         { file    => [ 'file1', 'file2' ],
                           comment => 'OI will not overwrite these files' } );
 
 # ... or without
 OpenInteract2::Config::Readonly->write_config(
                         $dir,
                         [ 'file1', 'file2' ] );

=head1 DESCRIPTION

Simple module to read/write configuration that determines which files
in a directory OpenInteract2 should not overwrite.

=head1 METHODS

Note: We only read, store and check against bare filenames from the
readonly config -- that is, the result of a
L<File::Basename|File::Basename> C<basename> call.

B<is_writeable_file( \@readonly_filenames | $directory, $filename )>

Returns true if file C<$filename> is writeable in C<$directory> or if
it is not found among C<\@readonly_filenames>. We do a C<basename()>
against C<$filename> before doing the check.

Examples:

 # These all return true
 OpenInteract2::Config::Readonly->is_writeable_file(
                    [ 'index.html' ], 'foo.html' );
 OpenInteract2::Config::Readonly->is_writeable_file(
                    [ 'index.html' ], 'INDEX.HTML' );
 OpenInteract2::Config::Readonly->is_writeable_file(
                    [ 'index.html' ], '/path/to/index.htm' );

 # These all return false
 OpenInteract2::Config::Readonly->is_writeable_file(
                    [ 'index.html' ], 'index.html' );
 OpenInteract2::Config::Readonly->is_writeable_file(
                    [ 'index.html' ], '/path/to/my/index.html' );


B<get_writeable_files( \@readonly_filenames | $directory, \@filenames )>

Returns an arrayref of all writeable files from C<\@filenames> as
compared against the config in C<$directory> or the readonly filenames
in C<\@readonly_filenames>. The filenames returned are whatever was
stored in C<\@filenames> rather than the basename.

Examples:

 my $files = OpenInteract2::Config::Readonly->get_writeable_files(
                    [ 'index.html' ], [ '/path/to/foo.html' ] );
 # $files = [ '/path/to/foo.html' ]
 
 my $files = OpenInteract2::Config::Readonly->get_writeable_files(
                    [ 'index.html' ], [ 'INDEX.HTML', '/path/to/README.txt' ] );
 # $files = [ 'INDEX.HTML', '/path/to/README.txt' ]
 
 my $files = OpenInteract2::Config::Readonly->get_writeable_files(
                    [ 'index.html' ], [ '/path/to/index.htm', '/path/to/index.html' ] );
 # $files = [ '/path/to/index.htm' ]

B<read_config( $dir )>

Reads the file in C<$dir> for files not to overwrite. This method
should never C<die> or throw an exception -- if there is an error
reading the file or if the file does not exist, it simply returns an
empty arrayref.

Returns: arrayref of filenames relative to C<$dir>.

B<write_config( $dir, \@files_to_write | \%write_info )>

Writes filenames to a file in C<$dir>. The C<\%write_info> parameters
can be either an arrayref of filenames to write or a hashref with the
following keys:

=over 4

=item *

B<file>: Arrayref of filenames to write

=item *

B<comment>: Message to write as a comment.

=back

No path information is written to the file, only the base filename.

Returns: full path to file written. If the file cannot be written, it
will throw an exception. If there are no files passed in to write, it
returns nothing.

=head1 BUGS

None known.

=head1 SEE ALSO

L<File::Basename|File::Basename>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
