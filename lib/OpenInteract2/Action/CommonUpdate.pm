package OpenInteract2::Action::CommonUpdate;

# $Id: CommonUpdate.pm,v 1.9 2003/06/24 03:35:38 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::Common );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( SEC_LEVEL_WRITE );

sub display_form {
    my ( $self ) = @_;
    $self->_update_init_param;
    my $log = get_logger( LOG_ACTION );

    my $fail_task = $self->param( 'c_display_form_fail_task' );
    my $object_class = $self->param( 'c_object_class' );
    my $object = $self->param( 'c_object' );
    unless ( $object ) {
        my $id = $self->param( 'c_id' );
        $object = eval { $object_class->fetch( $id ) };
        if ( $@ ) {
            $log->error( "Failed to fetch object [$object_class: $id]: $@" );
            $self->param_add(
                error_msg => "Cannot fetch object for update: $@" );
            return $self->execute( task => $fail_task );
        }
    }

    my $object_type = $self->param( 'c_object_type' );
    my %template_params = ( object       => $object,
                            $object_type => $object );
    $self->_display_form_customize( \%template_params );

    my $template = $self->param( 'c_display_form_template' );
    $self->param( c_object => $object );
    return $self->generate_content(
                    \%template_params, { name => $template } );
}

sub update {
    my ( $self ) = @_;
    $self->_update_init_param;

    my $log = get_logger( LOG_ACTION );
    CTX->response->return_url( $self->param( 'c_update_return_url' ) );
    my $fail_task = $self->param( 'c_update_fail_task' );
    my $object = eval { $self->_common_fetch_object };
    if ( $@ ) {
        return $self->execute({ task => $fail_task });
    }

    unless ( $object and $object->is_saved ) {
        $log->error( "Object does not exist or is not saved, cannot update" );
        my $msg = join( '', "You cannot update this object because it ",
                            "has not yet been saved." );
        $self->param_add( error_msg => $msg );
        return $self->execute({ task => $fail_task });
    }

    # TODO: - assumption: SEC_LEVEL_WRITE is necessary to update. (Probably ok.)

    if ( $object->{tmp_security_level} < SEC_LEVEL_WRITE ) {
        my $sec_fail_task = $self->param( 'c_update_security_fail_task' )
                            || $fail_task;
        my $msg = join( '', 'You do not have sufficient access to ',
                            'update this object. No modifications made.' );
        $self->param_add( error_msg => $msg );
        return $self->execute({ task => $sec_fail_task });
    }

    $self->param( c_object => $object );

    # We pass this to the customization routine so you can do
    # comparisons, set off triggers based on changes, etc.

    my $old_data = $object->as_data_only;

    $self->_common_assign_properties(
        $object,
        { standard        => scalar $self->param( 'c_update_fields' ),
          toggled         => scalar $self->param( 'c_update_fields_toggled' ),
          date            => scalar $self->param( 'c_update_fields_date' ),
          datetime        => scalar $self->param( 'c_update_fields_datetime' ),
          date_format     => scalar $self->param( 'c_update_date_format' ),
          datetime_format => scalar $self->param( 'c_update_datetime_format' ), } );

    my $object_spec = join( '', '[', ref $object, ': ', $object->id, ']' );

    my %save_options = ();
    $self->_update_customize( $object, $old_data, \%save_options );
    eval { $object->save( \%save_options ) };
    if ( $@ ) {
        $log->error( "Update of $object_spec failed: $@" );
        $self->param_add( error_msg => "Object update failed: $@" );
        return $self->execute({ task => $fail_task });
    }
    $self->param( status_msg => 'Object updated with changes' );
    $self->param( c_object_old_data => $old_data );
    $self->_update_post_action;
    my $success_task = $self->param( 'c_update_task' );
    $log->is_debug &&
        $log->debug( "Update ok, executing task [$success_task]" );
    return $self->execute({ task => $success_task });
}

my %DEFAULTS = (
    c_display_form_fail_task => 'common_error',
    c_update_fail_task       => 'display_form',
    c_update_task            => 'display_form',
);

sub _update_init_param {
    my ( $self ) = @_;
    $self->_common_set_defaults(
          { %DEFAULTS,
            c_update_return_url => $self->create_url({ TASK => undef }) });

    my $has_error = $self->_common_check_object_class;
    $has_error += $self->_common_check_id_field;
    $has_error += $self->_common_check_id;
    $has_error +=
        $self->_common_check_template_specified( 'c_display_form_template' );
    if ( $has_error ) {
        die $self->execute({ task => 'common_error' });
    }
}

########################################
# OVERRIDABLE

sub _display_form_customize { return undef }
sub _update_customize       { return undef }
sub _update_post_action     { return undef }

1;

__END__

=head1 NAME

OpenInteract2::Action::CommonUpdate - Task to update an object

=head1 SYNOPSIS

 # Just subclass and the task 'update' is implemented
 
 package OpenInteract2::Action::MyAction;
 
 use base qw( OpenInteract2::Action::CommonUpdate );

=head1 SUPPORTED TASKS

This common action support two tasks:

B<display_form>

Displays the filled-in form to edit an object.

B<update>

Read in field values for an object, apply them to an already existing
object and save the object with the new values.

=head1 DESCRIPTION FOR 'display_form'

This takes the object type and an ID passed in, fetches the
appropriate object and passes the object to a template which
presumably displays its data in a form.

=head1 TEMPLATES USED FOR 'display_form'

B<c_display_form_template>

Template used for editing the object. It will receive the object in
the keys 'object' and '$object_type'.

It's fairly common to use the same template as when creating a new
object.

=head1 METHODS FOR 'display_form'

B<_display_form_customize( \%template_params )>

Add any necessary parameters to C<\%template_params> before the
content generation step where they get passed to the template
specified in C<c_display_form_template>.

=head1 CONFIGURATION FOR 'display_form'

=head2 Basic

B<c_object_type> ($) (REQUIRED)

SPOPS key for object you'll be displaying.

B<c_display_form_fail_task> ($)

If we cannot fetch the necessary object this task is run.

Default: 'common_error'

=head2 System-created parameters

B<c_object_class>

See L<OpenInteract2::Common/_common_check_object_class>

B<c_id_field>

See L<OpenInteract2::Common/_common_check_id_field>

B<c_id> ($)

The ID of the object we've fetched for update.

B<c_object> ($)

The object we've fetched for update.

=head1 DESCRIPTION FOR 'update'

Takes request data, including the object ID, fetches the object and if
the fetch is successful sets the request data as the object properties
and tries to save it.

=head1 TEMPLATES USED FOR 'update'

None

=head1 METHODS FOR 'update'

B<_update_customize( $object, \%old_data, \%save_options )>

You can make any necessary customizations to C<$object> before it's
updated. You even have access to its previous values in the
C<\%old_data> mapping.

If you've encountered an error condition return the necessary
content. The update will not happen and the user will see whatever
you've generated.

You can also specify keys and values in C<\%save_options> which get
passed along to the C<save()> call.

B<_update_post_action>

This method is called after the object has been successfully updated
-- you'll find the object in the C<c_object> action parameter. You can
perform any action you like after this. If you return content it will
be displayed to the user rather than the configured C<c_update_task>.

=head1 CONFIGURATION FOR 'update'

=head2 Basic

B<c_update_fail_task> ($)

Task to execute on failure.

Default: 'display_form'

B<c_update_security_fail_task> ($)

Task to update on the specific failure of insufficient security. If
this is not defined we'll just use C<c_update_fail_task>.

B<c_update_task> ($)

Task to execute when the update succeeds.

Default: 'display_form'

B<c_update_return_url>

What I should set the 'return URL' to. This is used for links like
'Login/Logout' where you perform an action and the system brings you
back to a particular location. You don't want to come back to the
'.../update/' URL.

Default: the URL formed by the default task for the current action.

=head2 Object fields to assign

B<c_update_fields> ($ or \@)

List the fields you just want assigned directly from the name. So if a
form variable is named 'first_name' and you list 'first_name' here
we'll assign that value to the object property 'first_name'.

B<c_update_fields_toggled> ($ or \@)

List the fields you want assigned in a toggled fashion -- if any value
is specified, we set it to 'yes'; otherwise we set it to 'no'. (See
L<OpenInteract2::Request/param_toggled>.)

B<c_update_fields_date> ($ or \@)

List the date fields you want assigned. You can have the date read
from a single field, in which case you should also specify a
C<strptime> format in C<c_update_fields_date_format>, or multiple fields
as created by the C<date_select> OI2 control. (See
L<OpenInteract2::Request/param_date>.)

B<c_update_fields_datetime> ($ or \@)

List the datetime fields you want assigned. These are just like date
fields except they also have a time component. You can have the date
and time read from a single field, in which case you should also
specify a C<strptime> format in C<c_update_fields_date_format>, or
multiple fields. (See L<OpenInteract2::Request/param_datetime>.)

B<c_update_fields_date_format> ($)

If you list one or more fields in C<c_update_fields_date> and they're
pulled from a single field, you need to let OI2 know how to parse the
date. Just specify a C<strptime> format as specified in
L<DateTime::Format::Strptime|DateTime::Format::Strptime>.

B<c_update_fields_datetime_format> ($)

If you list one or more fields in C<c_update_fields_datetime> and
they're pulled from a single field, you need to let OI2 know how to
parse the date and time. Just specify a C<strptime> format as
specified in L<DateTime::Format::Strptime|DateTime::Format::Strptime>.

=head2 System-created parameters

B<c_object_class>

See L<OpenInteract2::Common/_common_check_object_class>

B<c_id_field>

See L<OpenInteract2::Common/_common_check_id_field>

B<c_id> ($)

The ID of the object we're trying to update.

B<c_object> ($)

If we're able to fetch an object to update this will be set. Whether
the update succeeds or fails the object should represent the state of
the object in the database.

B<c_object_old_data> (\%)

If the update is successful we set this to the hashref of the previous
record's data.

=head1 COPYRIGHT

Copyright (c) 2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
