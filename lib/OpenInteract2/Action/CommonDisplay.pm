package OpenInteract2::Action::CommonDisplay;

# $Id: CommonDisplay.pm,v 1.6 2003/06/11 02:43:31 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action::Common );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );

sub display {
    my ( $self ) = @_;
    $self->_display_init_param;

    my $fail_task = $self->param( 'c_display_fail_task' );
    my $object = eval { $self->_common_fetch_object };
    if ( $@ ) {
        return $self->execute({ task => $fail_task });
    }
    unless ( $object->is_saved ) {
        my $id = $self->param( 'c_id' );
        $self->param_add( error_msg => "Object with ID $id not found" );
        return $self->execute({ task => $fail_task });
    }

    # TODO: It would be nice to replace this with a '$object->is_active' ...

    if ( my $active_field = $self->param( 'c_display_active_field' ) ) {
        my $status = $object->$active_field();
        unless ( $status =~ /^\s*(y|yes|1|true)\s*$/i ) {
            my $object_class = $self->param( 'c_object_class' );
            my $id           = $self->param( 'c_id' );
            DEBUG && LOG( LINFO, "Object [$object_class] [$id] failed ",
                                 "'active' check [Status: $status]" );
            $self->param_add( error_msg => "This object is currently " .
                                           "inactive. Please check later." );
            return $self->execute({ task => $fail_task });
        }
        DEBUG && LOG( LDEBUG, "Object passed 'active' check" );
    }

    # Set both 'object' and the object type equal to the object so the
    # template can use either.

    my $object_type = $self->param( 'c_object_type' );
    my %params = ( object       => $object,
                   $object_type => $object );

    $self->_display_customize( \%params );

    my $display_template = $self->param( 'c_display_template' );
    return $self->generate_content(
                    \%params, { name => $display_template } );
}

my %DEFAULTS = (
    c_display_fail_task => 'common_error',
);

sub _display_init_param {
    my ( $self ) = @_;
    $self->_common_set_defaults( \%DEFAULTS );

    my $has_error = $self->_common_check_object_class;
    $has_error += $self->_common_check_id_field;
    $has_error += $self->_common_check_id;
    $has_error +=
        $self->_common_check_template_specified( 'c_display_template' );
    if ( $has_error ) {
        die $self->execute({ task => 'common_error' });
    }
}

########################################
# OVERRIDABLE

sub _display_customize { return undef }

1;

=head1 NAME

OpenInteract2::Action::CommonDisplay - Task to display an object

=head1 SYNOPSIS

 # Just subclass and the task 'display' is implemented
 
 package OpenInteract2::Action::MyAction;
 
 use base qw( OpenInteract2::Action::CommonDisplay );

=head1 SUPPORTED TASKS

This common action supports the following tasks:

B<display> - Display a non-editable object.

=head1 DESCRIPTION FOR 'display'

The 'display' task simply retrieves a specified object and sends it to
a template. If the object checks its active status we first do that,
but we don't really do too much.

=head1 TEMPLATES USED FOR 'display'

B<c_display_template> (no default)

This it the template we send the object to. The same object can be
found in two keys: 'object' and whatever you've set C<c_object_type>
to. So a handler manipulating 'doodad' objects will find the specified
doodad in 'object' and 'doodad'.

=head1 METHODS FOR 'display'

C<_display_customize( \%template_params )>

Called just before we generate the content. You can add parameters to
C<\%template_params> so your template will see them.

=head1 CONFIGURATION FOR 'display'

These are in addition to the template parameters defined above.

=head2 Basic

B<c_object_type> ($) (REQUIRED)

SPOPS key for object you'll be displaying.

B<c_display_fail_task> ($)

Task to run if we fail to fetch the object.

Default: 'common_error'

C<c_display_active_field> ($)

If your object has a field indicating whether the object is active,
specify it here. If specified we check the object for true values
('y', 'yes', '1', 'true') -- if none match, we pass control to the
C<c_display_fail_task>.

=head2 System-created parameters

B<c_object_class> ($)

SPOPS object class derived from C<c_object_type>.

C<c_id_field> ($)

ID field found from C<c_object_class>.

C<c_id> ($)

ID value used to fetch the object.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
