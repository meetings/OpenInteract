package OpenInteract2::Config::IniFile;

# $Id: IniFile.pm,v 1.6 2004/02/17 04:30:13 lachoy Exp $

use strict;
use base qw( OpenInteract2::Config );
use OpenInteract2::Config::Ini;
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Config::IniFile::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use constant META_KEY => '_INI';

sub valid_keys {
    my ( $self ) = @_;
    #return $self->sections;
    #return grep ! /^_/, keys %{ $self };
    return @{ $self->{_m}{order} };
}


sub read_config {
    my ( $class, $params ) = @_;
    if ( $params->{filename} ) {
        $class->is_file_valid( $params->{filename} );
    }
    elsif ( ! $params->{content} ) {
        oi_error "No filename or content given for configuration data";
    }
    my $ini = eval { OpenInteract2::Config::Ini->new({
                                        content  => $params->{content},
                                        filename => $params->{filename} }) };
    if ( $@ ) { oi_error $@ }
    return $ini;
}


# Cheeseball, but it works

sub write_config {
    my ( $self, $filename ) = @_;
    my $backup = $self;
    bless( $backup, 'OpenInteract2::Config::Ini' );
    my $actual_filename = eval { $backup->write_file( $filename ) };
    oi_error $@  if ( $@ );
    return $actual_filename;
}

1;

__END__

=head1 NAME

OpenInteract2::Config::IniFile - OI configuration using INI files

=head1 SYNOPSIS

 my $ini = OpenInteract2::Config->new( 'ini', { filename => 'foo.ini' } );
 print "Value of foo.bar: $ini->{foo}{bar}\n";

=head1 DESCRIPTION

Subclass of L<OpenInteract2::Config|OpenInteract2::Config> that
translates files/content to/from INI format.

=head1 METHODS

B<valid_keys()>

Returns the valid keys in this configuration.

B<read_config()>

Reads a configuration from a file or content passed in.

B<write_config( [ $filename ] )>

Writes the existing configuration to a file. If C<$filename> not
specified will use the file used to originally open the configuration.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::Config::Ini|OpenInteract2::Config::Ini>

L<OpenInteract2::Config|OpenInteract2::Config>

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
