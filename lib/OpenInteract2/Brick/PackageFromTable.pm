package OpenInteract2::Brick::PackageFromTable;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'package.ini' => 'PACKAGEINI',
    'MANIFEST.SKIP' => 'MANIFESTSKIP',
    'spops.ini' => 'SPOPSINI',
    'action.ini' => 'ACTIONINI',
    'messages_en.msg' => 'MESSAGES_ENMSG',
    'SQLInstall.pm' => 'SQLINSTALLPM',
    'Action.pm' => 'ACTIONPM',
    'App.pm' => 'APPPM',
    'form.tmpl' => 'FORMTMPL',
    'display.tmpl' => 'DISPLAYTMPL',
    'search_form.tmpl' => 'SEARCH_FORMTMPL',
    'search_results.tmpl' => 'SEARCH_RESULTSTMPL',
);

sub get_name {
    return 'package_from_table';
}

sub get_resources {
    return (
        'package.ini' => [ 'package.ini', 'yes' ],
        'MANIFEST.SKIP' => [ 'MANIFEST.SKIP', 'yes' ],
        'spops.ini' => [ 'conf spops.ini', 'yes' ],
        'action.ini' => [ 'conf action.ini', 'yes' ],
        'messages_en.msg' => [ 'msg/[% package_name %]-messages-en.msg', 'yes' ],
        'SQLInstall.pm' => [ 'OpenInteract2 SQLInstall [% class_name %].pm', 'yes' ],
        'Action.pm' => [ 'OpenInteract2 Action [% class_name %].pm', 'yes' ],
        'App.pm' => [ 'OpenInteract2 App [% class_name %].pm', 'yes' ],
        'form.tmpl' => [ 'template form.tmpl', 'yes' ],
        'display.tmpl' => [ 'template display.tmpl', 'yes' ],
        'search_form.tmpl' => [ 'template search_form.tmpl', 'yes' ],
        'search_results.tmpl' => [ 'template search_results.tmpl', 'yes' ],
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

OpenInteract2::Brick::PackageFromTable - All resources used for creating a package based on a table

=head1 SYNOPSIS

  oi2_manage easy_app --package=books --table=books --dsn=DBI:Pg:dbname=pubs --username=foo --password=bar

=head1 DESCRIPTION

This class just holds all the static resources used when creating a package with basic Create, Update,Delete and Search functionality based on an existing database table.

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

=item B<messages_en.msg>

=item B<SQLInstall.pm>

=item B<Action.pm>

=item B<App.pm>

=item B<form.tmpl>

=item B<display.tmpl>

=item B<search_form.tmpl>

=item B<search_results.tmpl>


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
[[% package_name %]]
class           = OpenInteract2::[% class_name %]
isa             = 
base_table      = [% table %]
field_discover  = yes
field           = 
id_field        = [% key_field %]

# We assume the ID field is auto-incrementable
increment_field = yes

# ...and that we have a sequence associated with it; if you're not
# using Oracle, PostgreSQL, or other sequenced-based systems then you
# can ignore this
sequence_name   = [% table %]_seq

is_secure       = no
no_insert       = [% key_field %]
no_update       = [% key_field %]
skip_undef      =
sql_defaults    =


# Additional names by which you can lookup this object class
#alias           = 

# Set to 'yes' for automatic full-text indexing.
#is_searchable = no

# ...and also list fields to be indexed
#fulltext_field = 

# Field/method name used to generically generate an object's title
name            = [% name_field %]

# Name of this class of objects (e.g., 'News')
object_name     = [% class_name %]

# Datetime fields get auto-converted to DateTime objects
[% FOREACH field = field_info -%]
[% IF field.is_datetime %]convert_date_field = [% field.name %][% END %]
[% END -%]

[[% package_name %] track]
create = yes
update = no
remove = yes

[[% package_name %] display]
ACTION = [% package_name %]
TASK   = display

# Additional information
#

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



SOMELONGSTRING
}

sub ACTIONINI {
    return <<'SOMELONGSTRING';
[[% package_name %]]
class                     = OpenInteract2::Action::[% class_name %]
task_default              = search_form

c_object_type             = [% package_name %]

# Search parameters
c_search_form_template    = [% package_name %]::search_form
[% FOREACH field = fields -%]
[% IF field.is_boolean -%]
c_search_fields_exact     = [% field.name %]
[% ELSIF field.is_text -%]
c_search_fields_like      = [% field.name %]
[% END -%]
[% END -%]
c_search_results_template = [% package_name %]::search_results

# Display parameters
c_display_template        = [% package_name %]::display
c_display_fail_task       = search_form

# Add parameters
c_display_add_template    = [% package_name %]::form
c_add_task                = display
c_add_fail_task           = display_add

[% FOREACH field = fields -%]
[% IF field.is_key; NEXT -%]
[% ELSIF field.is_date -%]
c_add_fields_date         = [% field.name %]
[% ELSIF field.is_boolean -%]
c_add_fields_boolean      = [% field.name %]
[% ELSE -%]
c_add_fields              = [% field.name %]
[% END -%]
[% END -%]

# Update parameters
c_display_form_template   = [% package_name %]::form
c_display_form_fail_task  = search_form
c_update_task             = display
c_update_fail_task        = display_form

[% FOREACH field = fields -%]
[% IF field.is_key; NEXT -%]
[% ELSIF field.is_date -%]
c_update_fields_date      = [% field.name %]
[% ELSIF field.is_boolean -%]
c_update_fields_boolean   = [% field.name %]
[% ELSE -%]
c_update_fields           = [% field.name %]
[% END -%]
[% END -%]

# Remove parameters
c_remove_task             = search_form
c_remove_fail_task        = search_form


SOMELONGSTRING
}

sub MESSAGES_ENMSG {
    return <<'SOMELONGSTRING';
[% package_name %].title_update           = Update the Object
[% package_name %].title_create           = Create a New Object
[% package_name %].title_search_form      = Search for Objects
[% package_name %].title_search_results   = Search Results
[% package_name %].title_display          = Object Details
[% package_name %].no_results             = No results found. <a href="[_1]">Create a new object</a>?

[% FOREACH field = fields -%]
[% package_name %].[% field.name %]_title = [% field.display %]
[% END -%]

SOMELONGSTRING
}

sub SQLINSTALLPM {
    return <<'SOMELONGSTRING';
package OpenInteract2::SQLInstall::[% class_name %];

# Sample of SQL installation class. This uses the given name as the
# base includes a sequence for PostgreSQL users (and Oracle too).

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
   pg      => [ '[% table %].sql',
                '[% table %]_sequence.sql' ],
   default => [ '[% table %].sql' ],
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

use strict;

use base qw(
    OpenInteract2::Action::CommonAdd
    OpenInteract2::Action::CommonDisplay
    OpenInteract2::Action::CommonRemove
    OpenInteract2::Action::CommonSearch
    OpenInteract2::Action::CommonUpdate
);

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

# It's always nice to let CVS deal with this
$OpenInteract2::Action::[% class_name %]::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

########################################
# DISPLAY

# customize what parameters get sent to 'display.tmpl'
# More info: see OpenInteract2::Action::CommonDisplay

sub _display_customize {
    my ( $self, $template_params ) = @_;
}


########################################
# ADD

# customize what parameters get sent to 'form.tmpl' on an add
# More info: see OpenInteract2::Action::CommonAdd

sub _display_add_customize {
    my ( $self, $template_params ) = @_;
}

# customize what occurs when adding an object, including validation
# More info: see OpenInteract2::Action::CommonAdd

sub _add_customize {
    my ( $self, $object, $save_options ) = @_;
}

# perform any actions after the add has occurred
# More info: see OpenInteract2::Action::CommonAdd

sub _add_post_action {
    my ( $self, $object ) = @_;
}


########################################
# UPDATE

# customize what parameters get sent to 'form.tmpl' on an update
# More info: see OpenInteract2::Action::CommonUpdate

sub _display_form_customize {
    my ( $self, $template_params ) = @_;
}

# customize what occurs when updating an object, including validation;
# the hashref $old_data is the object's old data for comparison
# More info: see OpenInteract2::Action::CommonUpdate

sub _update_customize {
    my ( $self, $object, $old_data, $save_options ) = @_;
}

# perform any actions after the add has occurred; the hashref
# $old_data is the object's old data for comparison
# More info: see OpenInteract2::Action::CommonUpdate

sub _update_post_action {
    my ( $self, $object, $old_data ) = @_;
}


########################################
# REMOVE

# perform any actions before the remove has occurred; you'll find the
# object we're about to remove in:
#   $self->param( 'c_object' );
# More info: see OpenInteract2::Action::CommonRemove

sub _remove_customize {
    my ( $self ) = @_;
}


########################################
# SEARCH


# modify template parameters sent to 'search_form.tmpl'
# More info: see OpenInteract2::Action::CommonSearch

sub _search_form_customize {
    my ( $self, $template_params ) = @_;
}

# modify the query criteria before we translate them to SQL
# More info: see OpenInteract2::Action::CommonSearch

sub _search_criteria_customize {
    my ( $self ) = @_;
}

# modify the query pieces before we run the query
# More info: see OpenInteract2::Action::CommonSearch

sub _search_query_customize {
    my ( $self ) = @_;
}

# any parameters you return as a hashref get passed to the final
# SPOPS::DBI->fetch_iterator() call
# More info: see OpenInteract2::Action::CommonSearch

sub _search_additonal_params {
    my ( $self ) = @_;
}

# modify template parameters sent to 'search_results.tmpl'
# More info: see OpenInteract2::Action::CommonSearch

sub _search_customize {
    my ( $self, $template_params ) = @_;
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

$OpenInteract2::App::[% class_name %]::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
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

sub FORMTMPL {
    return <<'SOMELONGSTRING';
[% TAGS star %]
[%-
   is_saved        = object.id;
   title           = ( is_saved )
                       ? MSG( '[* package_name *].title_update' )
                       : MSG( '[* package_name *].title_create' );
   OI.page_title( title );
   DEFAULT theme   = OI.theme_properties;
-%]

[%-
   PROCESS error_message;
   PROCESS status_message;
-%]

<div align="center">

[% task = ( is_saved ) ? 'update' : 'add' -%]
<h2>[% title %]</h2>

[% PROCESS form_begin( ACTION = '[* package_name *]',
                       TASK   = task,
                       method = 'POST',
                       name   = '[* package_name *]_form' ) -%]

[% INCLUDE table_bordered_begin %]
[%- count = 0; valign = 'top' -%]

[* FOREACH field = fields -*]

[*- IF field.name == key_field -*]
[% INCLUDE form_hidden( name = '[* key_field *]', value = object.id ) %]
[*- NEXT; END -*]

[%- count = count + 1 -%]

[*-
   label_key   = "${package_name}.${field.name}_title";
   is_required = field.is_nullable ? 'no' : 'yes';
-*]

[* IF field.is_text OR field.is_number -*]
[% INCLUDE label_form_text_row( label_key   = '[* label_key *]',
                                name        = '[* field.name *]',
                                is_required = '[* is_required *]',
                                value       = object.[* field.name *],
                                size        = 20,  ) -%]

[* ELSIF field.is_date OR field.is_datetime -*]
[% INCLUDE label_form_date_row( label_key    = '[* label_key *]',
                                name         = '[* field.name *]',
                                is_required  = '[* is_required *]',
                                date_object  = object.[* field.name *],
                                is_blank     = 'yes',
                                field_prefix = '[* field.name *]' ); -%]

[* ELSIF field.is_boolean -*]
[% INCLUDE label_form_checkbox_row( label_key   = '[* label_key *]',
                                    name        = '[* field.name *]',
                                    value       = 'TRUE',
                                    is_checked  = OI.as_boolean( object.[* field.name *] ) ) -%]
[* END -*]
[* END -*]

[%- count = count + 1 -%]
[% INCLUDE form_submit_row( value_key = 'global.button.modify' ) %]
  
[% INCLUDE table_bordered_end %]

[% PROCESS form_end %]

</div>

SOMELONGSTRING
}

sub DISPLAYTMPL {
    return <<'SOMELONGSTRING';
[% TAGS star %]
[%-
   title           = MSG( '[* package_name *].title_display' );
   OI.page_title( title );
   date_format     = '%Y-%m-%d';
   datetime_format = '%Y-%m-%d %l:%M %p';
   DEFAULT theme   = OI.theme_properties;
-%]

[%-
   PROCESS error_message;
   PROCESS status_message;
-%]

<div align="center">

[%-
    edit_url   = OI.make_url( ACTION = '[* package_name *]',
                              TASK   = 'display_form',
                              [* key_field *] = object.id );
    remove_url = OI.make_url( ACTION = '[* package_name *]',
                              TASK   = 'remove',
                              [* key_field *] = object.id );
-%]
<p align="right">
   <a href="[% edit_url %]">[% MSG( 'global.label.edit' ) %]</a> |
   <a href="[% remove_url %]">[% MSG( 'global.button.remove' ) %]</a>
</p>

<h2>[% title %]</h2>

[% INCLUDE table_bordered_begin %]
[%- count = 0; valign = 'top' -%]

[* FOREACH field = fields;
     IF field.is_key; NEXT; END -*]
[%-
   count = count + 1;
-%]
[*-
   label_key   = "${package_name}.${field.name}_title";
-*]

[* IF field.is_date -*]
[% INCLUDE label_text_row( label_key = '[* label_key *]',
                           name      = '[* field.name *]',
                           text      = OI.date_format( object.[* field.name *], date_format ), ) -%]
[* ELSIF field.is_datetime -*]
[% INCLUDE label_text_row( label_key = '[* label_key *]',
                           name      = '[* field.name *]',
                           text      = OI.date_format( object.[* field.name *], datetime_format ), ) -%]
[* ELSIF field.is_boolean -*]
[% INCLUDE label_text_row( label_key = '[* label_key *]',
                           name      = '[* field.name *]',
                           text      = OI.as_boolean_label( object.[* field.name *] ) ) -%]
[* ELSE -*]
[% INCLUDE label_text_row( label_key = '[* label_key *]',
                           name      = '[* field.name *]',
                           text      = object.[* field.name *], ) -%]
[* END -*]
[* END -*]

[% INCLUDE table_bordered_end %]

</div>

SOMELONGSTRING
}

sub SEARCH_FORMTMPL {
    return <<'SOMELONGSTRING';
[% TAGS star %]
[%-
   title         = MSG( '[* package_name *].title_search_form' );
   OI.page_title( title );
   DEFAULT theme = OI.theme_properties;
-%]

[%-
   PROCESS error_message;
   PROCESS status_message;
-%]

<div align="center">

[% PROCESS form_begin( ACTION = '[* package_name *]',
                       TASK   = 'search',
                       method = 'GET',
                       name   = 'search_form' ) -%]

<h2>[% title %]</h2>

[% INCLUDE table_bordered_begin %]
[%- count = 0; valign = 'top' -%]

[* FOREACH field = fields -*]
[*-
   label_key   = "${package_name}.${field.name}_title";
-*]
[* IF field.is_boolean -*]
[%- count = count + 1 -%]
[% INCLUDE label_form_checkbox_row( label_key   = '[* label_key *]',
                                    name        = '[* field.name *]',
                                    value       = 'TRUE',
                                    is_picked   = OI.as_boolean( object.[* field.name *] ) ) -%]
[* ELSIF field.is_text -*]
[%- count = count + 1 -%]
[% INCLUDE label_form_text_row( label_key = '[* label_key *]',
                                name      = '[* field.name *]',
                                size      = 20, ) -%]
[* END -*]
[* END -*]

[%- count = count + 1 -%]
[% INCLUDE form_submit_row( value_key = 'global.button.search' ) %]
  
[% INCLUDE table_bordered_end %]

[% PROCESS form_end %]

</div>

SOMELONGSTRING
}

sub SEARCH_RESULTSTMPL {
    return <<'SOMELONGSTRING';
[% TAGS star %]
[%-
   title           = MSG( '[* package_name *].title_search_results' );
   OI.page_title( title );
   date_format     = '%Y-%m-%d';
   datetime_format = '%Y-%m-%d %l:%M %p';
   DEFAULT theme   = OI.theme_properties;
-%]

[%-
   PROCESS error_message;
   PROCESS status_message;
-%]

<div align="center">

<h2>[% title %]</h2>

[% IF iterator AND iterator.has_next -%]


[% INCLUDE table_bordered_begin %]
[%- count = 1; valign = 'top' -%]

[% INCLUDE header_row( label_keys = [
[* FOREACH name = field_names;
    IF name == key_field; NEXT; END; -*]
     '[* package_name *].[* name *]_title',
[* END -*]
     'global.label.nbsp',
] ) -%]

[% WHILE ( object = iterator.get_next );
     row_color  = PROCESS row_color;
     view_url   = OI.make_url( ACTION = '[* package_name *]',
                               TASK   = 'display',
                               [* key_field *] = object.id );
     edit_url   = OI.make_url( ACTION = '[* package_name *]',
                               TASK   = 'display_form',
                               [* key_field *] = object.id );
     remove_url = OI.make_url( ACTION = '[* package_name *]',
                               TASK   = 'remove',
                               [* key_field *] = object.id );
-%]
  <tr [% row_color %]>
[* FOREACH field = fields;
    IF field.name == key_field; NEXT; END; -*]
[* IF field.is_date -*]
    <td>[% OI.date_format( object.[* field.name *], date_format ) %]</td>
[* ELSIF field.is_datetime -*]
    <td>[% OI.date_format( object.[* field.name *], datetime_format ) %]</td>
[* ELSIF field.is_boolean -*]
    <td>[% object.[* field.name *] ? MSG( 'global.label.yes' ) : MSG ( 'global.label.no' ) %]</td>
[* ELSE -*]
    <td>[% object.[* field.name *] %]</td>
[* END -*]
[* END -*]
    <td>
       <a href="[% view_url %]">[% MSG( 'global.label.view' ) %]</a> |
       <a href="[% edit_url %]">[% MSG( 'global.label.edit' ) %]</a> |
       <a href="[% remove_url %]">[% MSG( 'global.button.remove' ) %]</a>
   </td>
  </tr>
  [%- count = count + 1 -%]  
[% END %]

[% INCLUDE table_bordered_end -%]

[% ELSE -%]

[%- new_url = OI.make_url( ACTION = '[* package_name *]',
                           TASK   = 'display_add' ); -%]
<p>[% MSG( '[* package_name *].no_results', new_url ) %]</p>

[% END -%]


SOMELONGSTRING
}

