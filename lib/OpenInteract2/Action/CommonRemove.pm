package OpenInteract2::Action::CommonRemove;

# $Id: CommonRemove.pm,v 1.7 2003/06/25 14:11:57 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::Common );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use SPOPS::Secure            qw( SEC_LEVEL_WRITE );

sub remove {
    my ( $self ) = @_;
    $self->_remove_init_param;
    my $log = get_logger( LOG_ACTION );

    my $fail_task = $self->param( 'c_remove_fail_task' );
    my $object = eval { $self->fetch_object };
    if ( $@ ) {
        return $self->execute({ task => $fail_task });
    }
    unless ( $object and $object->is_saved ) {
        $self->param_add( error_msg => 'Cannot fetch object for removal. ' .
                                       'No modifications made.' );
        return $self->execute({ task => $fail_task });
    }

    $self->param( c_object => $object );

    # TODO: - assumption: SEC_LEVEL_WRITE is necessary to remove. (Probably ok.)

    if ( $object->{tmp_security_level} < SEC_LEVEL_WRITE ) {
        my $sec_fail_task = $self->param( 'c_remove_security_fail_task' )
                            || $fail_task;
        $self->param_add(
            error_msg => 'Insufficient access rights to remove this ' .
                         'object. No modifications made.' );
        return $self->execute({ task => $sec_fail_task });
    }

    my $bail_content = $self->_remove_customize;
    return $bail_content if ( $bail_content );

    eval { $object->remove };
    if ( $@ ) {
        $self->param_add( error_msg => "Object removal failed: $@" );
        $log->error( "Failed to remove ", $self->param( 'c_object_class' ),
                     "with ID" , $object->id, ": $@" );
        return $self->execute({ task => $fail_task });
    }

    $self->param_add( status_msg => 'Object successfully removed.' );
    my $success_task = $self->param( 'c_remove_task' );
    return $self->execute({ task => $success_task });
}

my %DEFAULTS = (
    c_remove_fail_task       => 'common_error',
);

sub _remove_init_param {
    my ( $self ) = @_;
    $self->_common_set_defaults( \%DEFAULTS );

    my $has_error = $self->_common_check_object_class;
    $has_error += $self->_common_check_id_field;
    $has_error += $self->_common_check_id;
    $has_error += $self->_common_check_param(
                      qw( c_remove_fail_task c_remove_task )
    );
    if ( $has_error ) {
        die $self->execute({ task => 'common_error' });
    }
}

########################################
# OVERRIDABLE

sub _remove_customize { return undef }

1;

=head1 NAME

OpenInteract2::Action::CommonRemove - Task to remove an object

=head1 SYNOPSIS

 # Just subclass and the task 'remove' is implemented
 
 package OpenInteract2::Action::MyAction;
 
 use base qw( OpenInteract2::Action::CommonRemove );
 
 # In your action configuration:
 
 [myaction]

=head1 SUPPORTED TASKS

This common action supports a single task:

=over 4

=item B<remove>

Removes a single object.

=back

=head1 DESCRIPTION FOR 'remove'

Very straightforward -- we just remove an object given an ID.

=head1 TEMPLATES USED FOR 'remove'

None.

=head1 METHODS FOR 'remove'

B<_remove_customize>

Called before the object removal. You can record the object being
removed (found in the action parameter C<c_object>) or any other
action you like.

This method is different from the other common C<_*_customize> methods
in that you can short-circuit the operation. If you return content
from this method the object will not be removed and the content
displayed.

=head1 CONFIGURATION FOR 'remove'

=head2 Basic

B<c_object_type> ($)

See L<OpenInteract2::Common|OpenInteract2::Common>

B<c_remove_fail_task> ($)

This is the task called when some part of the remove process
fails. For instance, if we cannot fetch the object requested to be
removed, or if there is a misconfiguration.

Default: 'common_error'

B<c_remove_security_fail_task> ($)

Optional task for the specific failure of security. It will be called
when the user does not have sufficient access to remove the object.

If not defined we use the value of C<c_remove_fail_task>.

B<c_remove_task> ($) (REQUIRED)

Task to be called when the remove succeeds. The object removed is
available in the C<c_object> action parameter.

=head2 System-created parameters

B<c_object_class>

See L<OpenInteract2::Common|OpenInteract2::Common>

B<c_id_field>

See L<OpenInteract2::Common|OpenInteract2::Common>

B<c_id>

The ID of the object we're trying to remove.

B<c_object>

Set to the object to be/that was removed. This will be set in all
cases except if the requested object is not found.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
