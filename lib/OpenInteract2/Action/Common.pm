package OpenInteract2::Action::Common;

# $Id: Common.pm,v 1.11 2003/06/26 14:11:02 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_security_error );

$OpenInteract2::Action::Common::VERSION   = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);
$OpenInteract2::Action::Common::AUTOLOAD  = '';

my %COMMON_TASKS = (
  search_form  => q{Capability to display a search form is not built into action '%s'.},
  search       => q{Search capability is not built into action '%s'.},
  display      => q{Display capability is not built into action '%s'.},
  display_new  => q{Capability to display a form for a new record is not built into action '%s'.},
  add          => q{Add capability is not built into action '%s'.},
  display_form => q{Capability to display a form for an existing record is not built into action '%s'.},
  update       => q{Update capability is not built into action '%s'.},
  remove       => q{Remove capability is not built into action '%s'.},
);

# TODO: We should probably have the messages be put into a template,
# or the template have the entire message...

sub AUTOLOAD {
    my ( $self ) = @_;
    my $request = $OpenInteract2::Action::Common::AUTOLOAD;
    $request =~ s/.*://;
    my $log = get_logger( LOG_ACTION );

    if ( my $msg = $COMMON_TASKS{ $request } ) {
        return sprintf( $msg, $self->name );
    }
    elsif ( $request =~ /^_/ ) {
        my $msg = sprintf( "Private function '%s' not found in action %s.",
                           $request, $self->name );
        $log->warn( $msg );
        return $msg;
    }
    else {
        my $msg = sprintf( "Task '%s' not available in action %s",
                           $request, $self->name );
        # cut down on noise in log messages...
        if ( $request eq 'DESTROY' ) {
            $log->is_debug && $log->debug( $msg );
        }
        else {
            $log->warn( $msg );
        }
        return $msg
    }
}

sub common_error {
    my ( $self ) = @_;
    my $error_template = $self->_common_error_template;
    return $self->generate_content(
                    {}, { name => $error_template } );
}

sub _common_error_template {
    return 'common_action_error';
}

sub _common_set_defaults {
    my ( $self, $defaults ) = @_;
    return unless ( ref $defaults eq 'HASH' );
    my $log = get_logger( LOG_ACTION );
    my $tag = join( ' -> ', $self->name, $self->task );
    while ( my ( $key, $value ) = each %{ $defaults } ) {
        if ( $self->param( $key ) ) {
            $log->is_debug &&
                $log->debug( "NOT settting default for [$tag]: [$key], value ",
                             "already exists [", $self->param( $key ), "]" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Setting default for [$tag]: [$key] [$value]" );
            $self->param( $key, $value );
        }
    }
    return;
}

########################################
# CHECKS

sub _common_check_object_class {
    my ( $self ) = @_;
    my $object_type = $self->param( 'c_object_type' );
    my $log = get_logger( LOG_ACTION );
    unless ( $object_type ) {
        $log->warn( "No object type specified" );
        my $msg = join( '', "Object type is undefined. How can we know ",
                            "what to search or return? Please set it in ",
                            "your action configuration using the key ",
                            "c_object_type." );
        $self->param_add( error_msg => $msg );
        return 1;
    }
    my $object_class = eval { CTX->lookup_object( $object_type ) };
    if ( $@ or ! $object_class ) {
        $log->warn( "No object class for [$object_type]" );
        my $msg = join( '', "Class for given object type '$object_type' ",
                            "is undefined. Maybe a typo in your action ",
                            "configuration using the key c_object_type." );
        $self->param_add( error_msg => $msg );
        return 1;
    }
    $self->param( c_object_class => $object_class );
    return 0;
}

sub _common_check_id_field {
    my ( $self ) = @_;
    my $log = get_logger( LOG_ACTION );

    my $object_class = $self->param( 'c_object_class' );
    my $id_field = eval { $object_class->id_field };
    if ( ! $id_field or $@ ) {
        $log->warn( "No ID field for [$object_class]" );
        my $msg = join( '', "Object ID field is undefined. We cannot know ",
                            "how to fetch an existing object without it. ",
                            "Please define the key 'id_field' in your ",
                            "object configuration." );
        $self->param_add( error_msg => $msg );
        return 1;
    }
    $self->param( c_id_field => $id_field );
    return 0;
}

sub _common_check_id {
    my ( $self ) = @_;
    my $log = get_logger( LOG_ACTION );

    my $id_field = $self->param( 'c_id_field' );
    my $id = $self->param( 'c_id' );
    if ( ! defined $id and $id_field ) {
        $id = $self->param( $id_field )
              || CTX->request->param( $id_field )
              || CTX->request->param( 'id' );
    }
    if ( $id ) {
        $self->param( c_id => $id );
    }
    else {
        $log->warn( "No ID found in action/request [$id_field]" );
        my $msg = join( '', "No value found in action parameters or ",
                            "request for ID field [$id_field]." );
        $self->param_add( error_msg => $msg );
        return 1;
    }
    return 0;
}

sub _common_check_template_specified {
    my ( $self, @template_params ) = @_;
    my $log = get_logger( LOG_ACTION );

    my $num_errors = 0;
    for ( @template_params ) {
        next unless ( $_ );
        unless ( $self->param( $_ ) ) {
            $log->warn( "No value in template parameter [$_]" );
            my $msg = join( '', "No template found in '$_' key. This " .
                                "template is mandatory for the task to ",
                                "function." );
            $self->param_add( error_msg => $msg );
            $num_errors++;
        }
    }
    return $num_errors;
}

sub _common_check_param {
    my ( $self, @params ) = @_;
    my $log = get_logger( LOG_ACTION );

    my $num_errors = 0;
    for ( @params ) {
        unless ( $self->param( $_ ) ) {
            $log->warn( "No value in parameter [$_]" );
            my $msg = join( '', "Action parameter '$_' is undefined but ",
                                "required for the task to function." );
            $self->param_add( error_msg => $msg );
            $num_errors++;
        }
    }
    return $num_errors;
}

########################################
# ASSIGN FIELDS

sub _common_assign_properties {
    my ( $self, $object, $fields ) = @_;
    my $request = CTX->request;

    my $log = get_logger( LOG_ACTION );
    my @standard = ( ref $fields->{standard} eq 'ARRAY' )
                     ? @{ $fields->{standard} } : ( $fields->{standard} );
    foreach my $field ( @standard ) {
        next unless ( $field );
        $log->is_debug &&
            $log->debug( "Setting standard [$field] in object from request" );
        eval { $object->{ $field } = $request->param( $field ) };
        if ( $@ ) {
            $log->warn( "Failed to set object value for [$field]: $@" );
        }
    }

    my @toggled = ( ref $fields->{toggled} eq 'ARRAY' )
                     ? @{ $fields->{toggled} } : ( $fields->{toggled} );
    foreach my $field ( @toggled ) {
        next unless ( $field );
        $log->is_debug &&
            $log->debug( "Setting toggled [$field] in object from request" );
        eval { $object->{ $field } = $request->param_toggled( $field ) };
        if ( $@ ) {
            $log->warn( "Failed to set object toggle for [$field]: $@" );
        }
    }

    my @date = ( ref $fields->{date} eq 'ARRAY' )
                     ? @{ $fields->{date} } : ( $fields->{date} );
    foreach my $field ( @date ) {
        next unless ( $field );
        $log->is_debug &&
            $log->debug( "Setting date [$field] in object from request" );
        eval {
            $object->{ $field }= $request->param_date(
                                       $field, $fields->{date_format} )
        };
        if ( $@ ) {
            $log->warn( "Failed to set object date for [$field]: $@" );
        }
    }

    my @datetime = ( ref $fields->{datetime} eq 'ARRAY' )
                     ? @{ $fields->{datetime} } : ( $fields->{datetime} );
    foreach my $field ( @datetime ) {
        next unless ( $field );
        $log->is_debug &&
            $log->debug( "Setting datetime [$field] in object from request" );
        eval {
            $object->{ $field } = $request->param_datetime(
                                       $field, $fields->{datetime_format} )
        };
        if ( $@ ) {
            $log->warn( "Failed to set object datetime for [$field]: $@" );
        }
    }
    return $object;
}


########################################
# FETCH

sub _common_fetch_object {
    my ( $self, $id ) = @_;
    my $log = get_logger( LOG_ACTION );

    my $object_class = $self->param( 'c_object_class' );
    $id ||= $self->param( 'c_id' );
    unless ( $id ) {
        $log->is_info &&
            $log->info( "No ID found, returning new object" );
        return $object_class->new;
    }
    $log->is_debug &&
        $log->debug( "Trying to fetch [$object_class: $id]" );
    my $object = eval { $object_class->fetch( $id ) };
    if ( $@ ) {
        my $error = $@;
        $log->error( "Caught exception fetching object: $@" );
        if ( $error->isa( 'SPOPS::Exception::Security' ) ) {
            my $msg = "Security violation: you do not have rights to " .
                      "retrieve the requested object.";
            $self->param_add( error_msg => $msg );
            oi_error $@;
        }
        else {
            $self->param_add( error_msg => "Cannot retrieve object: $@" );
            oi_error $error;
        }
    }
    return $object || $object_class->new;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::Common - Base class for common functionality

=head1 SYNOPSIS

 package OpenInteract2::Action::CommonSearch;
 
 use base qw( OpenInteract2::Action::Common );

=head1 DESCRIPTION

This class is a subclass of
L<OpenInteract2::Action|OpenInteract2::Action> and for now mostly
provides placeholder methods to signal that an action does not
implement certain common methods. It also has a few common functions
as well. All common actions should subclass this class so that any
inadvertent calls to other common methods get caught and a decent (if
terse) message is returned. For instance, say I did this:

 package OpenInteract2::Action::MyAction;
 
 use strict;
 use base qw( OpenInteract2::Action::CommonSearch );

and in my search results template I had:

 <p>Your search results:</p>
 
 <ul>
 [% FOREACH record = records;
        display_url = OI.action.create_url( TASK = 'display',
                                            my_id = record.id ); %]
     <li><a href="[% display_url %]">[% record.title %]</li>
 [% END %]
 </ul>

Since I haven't inherited a 'display' task or defined one myself, when
I click on the created link I can expect an ugly error message from
the dispatcher telling me that the task does not exist. Instead, I'll
get something like:

 Display capability is not built into action 'foo'.

It also leaves us an option for locating future common functionality.

=head1 METHODS

=head2 Fetching Objects

B<_common_fetch_object( [ $id ] )>

Fetches an object of the type defined in the C<c_object_type>
parameter. If an ID value is not passed in it looks for the ID using
the same algorithm found in C<_common_check_id> -- so you should run
that methods in your task initialization before calling this.

Returns: This method returns an object or throws an exception. If we
encounter an error while fetching the object we add to the action
parameter 'error_msg' stating the error and wrap the error in the
appropriate L<OpenInteract2::Exception|OpenInteract2::Exception>
object and rethrow it. Appropriate: if we cannot fetch an object due
to security we throw an
L<OpenInteract2::Exception::Security|OpenInteract2::Exception::Security>
exception.

If an object is not retrieved due to an ID value not being found or a
matching object not being found, a B<new> (empty) object is returned.

=head2 Setting object properties

B<_common_assign_properties( $object, \%field_info )>

Assign values from HTTP request into C<$object> as declared by
C<\%field_info>. The data in C<\%field_info> tells us the names and
types of data we'll be setting in the object. You can learn more about
the different types of parameters we're reading in the various
C<param_*> methods in
L<OpenInteract2::Request|OpenInteract2::Request>.

=over 4

=item *

B<standard> ($ or \@)

Fields that get copied as-is from the request data. (See L<OpenInteract2::Request/param>.)

=item *

B<toggled> ($ or \@)

Fields that get set to 'yes' if any data passed for the field, 'no'
otherwise. (See L<OpenInteract2::Request/param_toggled>.)

=item *

B<date> ($ or \@)

Date fields. These are set to a L<DateTime|DateTime> object assuming
that we can build a date properly from the input data. (See
C<date_format> if you want to parse a single field, and also
L<OpenInteract2::Request/param_date>.)

=item *

B<datetime> ($ or \@)

Datetime fields. These are set to a L<DateTime|DateTime> object
assuming that we can build a date and time properly from the input
data. (See C<date_format> if you want to parse a single field, and
also L<OpenInteract2::Request/param_date>.)

=item *

B<date_format> ($)

The C<strptime> format for all B<date> fields. (See
L<DateTime::Format::Strptime|DateTime::Format::Strptime>)

=item *

B<datetime_format> ($)

The C<strptime> format for all B<datetime> fields. (See
L<DateTime::Format::Strptime|DateTime::Format::Strptime>)

=back

The following example will set in C<$object> the normal fields
'first_name' and 'last_name', the date field 'birth_date' (formatted
in the standard 'yyyy-mm-dd' format) and the toggled field 'opt_in':

 $self->_common_assign_properties(
     $object, { standard    => [ 'first_name', 'last_name' ],
                toggled     => 'opt_in',
                date        => 'birth_date',
                date_format => '%Y-%m-%d' }
 );

=head2 Checking Parameters

This class has a number of methods that subclasses can call to check
parameters. Each method returns the number of errors found (0 is
good). It also deposits a message in the C<error_msg> action parameter
so you and the user can find out what happened.

B<_common_check_object_class()>

Ensures the parameter C<c_object_type> is present and refers to a
valid object class as returned by the context. We check the latter
condition like this:

 my $object_class = eval { CTX->lookup_object( $object_type ) };

If nothing is returned or the C<lookup_object()> method throws an
exception the condition fails.

If both conditions are true we set the parameter C<c_object_class> so
you don't need to do the lookup yourself.

B<_common_check_id_field()>

Ensures the object class (set in C<c_object_class>) has an ID field
specified. (Since we depend on C<c_object_class> you should run the
C<_common_check_object_class()> check first.) We check the ID field
from the class with:

 my $object_class = $self->param( 'c_object_class' );
 my $id_field = eval { $object_class->id_field };

If no ID field is returned or the method throws an exception the
condition fails.

If the condition succeeds we set the parameter C<c_id_field> so you
don't need to do the lookup yourself.

B<_common_check_id()>

Tries to find the ID for an object using a number of methods. We
depend on the C<c_id_field> parameter being set, so you should run
C<_common_check_id_field> before this check.

Here's how we find the ID, in order.

=over 4

=item *

Is there an action parameter with the name C<c_id>?

=item *

Is there an action parameter with the same name as the ID field?

=item *

Is there a request parameter with the same name as the ID field?

=item *

Is there a request parameter with the name 'id'?

=back

The first check that finds an ID is used. If no ID is found the check
fails. If an ID is found it's set in the action parameter C<c_id> so
you don't need to do the lookup.

B<_common_check_template_specified( @template_parameters )>

Check to see that each of C<@template_parameters> -- an error message
is generated for each one that is not.

No side effects.

B<_common_check_param( @params )>

Just check that each one of C<@params> is defined -- an error message
is generated for each one that is not. If you want to check that a
template is defined you should use
C<_common_check_template_specified()> since it provides a better error
message.

No side effects.

=head2 Setting Defaults

B<_common_set_defaults( \%defaults )>

Treats each key/value pair in C<\%defaults> as default action
parameters to set.

=head2 Handling Errors

B<common_error>

Displays any error messages set in your action using the template
returned from C<_common_error_template>.

Example:

 if ( $flubbed_up ) {
     $self->param_add( error_msg => 'Something is flubbed up' );
     $self->task( 'common_error' );
     return $self->execute;
 }

You could also use a shortcut:

 if ( $flubbed_up ) {
     $self->param_add( error_msg => 'Something is flubbed up' );
     return $self->execute({ task => 'common_error' });
 }

B<_common_error_template>

Returns a fully-qualified template name for when your action
encounters an error. By default this is defined as
C<common_action_error>, but you can also override this method and
define it yourself. If you do should take the same parameters as the
global C<error_message> template.

=head1 SEE ALSO

L<OpenInteract2::Action::CommonAdd|OpenInteract2::Action::CommonAdd>

L<OpenInteract2::Action::CommonDisplay|OpenInteract2::Action::CommonDisplay>

L<OpenInteract2::Action::CommonRemove|OpenInteract2::Action::CommonRemove>

L<OpenInteract2::Action::CommonSearch|OpenInteract2::Action::CommonSearch>

L<OpenInteract2::Action::CommonUpdate|OpenInteract2::Action::CommonUpdate>

=head1 COPYRIGHT

Copyright (c) 2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
