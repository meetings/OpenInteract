package OpenInteract2::Upload;

# $Id: Upload.pm,v 1.6 2005/03/17 14:57:58 sjn Exp $

use strict;
use base qw( Class::Accessor::Fast );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::File;

$OpenInteract2::Upload::VERSION  = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( name filehandle content_type size tmp_name );
OpenInteract2::Upload->mk_accessors( @FIELDS );

sub FUNNY_CHARACTERS { return '\\\'"!#\$\%\|&\^\*\<\>{}\[\]\(\)\?' }

########################################
# CLASS METHODS

# Constructor

sub new {
    my ( $class, $params ) = @_;
    my $self = bless( {}, $class );
    foreach my $field ( ( @FIELDS, 'filename' ) ) {
        next unless ( $params->{ $field } );
        $self->$field( $params->{ $field } );
    }
    return $self;
}


# Clean up the filename given by the client -- we could probably use
# File::Basename here, but we don't know what OS the client is running
# to set in fileparse_set_fstype(). This is called whenever you call
# the filename() set method

sub base_filename {
    my ( $class, $name ) = @_;
    $name =~ s|^.*/(.*)$|$1|;
    $name =~ s|^.*\\(.*)$|$1|;
    return $name;
}


sub clean_filename {
    my ( $class, $name ) = @_;
    $name =~ s/^\.+//;
    $name =~ s/\.\./_/g;
    $name =~ s/\s/_/g;
    my $funny_chars = $class->FUNNY_CHARACTERS;
    $name =~ s/[$funny_chars]//g;
    return $name;
}


########################################
# OBJECT METHODS

# Not auto-generated by Class::Accessor so we can ensure the filename
# does not have any leading directories.

sub filename {
    my ( $self, $filename ) = @_;
    if ( $filename ) {
        $self->{filename} = $self->clean_filename( $self->base_filename( $filename ) );
    }
    return $self->{filename};
}

# Common aliases

sub fh   { my $self = shift; return $self->filehandle( @_ ); }
sub type { my $self = shift; return $self->content_type( @_ ); }


sub save_file {
    my ( $self, $filename ) = @_;
    unless ( $self->filehandle ) {
        oi_error "Filehandle not set in upload object, cannot save";
    }
    $filename ||= $self->filename;
    return OpenInteract2::File->save_file( $self->filehandle, $filename );
}

1;

__END__

=head1 NAME

OpenInteract2::Upload - Represent a file upload

=head1 SYNOPSIS

 my $request = OpenInteract2::Request->get_current;

 # Get the upload as listed under 'input_file'
 my $upload = $request->upload( 'input_file' );

 # Get information about the upload
 print "Filename: ", $upload->filename, "\n",
       "Cleaned filename: ", $upload->clean_filename( $upload->filename ), "\n",
       "Size: ", $upload->size, " bytes\n",
       "Content-type: ", $upload->content_type, "\n";

 # Dump the data uploaded to a file the long way...

 open( NEW, "> blah" ) || die "cannot open blah: $!";
 my ( $data );
 my $filehandle = $upload->fh;
 binmode NEW;
 while ( read( $filehandle, $data, 1024 ) ) {
     print NEW $data;
 }

 # ...or the short way

 $upload->save_file;                  # use a cleaned up version of the
                                      # filename specified by the user
 $upload->save_file( 'newname.foo' ); # specify the filename yourself

=head1 DESCRIPTION

This class defines an object representing a generic uploaded file. The
L<OpenInteract2::Request|OpenInteract2::Request> subclasses must define
one of these objects for each file uploaded from the client.

=head1 METHODS

=head2 Class Methods

B<new( \%params )>

Defines a new upload object. The C<\%params> can be one or more of the
L<PROPERTIES>.

B<base_filename( $filename )>

Removes any leading directories from C<filename>. Web clients will
frequently include the full path when sending an uploaded file, which
is useless. This is called automatically when you call the
C<filename()> set method.

B<clean_filename( $filename )>

Removes a number of 'bad' characters from C<filename>. This is not
called automatically.

=head2 Object Methods

B<save_file( [ $filename ] )>

Saves the filehandle associated with this upload object to
C<$filename>. An exception is thrown if C<$filename> is outside
C<$website_dir> or if there is an error writing the file.

You can leave off C<$filename> and OpenInteract will save the file to
the 'upload' directory set in your server configuration. This
directory must be writeable by the process the server runs under.

See L<OpenInteract2::File|OpenInteract2::File> for the heuristic used
for finding a filename to save the content.

Returns: the full path to the filename saved

=head1 PROPERTIES

All properties have a corresponding combined get/set method.

B<name>: Name of the field that holds the uploaded file. If you are
using an HTML form to get the file from the client, this is the name
of the FILE field.

B<filename>: Name of the file as reported by the client. Note that
whenever you call the set method the value supplied is run through
C<base_filename()> before being set into the object. (Alias: C<fh>)

B<filehandle>: A filehandle reference suitable for reading the
uploaded file.

B<content_type>: The MIME content type as reported by the client. (Be
warned: sometimes the client lies or is just plain ignorant.) (Alias:
C<type>)

B<size>: The size of the uploaded file, in bytes.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<Apache::Request|Apache::Request>

L<CGI|CGI>

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
