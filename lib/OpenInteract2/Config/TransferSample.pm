package OpenInteract2::Config::TransferSample;

use strict;
use base qw( Class::Accessor::Fast );
use File::Basename           qw( basename dirname );
use File::Copy               qw( cp );
use File::Spec::Functions    qw( catfile rel2abs );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Config::Readonly;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Template;

$OpenInteract2::Config::TransferSample::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( source_dir file_spec files_copied files_skipped files_same );
__PACKAGE__->mk_accessors( @FIELDS );

my ( $log );

sub new {
    my ( $class, $source_dir ) = @_;
    $log ||= get_logger( LOG_CONFIG );
    my $self = bless( {
        files_copied  => [],
        files_skipped => [],
        files_same    => [],
    }, $class );
    $source_dir = rel2abs( $source_dir );
    unless ( -d $source_dir ) {
        oi_error "Source directory '$source_dir' is invalid";
    }
    $self->source_dir( $source_dir );
    $self->{_template} = Template->new( ABSOLUTE => 1 );
    $log->is_info &&
        $log->info( "Created new transfer object given source '$source_dir'" );
    return $self;
}

sub run {
    my ( $self, $dest_dir, $template_vars ) = @_;
    $log->is_info && $log->info( "Running transfer from '$dest_dir'..." );
    $self->read_file_spec( $template_vars );
    return $self->transfer( $dest_dir, $template_vars );
}

sub read_file_spec {
    my ( $self, $template_vars ) = @_;
    my $copy_list_file = catfile( $self->source_dir, 'FILES' );
    unless ( -f $copy_list_file ) {
        oi_error "File from which I read the file specifiecations ",
                 "'$copy_list_file' does not exist";
    }

    $template_vars ||= {};
    my ( $content );
    $self->{_template}->process( $copy_list_file, $template_vars, \$content )
        || oi_error "Cannot process template with files to ",
                    "copy '$copy_list_file': ", $self->{_template}->error;
    my @lines = split /\r?\n/, $content;
    my @files = ();
    foreach my $file_spec ( @lines ) {
        next if ( $file_spec =~ /^\s*#/ );  # skip comments
        next if ( $file_spec =~ /^\s*$/ );  # ...and blank lines
        $file_spec =~ s/^\s+//;
        $file_spec =~ s/\s+$//;
        my ( $source, $dest ) = split /\s*\-\->\s*/, $file_spec, 2;
        my @source_file = split /\s+/, $source;
        my @dest_file   = split /\s+/, $dest;
        push @files, [ \@source_file, \@dest_file ];
    }
    return $self->file_spec( \@files );
}

sub transfer {
    my ( $self, $dest_dir, $template_vars ) = @_;
    unless ( ref( $self->file_spec ) eq 'ARRAY' ) {
        oi_error "You must run 'read_file_spec()' before running 'transfer()' (you ",
                 "might try calling 'run()' instead of 'transfer()')";
    }
    $log->is_info &&
        $log->info( "Transferring files from '$dest_dir'..." );

    $template_vars ||= {};

FILESPEC:
    foreach my $info ( @{ $self->file_spec } ) {
        my $source_spec = $info->[0];
        my $dest_spec   = $info->[1];

        my ( $copy_only );
        if ( $source_spec->[-1] =~ /^\*/ ) {
            $copy_only++;
            $source_spec->[-1] =~ s/^\*//;
        }

        my $relative_dest    = join( '/', @{ $dest_spec } );
        my $full_source_file = catfile( $self->source_dir, @{ $source_spec } );
        my $full_dest_file   = catfile( $dest_dir, @{ $dest_spec } );
        $log->is_info &&
            $log->info( "Copying from '$full_source_file' to '$full_dest_file'" );

        # determine if we should overwrite

        if ( -f $full_dest_file ) {

            my $base_dest_file   = basename( $full_dest_file );
            my $full_dest_dir    = dirname( $full_dest_file );

            my $ro_check = OpenInteract2::Config::Readonly->new( $full_dest_dir );
            $log->is_debug &&
                $log->debug( "Files I shouldn't copy: ",
                             join( ', ', @{ $ro_check->get_readonly_files } ) );
            unless ( $ro_check->is_writeable( $base_dest_file ) ) {
                $log->is_info &&
                    $log->info( "Skipping '$base_dest_file', it's marked as ",
                                "readonly in the destination directory" );
                $self->add_skipped( $relative_dest );
                next FILESPEC;
            }

            # first check the filesize before the relatively expensive digest

            my $source_file_size = (stat $full_source_file)[7];
            my $dest_file_size   = (stat $full_dest_file)[7];
            if ( $source_file_size == $dest_file_size ) {
                my $source_digest =
                    OpenInteract2::Util->digest_file( $full_source_file );
                my $dest_digest   =
                    OpenInteract2::Util->digest_file( $full_source_file );
                if ( $source_digest eq $dest_digest ) {
                    $log->is_info &&
                        $log->info( "Digests for files are the same, not copying" );
                    $self->add_same( $relative_dest );
                    next FILESPEC;
                }
            }

        }

        # NOTE: You shouldn't assume because ( ! keys %{ $template_vars } )
        # that you should use copy only -- there might be other templating
        # directives in the file to copy...

        if ( $copy_only ) {
            cp( $full_source_file, $full_dest_file )
                || oi_error "Cannot copy '$full_source_file' -> ",
                            "'$full_dest_file': $!";
            $log->is_info &&
                $log->info( "Copied w/o processing '$full_source_file' ",
                            "-> '$full_dest_file'" );
        }

        else {
            $self->{_template}->process( $full_source_file, $template_vars, $full_dest_file )
                || oi_error "Cannot copy and token-replace file ",
                            "'$full_source_file' -> '$full_dest_file': ",
                            $self->{_template}->error;
            $log->is_info &&
                $log->info( "Copied with processing '$full_source_file' ",
                            "-> '$full_dest_file'" );
        }
        $self->add_copied( $relative_dest );
    }
    return wantarray
           ? ( $self->files_copied, $self->files_skipped, $self->files_same )
           : $self->files_copied;
}

sub add_copied {
    my ( $self, @files ) = @_;
    push @{ $self->{files_copied} }, @files;
}

sub add_skipped {
    my ( $self, @files ) = @_;
    push @{ $self->{files_skipped} }, @files;
}

sub add_same {
    my ( $self, @files ) = @_;
    push @{ $self->{files_same} }, @files;
}



1;

__END__

=head1 NAME

OpenInteract2::Config::TransferSample - On website install or package creation, transfer and modify sample files

=head1 SYNOPSIS

 use OpenInteract2::Config::TransferSample;
 ...
 # $source_dir has a 'FILES' document along with the files to copy
 # (they may be in subdirs of $source_dir also)
 
 my $transfer = OpenInteract2::Config::TransferSample->new( $source_dir );
 
 # Read in the 'FILES' document, replacing all instances of
 $ [% sample %] with 'YourSite' and parsing the file source
 # and destination into arrayrefs.
 
 my %filename_vars = ( sample => 'YourSite' );
 $transfer->read_file_spec( \%filename_vars );
 
 # Copy all files in 'FILES' (as translated by read_file_spec()) from
 # a relative directory in C<$source_dir> to a relative directory
 # C<$dest_dir>, replacing instances of [% sample %] and [% config %]
 # as specified in C<%content_vars>.
 
 my %content_vars => ( sample => 'YourSite',
                       config => 'YourSiteConfig' );
 my $copies = $transfer->transfer( \%content_files, $dest_dir );
 print "The following files were copied:\n  ",
       join( "\n  ", @{ $copies } ), "\n";
 
 # If our filename and content vars don't overlap we can take the
 # shortcut:
 
 my $copies = OpenInteract2::Config::TransferSample
                         ->new( $source_dir )
                         ->run( $dest_dir, \%template_vars );
 
 # We can also get the files we did not copy
 
 my ( $copies, $skips ) = OpenInteract2::Config::TransferSample
                                ->new( $source_dir )
                                ->run( $dest_dir, \%template_vars );

=head1 DESCRIPTION

This class simplifies copying around files when we're creating a new
package or website. As a result the non-OI2 developer will probably
never use it, or even know it exists.

For the rest of you, this class:

=over 4

=item *

Reads in a listing of files (always called 'FILES') to copy. This
listing specifies the relative source and destination paths, and can
be modified using Template Toolkit keys.

=item *

Copies files from a source directory tree to a destination directory
tree. They do not need to be copied to the same levels of the tree, or
even have the same resulting filename. Any files in the destination
directory's '.no_overwrite' file will not be copied. (See
L<OpenInteract2::Config::Readonly> for more.)

=back

=head2 Format of FILES document

=over 4

=item *

Blank lines are skipped

=item *

Comments are skipped

=item *

Source path and destination path are separated by a '--E<gt>'
sequence, with all whitespace on either side being eaten up by the
separation.

=item *

Entries in source and destination paths (directories and filenames)
are separated by a single space.

=item *

If a filename in the source path is preceded by a '*', it is copied
as-is and B<NOT> run through the template processor.

=back

B<Example>

(note that this is modified for the example -- there is no website
'widget' directory)

 conf base.conf                 --> conf base.conf
 conf override_spops.ini        --> conf sample-override_spops.ini
 conf server.ini                --> conf server.ini
 
 template *base_main            --> widget global base_main
 template *base_simple          --> widget global base_simple

Given the source directory '/opt/OpenInteract-2.00/sample/website' and
the destination directory '/home/httpd/mysite', the following actions
will be performed:

=over 4

=item *

Copy C</opt/OpenInteract-2.00/sample/website/conf/base.conf> --E<gt>
C</home/httpd/mysite/conf/base.conf>

=item *

Copy C</opt/OpenInteract-2.00/sample/website/conf/override_spops.ini> --E<gt>
C</home/httpd/mysite/conf/sample-override_spops.ini>

=item *

Copy C</opt/OpenInteract-2.00/sample/website/conf/server.ini> --E<gt>
C</home/httpd/mysite/conf/server.ini>

=item *

Copy C</opt/OpenInteract-2.00/sample/website/template/base_main> --E<gt>
C</home/httpd/mysite/widget/global/base_main>, and do not run it through
the template processor.

=item *

Copy C</opt/OpenInteract-2.00/sample/website/template/base_simple> --E<gt>
C</home/httpd/mysite/widget/global/base_simple>, and do not run it through
the template processor.

=back

=head1 METHODS

B<new( $source_dir )>

Creates a new object. The C<$source_dir> is mandatory, and if it is
invalid we throw an exception. We set the C<source_dir> property with
it.

B<run( $dest_dir, [ \%template_vars ] )>

Shortcut for C<read_file_spec()> and C<transfer()>. The same set of
C<\%template_vars> are applied to each, so be sure you do not use the
same key for different purposes in the file listing and file(s) to be
copied.

Returns: in a scalar context returns an arrayref of files copied; in
list context returns an arrayref of files copied and arrayref of files
skipped.

B<read_file_spec( [ \%template_vars ] )>

Reads in the 'FILES' document from C<$source_dir> and stores them in
the C<file_spec> property as an arrayref of arrayrefs. Each top-level
arrayref holds two arrayrefs. The first is the source file
specification, the second is the destination file specification. And
each will be an arrayref even if you specify a filename with no path.

Returns: the new contents of the C<file_spec> property.

B<transfer( $dest_dir, [ \%template_vars ] )>

Transfers the files given the specification read from
C<read_file_spec()>. (If that hasn't been run prior to this, an
exception is thrown.)

Files marked with a '*' in the source specification are not run
through the template processor, everything else is. Generally you need
to do this if the files you're copying are themselves Template Toolkit
templates.

No action will be taken for any files are found in the destination
directory's '.no_overwrite' file. (See
L<OpenInteract2::Config::Readonly>.)

We also don't do anything if two files are the same -- that is, if
their MD5 digests are the same.

=head1 PROPERTIES

B<source_dir>

Source directory of the files to copy, where the C<FILES>
specification is located.

B<file_spec>

Results of C<read_file_spec()> operation, also filled after C<run()>.

B<files_copied>

Results from C<transfer()> operation, also filled after C<run()>.

B<files_skipped>

Results from C<transfer()> operation, also filled after C<run()>.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
