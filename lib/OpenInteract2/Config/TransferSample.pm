package OpenInteract2::Config::TransferSample;

use strict;
use base qw( Class::Accessor );
use File::Copy               qw( cp );
use File::Spec;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Template;

$OpenInteract2::Config::TransferSample::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( source_dir file_spec files_copied );
__PACKAGE__->mk_accessors( @FIELDS );

sub new {
    my ( $class, $source_dir ) = @_;
    my $self = bless( {}, $class );
    $source_dir = File::Spec->rel2abs( $source_dir );
    unless ( -d $source_dir ) {
        oi_error "Given source directory [$source_dir] is invalid";
    }
    $self->source_dir( $source_dir );
    $self->{_template} = Template->new( ABSOLUTE => 1 );
    return $self;
}

sub run {
    my ( $self, $dest_dir, $template_vars ) = @_;
    $self->read_file_spec( $template_vars );
    return $self->transfer( $dest_dir, $template_vars );
}

sub read_file_spec {
    my ( $self, $template_vars ) = @_;
    my $copy_list_file = File::Spec->catfile( $self->source_dir, 'FILES' );
    unless ( -f $copy_list_file ) {
        oi_error "File from which I read the file specifiecations ",
                 "[$copy_list_file] does not exist";
    }

    $template_vars ||= {};
    my ( $content );
    $self->{_template}->process( $copy_list_file, $template_vars, \$content )
                    || oi_error "Cannot process template with files to ",
                                "copy [$copy_list_file]: ",
                                $self->{_template}->error;
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
        oi_error "You must run 'read_file_spec()' before running 'transfer()'";
    }

    $template_vars ||= {};
    my @copied = ();
    foreach my $info ( @{ $self->file_spec } ) {
        my $source_spec = $info->[0];
        my $dest_spec   = $info->[1];
        my ( $copy_only );
        if ( $source_spec->[-1] =~ /^\*/ ) {
            $copy_only++;
            $source_spec->[-1] =~ s/^\*//;
        }
        my $full_source_file = File::Spec->catfile( $self->source_dir,
                                                    @{ $source_spec } );
        my $full_dest_file   = File::Spec->catfile( $dest_dir,
                                                    @{ $dest_spec } );

        # NOTE: You shouldn't assume because ( ! keys %{ $template_vars } )
        # that you should use copy only -- there might be other templating
        # directives in the file to copy...

        if ( $copy_only ) {
            cp( $full_source_file, $full_dest_file )
                    || oi_error "Cannot copy [$full_source_file] -> ",
                                "[$full_dest_file]: $!";
        }

        else {
            $self->{_template}->process( $full_source_file, $template_vars, $full_dest_file )
                    || oi_error "Cannot copy and token-replace file ",
                                "[$full_source_file] -> [$full_dest_file]: ",
                                $self->{_template}->error;
        }
        push @copied, $full_dest_file;
    }
    return $self->files_copied( \@copied );
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
even have the same resulting filename.

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

=head1 PROPERTIES

B<source_dir>

Source directory of the files to copy, where the C<FILES>
specification is located.

B<file_spec>

Results of C<read_file_spec()> operation, also filled after C<run()>.

B<files_copied>

Results of C<transfer()> operation, also filled after C<run()>.

=head1 TO DO

B<Copy only new files>

For files that are marked as copy-only, compare the file size and
date. If both are equal, don't do the copy. (Makes it easy for people
to see what's new.)

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
