package OpenInteract2::Config::Package;

# $Id: Package.pm,v 1.19 2004/09/26 16:06:30 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast );
use File::Basename ();
use File::Spec;
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Config::Package::VERSION = sprintf("%d.%02d", q$Revision: 1.19 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_FILENAME => 'package.conf';

my @REQUIRED_FIELDS = qw( name version );
sub get_required_fields { return [ @REQUIRED_FIELDS ] }

# Fields in our package/configuration. These are ordered --
# save_config() will output to the file in this order.

my @SERIAL_FIELDS = qw( name version author url
                        spops_file action_file message_file module
                        sql_installer template_plugin
                        observer config_watcher description );
my @OBJECT_FIELDS = qw( filename package_dir );

# Define the keys in 'package.conf' that can be a list, meaning you
# can have multiple items defined:
#
#  author  Larry Wall <larry@wall.org>
#  author  Chris Winters E<lt>chris@cwinters.comE<gt>

# NOTE: If you add a field here you must also add it to @SERIAL_FIELDS

my %LIST_FIELDS = map { $_ => 1 } qw( author module spops_file action_file
                                      message_file config_watcher );

# Define the keys in 'package.conf' that can be a hash, meaning that
# you can have items defined as multiple key-value pairs
# (space-separated):
#
#  template_plugin MyNew OpenInteract2::TT::Plugin::New
#  template_plugin MyURL OpenInteract2::TT::Plugin::URL

# NOTE: If you add a field here you must also add it to @SERIAL_FIELDS

my %HASH_FIELDS = map { $_ => 1 } qw( template_plugin observer );

my @FIELDS      = ( @SERIAL_FIELDS, @OBJECT_FIELDS );
OpenInteract2::Config::Package->mk_accessors( @FIELDS );

########################################
# CLASS METHODS

sub new {
    my ( $class, $params ) = @_;
    my $self = bless( {}, $class );
    my $filename  = $params->{filename};
    my $directory = $params->{package_dir} || $params->{directory};
    if ( ! $filename and $directory ) {
        $filename = $self->create_filename( $directory );
    }
    if ( $filename and -f $filename ) {
        my $new_params = $class->_read_config( $filename );
        $params->{ $_ } = $new_params->{ $_ } for ( keys %{ $new_params } );
        $self->filename( $filename );
        $self->package_dir( File::Spec->rel2abs( File::Basename::dirname( $filename ) ) );
    }
    return $self->init( $params );
}

sub create_filename {
    my ( $class, $dir ) = @_;
    unless ( $dir ) {
        oi_error "Must pass in directory to create package config filename";
    }
    return File::Spec->catfile( $dir, DEFAULT_FILENAME );
}


########################################
# OBJECT METHODS

sub init {
    my ( $self, $params ) = @_;
    for ( @FIELDS ) {
        next unless ( $params->{ $_ } );
        $self->{ $_ } = $params->{ $_ };
    }
    return $self;
}


sub get_spops_files {
    my ( $self ) = @_;
    my $spops_files = $self->spops_file;
    my $dir = $self->package_dir;
    unless ( ref $spops_files eq 'ARRAY' and scalar @{ $spops_files } ) {
        return [];
    }
    return $spops_files;
}

sub get_action_files {
    my ( $self ) = @_;
    my $action_files = $self->action_file;
    my $dir = $self->package_dir;
    unless ( ref $action_files eq 'ARRAY' and scalar @{ $action_files } ) {
        return [];
    }
    return $action_files;
}

sub get_message_files {
    my ( $self ) = @_;
    my $message_files = $self->message_file;
    my $dir = $self->package_dir;
    unless ( ref $message_files eq 'ARRAY' and scalar @{ $message_files } ) {
        return [];
    }
    return $message_files;
}

sub check_required_fields {
    my ( $self, @check_fields ) = @_;

    my @all_check_fields = ( @check_fields, @REQUIRED_FIELDS );

   # First ensure that required fields are set

    my @empty_fields = ();
    foreach my $field ( @all_check_fields ) {
        my $value = $self->$field();
        if ( $LIST_FIELDS{ $field } ) {
            unless ( ref $value eq 'ARRAY' and scalar @{ $value } ) {
                push @empty_fields, $field;
            }
        }
        elsif ( $HASH_FIELDS{ $field } ) {
            unless ( ref $value eq 'HASH' and scalar keys %{ $value } ) {
                push @empty_fields, $field;
            }
        }
        else {
            unless ( $value ) {
                push @empty_fields, $field;
            }
        }
    }

    if ( scalar @empty_fields ) {
        oi_error "Required fields check failed: the following fields ",
                 "must be defined: ", join( ", ", @empty_fields );
    }
    return 1;
 }


sub save_config {
    my ( $self ) = @_;

    unless ( $self->filename() ) {
        oi_error "Save failed: set filename first";
    }

    $self->check_required_fields;
    eval { open( CONF, '> ' . $self->filename ) || die $! };
    if ( $@ ) {
        oi_error "Cannot open [", $self->filename, "] for writing: $@";
    }
    foreach my $field ( @SERIAL_FIELDS ) {
        if ( $LIST_FIELDS{ $field } ) {
            my $values = $self->$field() || [];
            foreach my $value ( @{ $values } ) {
                print CONF $self->_line_single_value( $field, $value );
            }

        }
        elsif ( $HASH_FIELDS{ $field } ) {
            my $h = $self->$field() || {};
            while ( my ( $key, $value ) = each %{ $h } ) {
                print CONF $self->_line_keyed_value( $field, $key, $value );
            }
        }
        elsif ( $field eq 'description' ) {
            print CONF "$field\n", $self->description, "\n";
        }
        else {
            print CONF $self->_line_single_value( $field, $self->$field() );
        }
    }
    close( CONF );
    return $self->filename;
}


# Read in the configuration, returning a hashref of data. Fields in
# %LIST_FIELDS are read into an arrayref (even if only one exists);
# fields in %HASH_FIELDS are read into a hashref

sub _read_config {
    my ( $class, $filename )  = @_;
    unless ( -f $filename ) {
        die "Package configuration file [$filename] does not exist.\n";
    }
    eval { open( CONF, '<', $filename ) || die $! };
    if ( $@ ) {
        oi_error "Cannot open package configuration [$filename]: $@";
    }

    my %config = ();
    while ( <CONF> ) {
        next if ( /^\s*\#/ );
        next if ( /^\s*$/ );
        chomp;
        s/\r//g;
        s/^\s+//;
        s/\s+$//;
        my ( $field, $value ) = split /\s+/, $_, 2;
        last if ( $field eq 'description' );

        # If there are multiple values possible, make a list

        if ( $LIST_FIELDS{ $field } and $value ) {
            push @{ $config{ $field } }, $value;
        }

        # Otherwise, if it's a key -> key -> value set; add to list

        elsif ( $HASH_FIELDS{ $field } and $value ) {
            my ( $sub_key, $sub_value ) = split /\s+/, $value, 2;
            $config{ $field }->{ $sub_key } = $sub_value;
        }

        # If not all that, then simple key -> value

        else {
            $config{ $field } = $value;
        }
    }

    # Once all that is done, read the description in all at once

    {
        local $/ = undef;
        $config{description} = <CONF>;
    }
    chomp $config{description};
    close( CONF );
    return \%config;
}


sub _line_single_value {
    my ( $class, $field, $value ) = @_;
    $value ||= '';
    return sprintf "%-20s%s\n", $field, $value;
}


sub _line_keyed_value {
    my ( $class, $field, $key, $value ) = @_;
    $value ||= '';
    return sprintf "%-20s%-15s%s\n", $field, $key, $value;
}

1;

__END__

=head1 NAME

OpenInteract2::Config::Package - Read, write and check package config files

=head1 SYNOPSIS

 # Sample package file
 name                MyPackage
 version             1.53
 author              Steve <steve@dude.com>
 author              Chuck <chuck@guy.com>
 url                 http://www.oirox.com/
 template_plugin     TestPlugin     OpenInteract2::Plugin::Test
 observer            mywiki         OpenInteract2::Filter::MyWiki
 description
 This package rocks!

 # Create a new package file from scratch
 
 use OpenInteract2::Config::Package;
 
 my $c = OpenInteract2::Config::Package->new();
 $c->name( 'MyPackage' );
 $c->version( 1.53 );
 $c-> url( 'http://www.oirox.com/' );
 $c->author( [ 'Steve <steve@dude.com>', 'Chuck <chuck@guy.com>' ] );
 $c->template_plugin({ TestPlugin => 'OpenInteract2::Plugin::Test' });
 $c->description( 'This package rocks!' );
 
 # Set the filename to save the config to and save it
 
 $c->filename( 'mydir/pkg/MyPackage/package.conf' );
 eval { $c->save_config };
 
 # Specify a directory for an existing config
 
 my $c = OpenInteract2::Config::Package->new(
                    { directory => '/path/to/mypackage' } );
 
 # Specify a filename for an existing config
 
 my $c = OpenInteract2::Config::Package->new(
                    { filename => 'work/pkg/mypackage/package-alt.conf' } );

=head1 DESCRIPTION

This class implements read/write access to a package configuration
file. This is a very simple line-based format. There are three types
of values:

B<single value>

Example:

 name               MyPackage

B<multiple value>

Example:

 author             Chris Winters E<lt>chris@cwinters.comE<gt>
 author             Mario Lemiux <mario@pghpenguins.com>

B<multiple keyed value>

Example:

 template_plugin    MyPlugin     OpenInteract2::Template::Plugin::MyPlugin
 template_plugin    MyPluginNew  OpenInteract2::Template::Plugin::MyPluginNew
 observer           mywiki       OpenInteract2::Filter::MyWiki

Additionally, all data below the last entry C<description> is used as
the description. Example:

 description
 Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam
 nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat
 volutpat. Ut wisi enim ad minim veniam, quis nostrud exercitation
 ulliam corper suscipit lobortis nisl ut aliquip ex ea commodo

=head1 METHODS

=head2 Class Methods

B<new( \%params )>

Creates a new configuration object from C<\%params>:

=over 4

=item *

C<filename>: Read the configuration from this file

=item *

C<directory>: Read the configuration from the file C<package.conf>
located in this directory. (Also: C<package_dir>)

=back

Other fields in C<\%params> are used to set the values of the
object. If you pass a filename/directory B<and> parameters, the
parameters will be overridden by whatever is read from the file.

Returns: new object

B<create_filename( $directory )>

Create a filename for this configuration file given C<$directory>. The
default name for the package configuration file is C<package.conf>.

Examples:

 my $filename = OpenInteract2::Config::Package->create_filename( '/home/httpd/mysite/pkg/foo' );
 # $filename: '/home/httpd/mysite/pkg/foo/package.conf'

We do not check whether C<$directory> exists or whether the resulting
filename is valid.

Returns: filename

B<get_required_fields()>

Returns: Arrayref of fields required for configuration object to be
valid.

=head2 Object Methods

B<init( \%params )>

Initialize the object with C<\%params>. Only fields listed in
L<PROPERTIES> will be set, and only properties with a value will be
set.

Returns: object

B<get_spops_files()>

Returns all SPOPS files in this package as set in C<spops_file>,
relative to the package directory (set in C<package_dir>). This module
does not verify that the files exist and are coherent, it just reports
what is configured. If no entries are in C<spops_file>, it returns an
empty arrayref.

Example:

 name        foo
 version     1.51
 spops_file  conf/object_one.ini
 spops_file  conf/object_two.ini
 ...
 $config->package_dir( '/home/me/pkg' )
 my $files = $config->get_spops_files();
 # [ 'conf/object_one.ini', 'conf/object_two.ini' ]

Returns: Arrayref of filenames, not fully-qualified. If no files
declared return an empty arrayref.

B<get_action_files()>

Returns all action files in this package as set in C<action_file>,
relative to the package directory (set in C<package_dir>). This module
does not verify that the files exist and are coherent, it just reports
what is configured. If no entries are in C<action_file>, it returns an
empty arrayref.

Example:

 name        foo
 version     1.51
 action_file  conf/action_one.ini
 action_file  conf/action_two.ini
 ...
 $config->package_dir( '/home/me/pkg' )
 my $files = $config->get_action_files();
 # [ 'conf/action_one.ini', 'conf/action_two.ini' ]

Returns: Arrayref of filenames, not fully-qualified. If no files
declared returns an empty arrayref.

B<get_message_files()>

Returns all message files in this package as set in C<message_file>,
relative to the package directory (set in C<package_dir>). This module
does not verify that the files exist and are coherent, it just reports
what is configured. If no entries are in C<message_file>, it returns an
empty arrayref.

Example:

 name          foo
 version       1.51
 message_file  data/foo-en.msg
 message_file  data/foo-en_us.msg
 message_file  data/foo-en_uk.msg
 ...
 $config->package_dir( '/home/me/pkg' )
 my $files = $config->get_message_files();
 # [ 'data/foo-en.msg', 'data/foo-en_us.msg', 'data/foo-en_uk.msg' ]

Returns: Arrayref of filenames, not fully-qualified. If no files
declared returns an empty arrayref.

B<check_required_fields( [ @check_fields ] )>

Check whether the required fields are set in the object. Required
fields are those returned by C<get_required_fields()>; you can also
add your own to check using C<@check_fields>.

Returns: true if all required fields are defined, throws exception if
not.

B<save_config()>

Saves the configuration information to a file. The property
C<filename> must be set, otherwise an exception is thrown. An
exception is also thrown if C<filename> cannot be opened for writing.

Returns: Filename where the configuration was written.

=head1 PROPERTIES

=head2 Filesystem Properties

Both of these will be set automatically if you pass in either
C<filename> or C<directory> to C<new()>

B<filename>: File where the configuration is written.

B<package_dir>: Directory in which the configuration is written.

=head2 Configuration Properties

These are all read from and written to the configuration file.

B<name> ($) (mandatory)

Name of the package

B<version> ($) (mandatory)

Package version

B<author> (\@)

Author(s) of the package

B<url> ($)

URL where you can find out more information

B<spops_file> (\@)

File with SPOPS objects defined in this package. If you do not specify
these you must store all object configuration information in a single
file C<conf/spops.ini>. Both perl- and INI-formatted configurations
are acceptable. (TODO: true?)

B<action_file> (\@)

File with the actions defined in this package. If you do not specify
these you must store all action information in a single file
C<conf/action.ini>. Both perl- and INI-formatted configurations are
acceptable. (TODO: true?)

B<message_file> (\@)

File with the localized messages used in your application. If you do
not specify these you must store your message files in a subdirectory
C<msg/> and in files ending with C<.msg>. The format of these files is
discussed in L<OpenInteract2::I18N|OpenInteract2::I18N> and
L<OpenInteract2::Manual::I18N|OpenInteract2::Manual::I18N>.

B<module> (\@)

Module(s) required by this package.

B<sql_installer> ($)

SQL installer class to use for this package.

B<template_plugin> (\%)

Template Toolkit plugins defined by this package. Each plugin is
defined by a space-separated key/value pair. The template users access
the plugin by the key, the value is used to instantiate the plugin.

B<observers> (\%)

Observers (commonly in the guise of filters) defined by this
package. It should be in a space-separated key/value pair simiilar to
C<template_plugin>, where the key defines the observer name and the
value defines the observer class.

B<config_watcher> (\@)

Classes defined by this package that will observe
L<OpenInteract2::Config::Initializer|OpenInteract2::Config::Initializer>
events at server startup. You can use this to create custom, concise
directives for your SPOPS and/or Action configurations that get
expanded into either more meaningful information or into data that can
only be found at runtime. That may be a little abstract: see
L<OpenInteract2::Config::Initializer|OpenInteract2::Config::Initializer>
for examples.

C<description> ($*)

Description of this package. Instead of reading a single line we read
every line after the 'description' key to the end of the file. Do not
put additional configuration keys under 'description', they will not
be read.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<OpenInteract2::Package|OpenInteract2::Package>

L<Class::Accessor|Class::Accessor>

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
