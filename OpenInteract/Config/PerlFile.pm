package OpenInteract::Config::PerlFile;

# $Id: PerlFile.pm,v 1.8 2001/02/01 05:27:40 cwinters Exp $

use strict;
use Data::Dumper     qw( Dumper );
use OpenInteract::Config;

@OpenInteract::Config::PerlFile::ISA     = qw( OpenInteract::Config );
$OpenInteract::Config::PerlFile::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

sub read_config {
  my ( $class, $filename ) = @_;
  unless ( -f $filename ) {
    my $msg = 'Cannot read configuration file!';
    OpenInteract::Error->set( { user_msg => $msg, type => 'config',
                                system_msg => "No valid filename ($filename) for reading configuration information!",
                                method => 'read_config',
                                extra => { filename => $filename } } );
    die $msg;
  }
  if ( DEBUG ) { warn " (Config/PerlFile): Reading configuration from $filename\n"; }
  eval { open( CONF, "$filename" ) || die $! };
  if ( $@ ) {
    my $msg = 'Cannot read configuration file!';
    OpenInteract::Error->set( { user_msg => $msg, type => 'config',
                                system_msg => "Error trying to open $filename: $@",
                                method => 'read_config',
                                extra => { filename => $filename } } );
    die $msg;
  }
  local $/ = undef;
  my $config = <CONF>;
  close( CONF );
  my ( $data );
  eval $config;
  if ( $@ ) {
    my $msg = 'Cannot read configuration file!';
    OpenInteract::Error->set( { user_msg => $msg, type => 'config',
                                system_msg => "Error trying to eval $filename: $@",
                                method => 'read_config',
                                extra => { config => $config } } );
    die $msg;
  }
  if ( DEBUG > 1 ) { warn " (Config/PerlFile): Structure of config:\n", Dumper( $data ), "\n"; }
  return $data;
}



sub save_config {
  my ( $self, $filename ) = @_;
  $filename ||= join( '/', $self->get_dir( 'config' ), $self->{config_file} ); 
  unless ( -f $filename ) {
    my $msg = 'Cannot read configuration file!';
    OpenInteract::Error->set( { user_msg => $msg, type => 'config',
                                system_msg => "No valid filename for saving configuration information!",
                                method => 'save_config',
                                extra => { filename => $filename } } );
    die $msg;
  }
  eval { open( CONF, "> $filename" ) || die $! };
  if ( $@ ) {
    my $msg = 'Cannot read configuration file!';
    OpenInteract::Error->set( { user_msg => $msg, type => 'config',
                                system_msg => "Error trying to write $filename: $@",
                                method => 'save_config',
                                extra => { filename => $filename } } );
    die $msg;
  }
  my %data = %{ $self };
  my $config = Data::Dumper->Dump( [ \%data ], [ 'data' ] );
  print CONF $config;
  close( CONF );
  return $self;
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Config::PerlFile - subclass of OpenInteract::Config for reading information from a perl file

=head1 DESCRIPTION

Create a 'read_config' method to override the base Config
method. See I<OpenInteract::Config> for usage of this base object.

The information in the config file is perl, so we do not 
have to go through any nutty contortions with types, etc.

=head1 METHODS

B<read_config( $filename )>

Read configuration directives from $filename. The 
configuration directives are actually perl data structures
saved in an I<eval>able format using I<Data::Dumper>.

B<save_config( $filename )>

Saves the current configuration to $filename. Normally
not needed since you are not always changing configurations
left and right.

=head1 TO DO

=head1 BUGS 

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
