package OpenInteract::Config::IniFile;

# $Id: IniFile.pm,v 1.2 2001/10/17 04:48:58 lachoy Exp $

use strict;
use OpenInteract::Config qw( _w DEBUG );
use OpenInteract::Config::Ini;

@OpenInteract::Config::IniFile::ISA     = qw( OpenInteract::Config );
$OpenInteract::Config::IniFile::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use constant META_KEY => '_INI';


sub read_config {
    my ( $class, $filename ) = @_;
    $class->is_file_valid( $filename );
    my $ini = OpenInteract::Config::Ini->new({ filename => $filename });
    return $ini;
}


# Cheeseball, but it works

sub write_config {
    my ( $self ) = @_;
    my $backup = $self;
    bless( $backup, 'OpenInteract::Config::Ini' );
    $backup->write_file;
}


1;
