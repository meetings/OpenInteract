package OpenInteract2::Brick::Package;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'package.ini' => 'PACKAGEINI',
    'MANIFEST.SKIP' => 'MANIFESTSKIP',
    'spops.ini' => 'SPOPSINI',
    'action.ini' => 'ACTIONINI',
    'SQLInstall.pm' => 'SQLINSTALLPM',
    'Action.pm' => 'ACTIONPM',
    'App.pm' => 'APPPM',
    'sample.tmpl' => 'SAMPLETMPL',
);

sub get_name {
    return 'package';
}

sub get_resources {
    return (
        'package.ini' => [ 'package.ini', 'yes' ],
        'MANIFEST.SKIP' => [ 'MANIFEST.SKIP', 'yes' ],
        'spops.ini' => [ 'conf spops.ini', 'yes' ],
        'action.ini' => [ 'conf action.ini', 'yes' ],
        'SQLInstall.pm' => [ 'OpenInteract2 SQLInstall [% class_name %].pm', 'yes' ],
        'Action.pm' => [ 'OpenInteract2 Action [% class_name %].pm', 'yes' ],
        'App.pm' => [ 'OpenInteract2 App [% class_name %].pm', 'yes' ],
        'sample.tmpl' => [ 'template sample.tmpl', 'no' ],
    );
}

sub load {
    my ( $self, $resource_name ) = @_;
    my $inline_sub_name = $INLINED_SUBS{ $resource_name };
    unless ( $inline_sub_name ) {
        OpenInteract2::Exception->throw(
            "Resource name '$resource_name' not found ",
            "in ", ref( $self ), "; cannot load content." );
    }
    return $self->$inline_sub_name();
}

OpenInteract2::Brick->register_factory_type( get_name() => __PACKAGE__ );

=pod

=head1 NAME

OpenInteract2::Brick::Package - All resources used for creating a package

=head1 SYNOPSIS

  oi2_manage create_package --package=foo

=head1 DESCRIPTION

This class just holds all the static resources used when creating a package.

These resources are associated with OpenInteract2 version 1.99_06.

=head2 Resources

You can grab resources individually using the names below and
C<load_resource()> and C<copy_resources_to()>, or you can copy all the
resources at once using C<copy_all_resources_to()> -- see
L<OpenInteract2::Brick> for details.

=over 4


=item B<package.ini>

=item B<MANIFEST.SKIP>

=item B<spops.ini>

=item B<action.ini>

=item B<SQLInstall.pm>

=item B<Action.pm>

=item B<App.pm>

=item B<sample.tmpl>


=back

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS


Chris Winters E<lt>chris@cwinters.comE<gt>


=cut


sub PACKAGEINI {
    return <<'SOMELONGSTRING';
[package]
name            = [% package_name %]
version         = 0.01
author          = Who AmI <me@whoami.com>
url             = http://www.whereami.com/
sql_installer   = OpenInteract2::SQLInstall::[% class_name %]
description     = Description of package [% package_name %]  goes here. Use can use '\' as a line continuation.

# Dependencies: use multiple lines for multiple dependencies
module          =

# Other options: config_watcher, spops_file, action_file, message_file

# Add template plugins here: key is name of plugin, value is class
[package template_plugin]

# Register observers here: key is name of observer, value is class
[package observer]


SOMELONGSTRING
}

sub MANIFESTSKIP {
    return <<'SOMELONGSTRING';
\bCVS\b
~$
^oi2_manage\.log$
\.old$
\.bak$
\.backup$
^tmp
^_

SOMELONGSTRING
}

sub SPOPSINI {
    return <<'SOMELONGSTRING';
# spops.ini: define an object to be used by your package

# Define the name by which OI2 uses to lookup this object class
#[[% package_name %]]

# Class to be generated for object.
#class           = OpenInteract2::[% class_name %]

# Add parent classes for generated object
#isa             = 

# field - List of fields/properties of this object. If this is a
# DBI-based object and you specify 'yes' for 'field_discover' below,
# you can leave this blank

#field           = id
#field           = name
#field           = type

# Discover object fields at startup. (Recommended.)
#field_discover  = yes

# Name of primary key field
#id_field        = [% package_name %]_id

# If we should use auto-increment/sequence for IDs
#increment_field = yes

# Name of sequence to use (Oracle, Postgres)
#sequence_name   = [% package_name %]_seq

# If set to 'yes' the object will be protected by security
#is_secure       = yes

# Fields for which we do not insert values. If you're using an
# auto-increment/sequence your ID field should be here.
#no_insert       = [% package_name %]_id

# Fields for which we should never update values.
#no_update       = [% package_name %]_id

# Values will not be inserted/updated if field is undefined.
#skip_undef      =

# Fields that have SQL defaults in the database
#sql_defaults    =

# Name of the table data are stored in. 
#base_table      = [% package_name %]

# Additional names by which you can lookup this object class
#alias           = 

# Field/method name used to generically generate an object's title
#name            =

# Name of this class of objects (e.g., 'News')
#object_name     = [% class_name %]

# Set to 'yes' for automatic full-text indexing.
#is_searchable = no

# If searchable, list all fields to be indexed
#fulltext_field = 


# Define a containing relationship. Key is class of object, value is
# the ID field in your object. So if your object contains a user ID
# field in 'user_id', you'd use 'OpenInteract2::User = user_id'; see
# SPOPS::Manual::Relationships' for details.

#[[% package_name %] has_a]
#OpenInteract2::Theme = theme_id

# Define a relationship between objects from this class and any number
# of other objects

#[[% package_name %] links_to]
#OpenInteract2::Foo = foo_[% package_name %]_link

# Security to apply to newly created objects from this class.
#[[% package_name %] creation_security]
#user  = WRITE
#group = site_admin_group:WRITE
#world = READ

# Specify actions to log
#[[% package_name %] track]
#create = no
#update = yes
#remove = yes

# Every object can report its URL; using ACTION and TASK properly
# localizes the generated URL to your deployment context
#[[% package_name %] display]
#ACTION = [% package_name %]
#TASK   = display


SOMELONGSTRING
}

sub ACTIONINI {
    return <<'SOMELONGSTRING';
# This is a sample action.ini file. Its purpose is to define the
# actions that OpenInteract2 can take based on the URL requested or
# other means. The keys are commented below. (You can of course change
# anything you like. I've only used your package name as a base from
# which to start.)

# '[% package_name %]' - Published name for this action; this is how
# other parts of OI2 find the action. (Will always be lower-case.)

[[% package_name %]]

# class - The class that will execute the action. Can be blank if it's
# a template-only action.

class   = OpenInteract2::Action::[% class_name %]

# Other keys you might want to investigate - 
# see OpenInteract2::Action for more:
#
# task_default: task to assign when none specified in the URL
# is_secure:    whether Check security for this action or not (default: 'no')
# method:       instead of calling arbitrary routines you can direct all requests to one
# action_type:  base for action; OI2 comes with 'template_only' and 'lookup'

SOMELONGSTRING
}

sub SQLINSTALLPM {
    return <<'SOMELONGSTRING';
package OpenInteract2::SQLInstall::[% class_name %];

# Sample of SQL installation class. This uses your package name as the
# base and assumes you want to create a separate table for Oracle
# users and include a sequence for Oracle and PostgreSQL users.

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
   pg      => [ '[% package_name %].sql',
                '[% package_name %]_sequence.sql' ],
   default => [ '[% package_name %].sql' ],
);

sub get_structure_set {
    return '[% package_name %]';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{default};
}

# Uncomment this if you're passing along initial data

#sub get_data_file {
#    return 'initial_data.dat';
#}

# Uncomment this if you're using security

#sub get_security_file {
#    return 'install_security.dat';
#}

1;

SOMELONGSTRING
}

sub ACTIONPM {
    return <<'SOMELONGSTRING';
package OpenInteract2::Action::[% class_name %];

# This is a sample action. It exists only to provide a template for
# you and some notes on what these configuration variables mean.

use strict;

# All actions subclass OI2::Action or one of its subclasses

use base qw( OpenInteract2::Action );

# You almost always use these next three lines -- the first imports
# the logger, the second logging constants, the third the context

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

# Use whatever standard you like here -- it's always nice to let CVS
# deal with it :-)

$OpenInteract2::Action::[% class_name %]::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

# Here's an example of the simplest response...

sub hello {
    my ( $self ) = @_;
    return 'Hello world!';
}


# Here's a more complicated example -- this will just display all the
# content types in the system.

sub list {
    my ( $self ) = @_;

 # This will hold the data you're passing to your template

    my %params = ();

 # Retrieve the class corresponding to the 'content_type' SPOPS
 # object...

    my $type_class = CTX->lookup_object( 'content_type' );
    $params{content_types} = eval { $type_class->fetch_group() };

 # If we've encountered an error in the action, add the error message
 # to it. The template has a component to find the errors encountered
 # and display them

    if ( $@ ) {
        $self->param_add( error_msg => "Failed to fetch content types: $@" );
    }

 # The template also has a component to display a status
 # message. (This is a silly status message, but it's just an
 # example...)

    else {
        my $num_types = scalar @{ $params{content_types} };
        $self->param_add( status_msg => "Fetched $num_types types successfully" );
    }

 # Every action should return content. It can do this by generating
 # content itself or calling another action to do so. Here we're doing
 # it ourselves.

    return $self->generate_content(
                    \%params, { name => '[% package_name %]::sample' } );
}

1;

SOMELONGSTRING
}

sub APPPM {
    return <<'SOMELONGSTRING';
package OpenInteract2::App::[% class_name %];

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::[% class_name %]::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::[% class_name %]::EXPORT  = qw( install );

my $NAME = '[% package_name %]';

sub new {
    return OpenInteract2::App->new( $NAME );
}

sub get_brick {
    require OpenInteract2::Brick;
    return OpenInteract2::Brick->new( $NAME );
}

sub get_brick_name {
    return $NAME;
}

# Not a method, just an exported sub
sub install {
    my ( $website_dir ) = @_;
    my $manage = OpenInteract2::Manage->new( 'install_package' );
    $manage->param( website_dir   => $website_dir );
    $manage->param( package_class => __PACKAGE__ );
    return $manage->execute;
}

OpenInteract2::App->register_factory_type( $NAME => __PACKAGE__ );

1;

__END__

=pod

=head1 NAME

OpenInteract2::App::[% class_name %] - This application will do everything!

[% pod %]

=cut

SOMELONGSTRING
}

sub SAMPLETMPL {
    return <<'SOMELONGSTRING';
[% PROCESS error_message %]
[% PROCESS status_message %]

<h2>Welcome!</h2>

<p>This is a sample template. It consists of normal <a
href="http://www.w3.org/MarkUp/">HTML</a> text with tags plus template
directives like this:

[% IF OI.login %]

 <p>Hello [% OI.login.first_name %], welcome back!</p>

[% ELSE %]
 [%- new_user_url = OI.make_url( ACTION = 'newuser' ) -%]
 <p>Hello, and welcome to our site! You might be interested in 
<a href="[% new_user_url %]">signing up</a> for an account.

[% END %]

[% template_url = OI.make_url( ACTION = 'systemdoc',
                               TASK   = 'display',
                               module = 'OpenInteract2::Manual::Templates' ) %]
<p>See the <a href="[% template_url %]">OpenInteract2 Guide to
Templates</a> for some simple template syntax and a description of the
environment available to template authors.</p>

<h2>Content Types</h2>

<p>If you referenced this template from the generated action you will
probably see a list of content types below:</p>

[% IF content_types.size > 0 %]

<div align="center">

<table border="0">

[% FOREACH content_type = content_types %]
  [% image_url = OI.make_url( BASE  = content_type.image_source,
                              IMAGE = 'yes' ) -%]
  <tr valign="top" align="left">
     <td><img src="[% image_url %]"></td>
     <td>[% content_type.mime_type %]<br>
         [% content_type.description %]</td>
  </tr>
[% END %]

</table>

</div>

[% ELSE %]

<p>Sorry, no content types to see here.</p>

[% END %]

SOMELONGSTRING
}

