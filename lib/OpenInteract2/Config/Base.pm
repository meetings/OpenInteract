package OpenInteract2::Config::Base;

# $Id: Base.pm,v 1.7 2003/06/24 03:35:38 lachoy Exp $

use strict;
use base qw( Exporter Class::Accessor );
use File::Basename           qw( dirname );
use File::Spec               qw();
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log BASE_CONF_DIR BASE_CONF_FILE );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Config::Base::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my @CONFIG_FIELDS = qw( website_dir temp_lib_dir package_dir
                        config_type config_class config_dir config_file );
my @FIELDS        = ( @CONFIG_FIELDS, 'filename' );
OpenInteract2::Config::Base->mk_accessors( @FIELDS );

########################################
# CLASS METHODS

sub new {
    my ( $class, $params ) = @_;
    my $self = bless( {}, $class );
    my $filename = $params->{filename};
    my $website_dir = $params->{website_dir};
    if ( ! $filename and $website_dir ) {
        $filename = $self->create_website_filename( $website_dir );
        $self->website_dir( $website_dir );
    }

    # If the last directory of the specified file is 'conf', assume
    # that everything else is the website dir

    elsif ( $filename and ! $website_dir ) {
        $filename = File::Spec->rel2abs( $filename );
        my @dirs = File::Spec->splitdir( dirname( $filename ) );
        if ( $dirs[-1] eq 'conf' ) {
            pop @dirs;
            $self->website_dir( File::Spec->catdir( @dirs ) );
        }
    }
    if ( $filename and -f $filename ) {
        $params = $self->read_config( $filename );
        $self->filename( $filename );
    }
    return $self->initialize( $params );
}


sub read_config {
    my ( $class, $filename ) = @_;
    my $log = get_logger( LOG_CONFIG );
    unless ( -f $filename ) {
        $log->error( "Config file [$filename] does not exist" );
        oi_error "Cannot open [$filename] for base configuration: ",
                 "file does not exist";
    }
    eval { open( CONF, "< $filename" ) || die $! };
    if ( $@ ) {
        $log->error( "Failed to open [$filename]: $@" );
        oi_error "Cannot open [$filename] for base configuration: $@";
    }
    my $vars = {};
    while ( <CONF> ) {
        chomp;
        $log->is_debug &&
            $log->debug( "Config line read: $_" );
        next if ( /^\s*\#/ );
        next if ( /^\s*$/ );
        s/^\s*//;
        s/\s*$//;
        my ( $var, $value ) = split /\s+/, $_, 2;
        $vars->{ $var } = $value;
    }
    return $vars;
}


sub create_website_filename {
    my ( $class, $dir ) = @_;
    unless ( $dir ) {
        oi_error "Must pass in website directory to create base ",
                 "config filename";
    }
    return $class->create_filename(
                   File::Spec->catdir( $dir, BASE_CONF_DIR ) );
}

sub create_filename {
    my ( $class, $dir ) = @_;
    unless ( $dir ) {
        oi_error "Must pass in directory to create base config filename";
    }
    return File::Spec->catfile( $dir, BASE_CONF_FILE );
}


########################################
# OBJECT METHODS

sub initialize {
    my ( $self, $params ) = @_;
    foreach my $field ( @CONFIG_FIELDS ) {
        next unless ( $params->{ $field } );
        $self->$field( $params->{ $field } );
    }
    return $self;
}


sub clean_dir {
    my ( $self, $prop ) = @_;
    my $dir = $self->$prop();
    $dir =~ s|/$||;
    return $self->$prop( $dir );
}


sub get_server_config_file {
    my ( $self ) = @_;
    unless ( $self->website_dir and $self->config_dir and
             $self->config_file ) {
        oi_error "Properties 'website_dir', 'config_dir' and 'config_file' ",
                 "must be defined to retrieve the config filename.";
    }
    $self->clean_dir( 'website_dir' );
    $self->clean_dir( 'config_dir' );
    return File::Spec->catfile( $self->website_dir,
                                $self->config_dir,
                                $self->config_file );
}


sub save_config {
    my ( $self, ) = @_;

    # First ensure that everything necessary is set
    my @empty_fields = grep { ! $self->$_() } @CONFIG_FIELDS;
    if ( scalar @empty_fields ) {
        oi_error "Cannot save base config: the following fields must be",
                 "defined: ", join( ", ", @empty_fields );
    }

    # If not filename set, create one from the website_dir

    unless ( $self->filename() ) {
        $self->filename(
            $self->create_website_filename( $self->website_dir )
        );
    }

    eval { open( CONF, '>', $self->filename ) || die $! };
    if ( $@ ) {
        oi_error "Cannot open [", $self->filename, "] for writing: $@";
    }
    foreach my $config ( @CONFIG_FIELDS ) {
        printf CONF "%-20s%s\n", $config, $self->$config();
    }
    close( CONF );
    return $self->filename;
}

1;

__END__

=head1 NAME

OpenInteract2::Config::Base - Represents a server base configuration

=head1 SYNOPSIS

 # Sample base configuration
 
 website_dir      /path/to/mysite
 config_type      ini
 config_class     OpenInteract2::Config::IniFile
 config_dir       conf
 config_file      server.ini
 package_dir      pkg

 # Open an existing base config
 
 my $bc = OpenInteract2::Config::Base->new({
                    website_dir => '/path/to/mysite' });
 my $bc = OpenInteract2::Config::Base->new({
                    filename => '/path/to/mysite/conf/base-alt.conf' });

 # Create a new one and write it with the default filename
 
 my $bc = OpenInteract2::Config::Base->new;
 $bc->website_dir( '/path/to/mysite' );
 $bc->config_type( 'ini' );
 $bc->config_class( 'OpenInteract2::Config::IniFile' );
 $bc->config_dir( 'conf' );
 $bc->config_file( 'server.ini' );
 $bc->package_dir( 'pkg' );
 $bc->write;

=head1 DESCRIPTION

A base configuration enables you to easily bootstrap an OpenInteract
server configuration with just a little information.

=head1 METHODS

=head2 Class Methods

B<new( [ \%params ] )>

Creates a new base config object. You can initialize it with as many
parameters as you like if you are creating one from scratch.

You can also pass in one of:

=over 4

=item B<filename>

=item B<website_dir>

=back

And the constructor will read values from C<filename> or the filename
returned by C<create_filename()> with C<website_dir>. The constructor
will also set the C<filename> property to the file from which the
values were read.

Returns: A C<OpenInteract2::Config::Base> object.

B<read_config( $filename )>

Reads configuration values from C<$filename> and returns the
configured key/value pairs. When reading in the file we sskip all
blank lines as well as lines beginning with a '#' for comments. Extra
space is stripped from the beginning and ending of all keys and values.

Returns: Hashref of config values from $filename.

B<create_website_filename( $website_directory )>

Creates a typicaly configuration filename given
C<$website_directory>. This is:

 $website_directory/BASE_CONF_DIR/BASE_CONF_FILE

where C<BASE_CONF_DIR> and C<BASE_CONF_FILE> are from
L<OpenInteract2::Constants|OpenInteract2::Constants>.


An exception is thrown if C<$directory> is not provided. We do not
check whether C<$directory> is a valid directory.

Returns: a potential filename for a base config object

B<create_filename( $directory )>

Creates a typical configuration filename given C<$directory>. This is:

 $directory/BASE_CONF_FILE

where C<BASE_CONF_FILE> is from
L<OpenInteract2::Constants|OpenInteract2::Constants>.

An exception is thrown if C<$directory> is not provided. We do not
check whether C<$directory> is a valid directory.

Returns: a potential filename for a base config object

=head2 Object Methods

B<initialize( \%params )>

You will probably never call this as it is only used from the
constructor.

Returns: a C<OpenInteract2::Config::Base> object with relevant
properties from C<\%params> set.

B<clean_dir( $property_name )>

Remove the trailing '/' from the directory specified by
C<$property_name>. Sets the property in the object and returns the
cleaned directory.

Example:

  $bc->clean_dir( 'config_dir' );
  $bc->clean_dir( 'website_dir' );

Returns: the cleaned directory.

B<get_server_config_file()>

Puts together the properties 'website_dir', 'config_dir' and
'config_file' to create a fully qualified filename.

Returns: full filename for the server config.

B<save_config()>

Writes the configured values from the object to a file. If you do not
set a filename before calling this the method will create one for you
using C<create_filename()> and the value from the C<website_dir>
property.

If you do not have all the properties defined the method will throw an
exception.

Returns: the filename to which the configuration was written.

=head1 PROPERTIES

B<website_dir>: Root directory of the website

B<config_type>: Type of configuration site is using

B<config_class>: Class used to read server configuration

B<config_dir>: Directory where configuration is kept, relative to
C<website_dir>

B<config_file>: Name of configuration file in C<config_dir>

B<package_dir>: Directory where packages are kept, relative to
C<website_dir>.

B<filename>: Location of base_configuration file. Not written out to
the base configuration file.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<Class::Accessor|Class::Accessor>

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
