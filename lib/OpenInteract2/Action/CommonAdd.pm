package OpenInteract2::Action::CommonAdd;

# $Id: CommonAdd.pm,v 1.8 2003/06/11 02:43:31 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::Common );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use SPOPS::Secure            qw( SEC_LEVEL_WRITE );

sub display_add {
    my ( $self ) = @_;
    $self->_add_init_param;
    my $object_class = $self->param( 'c_object_class' );

    # We take 'object' as a parameter in case 'add' bombs

    my $object = $self->param( 'c_object' );
    unless ( $object ) {
        $object = $self->param( c_object => $object_class->new );
    }

    my $object_type = $self->param( 'c_object_type' );
    my %template_params = ( object       => $object,
                            $object_type => $object );
    $self->_display_add_customize( \%template_params );

    my $template = $self->param( 'c_display_add_template' );
    return $self->generate_content(
                    \%template_params, { name => $template } );
}

sub add {
    my ( $self ) = @_;
    $self->_add_init_param;
    CTX->response->return_url( $self->param( 'c_add_return_url' ) );

    my $object_class = $self->param( 'c_object_class' );
    my $object = $self->param( 'c_object' ) || $object_class->new;

    # we don't want any parameter value hanging around just in case
    # the save fails...

    $self->param_clear( 'c_object' );

    # Assign values from the form (specified by MY_EDIT_FIELDS,
    # MY_EDIT_FIELDS_DATE, MY_EDIT_FIELDS_TOGGLED, ...)

    $self->_common_assign_properties(
        $object,
        { standard        => scalar $self->param( 'c_add_fields' ),
          toggled         => scalar $self->param( 'c_add_fields_toggled' ),
          date            => scalar $self->param( 'c_add_fields_date' ),
          datetime        => scalar $self->param( 'c_add_fields_datetime' ),
          date_format     => scalar $self->param( 'c_add_date_format' ),
          datetime_format => scalar $self->param( 'c_add_datetime_format' ), } );

    # If after customizing/inspecting the object you want to bail and
    # go somewhere else, return content

    my %save_options = ();
    $self->_add_customize( $object, \%save_options );

    eval { $object->save( \%save_options ) };
    if ( $@ ) {
        LOG( LERROR, "Failed to create object: $@" );
        $self->param_add( error_msg => "Object creation failed: $@" );
        my $fail_task = $self->param( 'c_add_fail_task' );
        return $self->execute({ task => $fail_task });
    }
    $self->param( c_object => $object );
    $self->param( status_msg => 'Object created properly' );
    $self->_add_post_action;
    $self->param( c_id => scalar $object->id );
    my $success_task = $self->param( 'c_add_task' );
    return $self->execute({ task => $success_task });
}

my %DEFAULTS = (
    c_add_fail_task => 'display_add',
);

sub _add_init_param {
    my ( $self ) = @_;
    $self->_common_set_defaults({
          %DEFAULTS,
          c_add_return_url => $self->create_url({ TASK => undef }),
    });

    my $has_error = $self->_common_check_object_class;
    $has_error   +=
        $self->_common_check_template_specified( 'c_display_add_template' );
    $has_error   += $self->_common_check_param( 'c_add_task' );
    if ( $has_error ) {
        die $self->execute({ task => 'common_error' });
    }
}

########################################
# OVERRIDABLE

sub _display_add_customize { return undef }
sub _add_customize         { return undef }
sub _add_post_action       { return undef }

1;

__END__

=head1 NAME

OpenInteract2::Action::CommonAdd - Tasks to display empty form and create an object

=head1 SYNOPSIS

 # Just subclass and the tasks 'display_add' and 'add' are implemented
 
 package OpenInteract2::Action::MyAction;
 
 use base qw( OpenInteract2::Action::CommonAdd );

=head1 SUPPORTED TASKS

This common action supports the following tasks:

B<display_add> - Display a form to create a new object.

B<add> - Add the new object.

=head1 DESCRIPTION FOR 'display_add'

Displays a possibly empty form to create a new object. The 'possibly'
derives from your ability to pre-populate the object with default data
so the user can do less typing. Because it's all about the users...

=head1 TEMPLATES USED FOR 'display_add'

B<c_display_add_template>: Template with a form for the user to fill
in with values to create a new object.

The template gets an unsaved (likely empty) object in the keys
'object' and '$object_type'.

=head1 METHODS FOR 'display_add'

B<_display_add_customize( \%template_params )>

Called just before the content is generated, giving you the ability to
modify the likely empty object to display or to add more parameters.

=head1 CONFIGURATION FOR 'display_add'

These are in addition to the template parameters defined above.

=head2 Basic

B<c_object_type> ($) (REQUIRED)

SPOPS key for object you'll be displaying.

=head2 System-created

B<c_object> ($)

System will create a new instance of the object type if not previously
set.

B<c_object_class> ($)

Set to the class corresponding to C<c_object_type>. This has already
been validated.

=head1 DESCRIPTION FOR 'add'

Takes data from a form and creates a new object from it.

=head1 TEMPLATES USED FOR 'add'

None

=head1 METHODS FOR 'add'

B<_add_customize( $object, \%save_options )>

Called just before the C<save()> operation which creates the object in
your datastore. You have two opportunities to affect the operation:

=over 4

=item *

Return content from the method. This content will be sent on to the
user. This gives you an opportunity to do any necessary validation,
quota ceiling inspections, time of day checking, etc.

=item *

Modify the options passed to C<save()> by setting values in
C<\%save_options>.

=back

Here's an example of a validation check:

 sub _add_customize {
     my ( $self, $object, $save_options ) = @_;
     if ( $self->widget_type eq 'Frobozz' and $self->size ne 'Large' ) {

         # First set an error message to tell the user what's wrong...

         $self->param_add(
             error_msg => "Only large widgets of type Frobozz are allowed' );

         # Next, provide the object with its values to the form so we
         # can prepopulate it...

         $self->param( c_object => $object );

         # ...and display the editing form again

         return $self->execute( task => 'display_add' );
     }
 }

B<_add_post_action>

This method is called after the object has been successfully created
-- you'll find the object in the C<c_object> action parameter. You can
perform any action you like after this. If you return content it will
be displayed to the user rather than the configured C<c_add_task>.

=head1 CONFIGURATION FOR 'add'

=head2 Basic

B<c_object_type> ($) (REQUIRED)

SPOPS key for object you'll be displaying.

B<c_add_task> ($) (REQUIRED)

Task executed when the add is successful.

B<c_add_fail_task> ($)

Task to run if we fail to fetch the object.

Default: 'display_add'

B<c_add_return_url> ($)

Path we use for returning. (For example, if someone logs in on the resulting page.)

Default: the default task for this action

=head2 Object fields to assign

These configuration keys control what data will be read from the HTTP
request into your object, and in some cases how it will be read.

B<c_add_fields> ($ or \@)

List the fields you just want assigned directly from the name. So if a
form variable is named 'first_name' and you list 'first_name' here
we'll assign that value to the object property 'first_name'.

B<c_add_fields_toggled> ($ or \@)

List the fields you want assigned in a toggled fashion -- if any value
is specified, we set it to 'yes'; otherwise we set it to 'no'. (See
L<OpenInteract2::Request/param_toggled>.)

B<c_add_fields_date> ($ or \@)

List the date fields you want assigned. You can have the date read
from a single field, in which case you should also specify a
C<strptime> format in C<c_add_fields_date_format>, or multiple fields
as created by the C<date_select> OI2 control. (See
L<OpenInteract2::Request/param_date>.)

B<c_add_fields_datetime> ($ or \@)

List the datetime fields you want assigned. These are just like date
fields except they also have a time component. You can have the date
and time read from a single field, in which case you should also
specify a C<strptime> format in C<c_add_fields_date_format>, or
multiple fields. (See L<OpenInteract2::Request/param_datetime>.)

B<c_add_fields_date_format> ($)

If you list one or more fields in C<c_add_fields_date> and they're
pulled from a single field, you need to let OI2 know how to parse the
date. Just specify a C<strptime> format as specified in
L<DateTime::Format::Strptime|DateTime::Format::Strptime>.

B<c_add_fields_datetime_format> ($)

If you list one or more fields in C<c_add_fields_datetime> and they're
pulled from a single field, you need to let OI2 know how to parse the
date and time. Just specify a C<strptime> format as specified in
L<DateTime::Format::Strptime|DateTime::Format::Strptime>.

=head2 System-created parameters

B<c_object> ($)

If the add is successful this will be set to the newly-created object.

B<c_object_class> ($)

Set to the class corresponding to C<c_object_type>. This has already
been validated.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
