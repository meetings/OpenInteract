package OpenInteract::Config::IniFile;

# $Id: IniFile.pm,v 1.4 2002/04/22 05:05:17 lachoy Exp $

use strict;
use OpenInteract::Config qw( _w DEBUG );
use OpenInteract::Config::Ini;

@OpenInteract::Config::IniFile::ISA     = qw( OpenInteract::Config );
$OpenInteract::Config::IniFile::VERSION = substr(q$Revision: 1.4 $, 10);

use constant META_KEY => '_INI';

sub valid_keys {
    my ( $self ) = @_;
    return $self->sections;
    #return grep ! /^_/, keys %{ $self };
}


sub read_config {
    my ( $class, $filename ) = @_;
    $class->is_file_valid( $filename );
    return OpenInteract::Config::Ini->new({ filename => $filename });
}


# Cheeseball, but it works

sub write_config {
    my ( $self ) = @_;
    my $backup = $self;
    bless( $backup, 'OpenInteract::Config::Ini' );
    $backup->write_file;
}


1;
