package OpenInteract::Handler::GenericDispatcher;

# $Id: GenericDispatcher.pm,v 1.3 2001/09/21 02:59:43 lachoy Exp $

use strict;
use SPOPS::Secure qw( SEC_LEVEL_WRITE );
require Exporter;

@OpenInteract::Handler::GenericDispatcher::ISA     = qw( Exporter );
$OpenInteract::Handler::GenericDispatcher::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);
@OpenInteract::Handler::GenericDispatcher::EXPORT_OK = qw( DEFAULT_SECURITY_KEY );

use constant DEFAULT_SECURITY_KEY => 'DEFAULT';


# Note that we do "no strict 'refs'" a few times in various methods
# throughout this packge -- it's just so we can refer to packge
# variables properly.

sub handler {
    my ( $class, $p ) = @_;
    my $R = OpenInteract::Request->instance;

    # This routine should take care of parsing the task from the
    # information passed in the $p hashref or via theURL and if not
    # given, discerning a default; if there is no task returned, we're
    # outta here.

    my $task = $p->{task} || $class->_get_task;

    $R->DEBUG && $R->scrib( 1, "Trying to run $class with $task" );

    # Default is to email the author there is no default task defined.

    return $class->_no_task_found  unless( $task );

    # If we are not allowed to run the task, the error handler should 
    # die() with the content for the page

    unless ( $class->_task_allowed( $task ) ) {
        $R->DEBUG && $R->scrib( 1, "$task is forbidden by $class; bailing." );
        $R->throw({ code  => 303, 
                    type  => 'module', 
                    extra => { task => $task } });
    }

    # Check to see that user can do this task with security; if not
    # routine should die() with an error message.

    $p->{level} = $class->_check_task_security( $task );

    # For subclasses to override -- this would be useful if you want to
    # create a new dispatcher by subclassing this class and, for
    # instance, do a lookup in a hash or database as to what 'tab'
    # should be selected in a menubar on your web page.

    $class->_local_action( $p );

    return $class->$task( $p );
}


sub _local_action { return; }


# Get the task asked to do use the 'default_method' package variable

sub _get_task {
    my ( $class ) = @_;
    no strict 'refs';
    my $R = OpenInteract::Request->instance;
    my $task = lc shift @{ $R->{path}->{current} } ||
               ${ $class . '::default_method' };
    return $task;
}


# If there is no task defined, use the default method that $class
# has specified. What to do if $class hasn't specified one? 
# We should probably bail, create an error object and send it
# to the module's author. (cool!)

sub _no_task_found {
    my ( $class ) = @_;
    my $author_msg = <<MSG;
Your module ($class) does not have a default task defined.
Please create the package variable '\$$class\:\:default_method'
as soon as you can. 

Thanks!

The Management
MSG
    no strict 'refs';
    my $R = OpenInteract::Request->instance;
    return $R->throw( { code       => 304, 
                        type       => 'module',
                        system_msg => "Author has not defined default task for $class",
                        extra => { email   => ${ $class . '::author' }, 
                                   subject => "No default task defined for $class",
                                   msg     => $author_msg } } );
}



sub _task_allowed {
    my ( $class, $task ) = @_;

    # Tasks beginning with '_' are not allowed by default

    return undef if ( $task =~ /^_/ );
    no strict 'refs'; 

    # Check to see if this task is forbidden from being publicly called; if so, bail.

    my %forbidden = map { $_ => 1 } @{ $class . '::forbidden_methods' };
    return ! $forbidden{ $task };
}


sub _check_task_security {
    my ( $class, $task ) = @_;
    no strict 'refs';
    my $R = OpenInteract::Request->instance;

    # If the class uses security, $level will be overridden; if 
    # it does not use security, then it will be ignored. Note that
    # we pass this on to the handler so it doesn't need to check the
    # security again.

    my $level = SEC_LEVEL_WRITE;

    # Allow the handler to perform a shortcut if it wants to check
    # security; note that if security for a task is not defined in the
    # package, this check assumes WRITE security as a default

    if ( $class->isa( 'SPOPS::Secure' ) ) {
        $level           = eval { $R->user->check_security( { class => $class, oid => '0' } ) };
        my %all_levels   = %{ $class . '::security' };
        my $target_level = $all_levels{ $task } ||
                           $all_levels{ DEFAULT_SECURITY_KEY() } ||
                           SEC_LEVEL_WRITE;
        $R->DEBUG && $R->scrib( 2, "Security after check for ($task):\n", 
                                   "user has: $level; user needs: $target_level" );

        # Security check failed, so bail (error handler die()s with an error message

        if ( $level < $target_level ) {
            $R->throw( { code => 305, type => 'security',
                         extra => { user_level     => $level,
                                    required_level => $target_level,
                                    class          => $class,
                                    task           => $task } } );
        }
    }
    return $level;
}


# Return an object if we are able to construct it from parameters or 
# wherever; if we have errors, raise them 

sub _create_object {
    my ( $class, $p ) = @_;
    my $R = OpenInteract::Request->instance;
    my $id_field_list = ( ref $p->{_id_field} ) ? $p->{_id_field} : [ $p->{_id_field} ];
    my $object_class = $p->{_class};
    unless ( scalar @{ $id_field_list } and $object_class ) {
        die "Cannot retrieve object without id_field and class definitions\n";
    }

    my $oid = undef;
    foreach my $id_field ( @{ $id_field_list } ) {
        $oid = $R->apache->param( $id_field );
        last if ( $oid );
    }
    return undef unless ( $oid );
    my $object = eval { $object_class->fetch( $oid ) };
    if ( $@ ) {
        my $ei = OpenInteract::Error->set( SPOPS::Error->get );
        my $error_msg = undef;
        if ( $ei->{type} eq 'security' ) {
            $error_msg = "Permission denied: you do not have access to view the requested object. ";
        }
        else {
            $R->throw( { code => 404 } );
            $error_msg = "Error encountered trying to retrieve object. The error has been logged. "
        }
        die "$error_msg\n";
    }
    return $object;
} 

sub date_process {
    my ( $class, $date ) = @_;
    return {} if ( ! $date );
    my ( $y, $m, $d ) = split /\D/, $date;
    $m =~ s/^0//;   # do this so comparisons 
    $d =~ s/^0//;   # within Template work
    return { year => $y, month => $m, day => $d };
}

sub date_read {
    my ( $class, $prefix, $defaults ) = @_;
    $defaults ||= {};
    my $apr = OpenInteract::Request->instance->apache;
    my $day   = $apr->param( "${prefix}_day" )   || $defaults->{day_default};
    my $month = $apr->param( "${prefix}_month" ) || $defaults->{month_default};
    my $year  = $apr->param( "${prefix}_year" )  || $defaults->{year_default};
    return join '-', $year, $month, $day if ( $day and $month and $year );
    return undef;
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Handler::GenericDispatcher - Define task-dispatching, security-checking and other routines for Handlers to use

=head1 SYNOPSIS

 use OpenInteract::Handler::GenericDispatcher qw( DEFAULT_SECURITY_KEY );
 use SPOPS::Secure qw( :level );

 @OpenInteract::Handler::MyHandler::ISA = qw( 
                             OpenInteract::Handler::GenericDispatcher SPOPS::Secure );
 %OpenInteract::Handler::MyHandler::default_security = (
     DEFAULT_SECURITY_KEY() => SEC_LEVEL_READ,
     'edit'                 => SEC_LEVEL_WRITE );

=head1 DESCRIPTION

The Generic Dispatcher provides the methods to discern what task is
supposed to execute, ensure that the current user is allowed to
execute it, and returns the results of the task.

It is meant to be subclassed so that your handlers do not have to keep
parsing the URL for the action to take. Each action the Generic
Dispatcher takes can be overridden with your own.

This module provides the routine 'handler' for you, which does all the
routines (security checking and other) for you, then calls the proper
method.

There are also a couple of utility methods you can use, although they
will probably be punted off to a separate module at some point.

B<NOTE>: This module will likely be scrapped for a more robust
dispatching system. Please see L<NOTES> for a discussion.

=head1 METHODS

Even though there is only one primary method for this class
(C<handler()>), you may override individual aspects of the checking
routine:

B<_get_task>

Return a task name by whatever means necessary. Default behavior is
to return the next element (lowercased) from:

 $R->{path}->{current}

If that element is undefined (or blank), the default behavior returns
the the package variable B<default_method>.

Return a string corresponding to a method.

B<_no_task_found>

Called when no task is found from the I<_get_task> method. Default
behavior is to email the author of the handler (found in the package
variable B<author>) and tell him/her to at least define a default
method.

Method should either return or I<die()> with html necessary for
displaying an error.

B<_task_allowed( $task )>

Called to ensure the $task found earlier is not forbidden from being
run. Tasks beginning with '_' are automatically denied, and we look
into the @forbidden_methods package variable for further
enlightenment. Return 1 if allowed, 0 if forbidden.

B<_check_task_security>

Called to ensure this $task can be run by the currently logged-in
user. Default behavior is to check the security for this user and
module against the package hash B<security>, which has tasks as keys
and security levels as values.

Note: you can define a default security for your methods and then
specify security for only the ones you need using the exported
constant 'DEFAULT_SECURITY_KEY'. For instance:

  %My::Handler::Action = (
     DEFAULT_SECURITY_KEY() => SEC_LEVEL_READ,
     edit                   => SEC_LEVEL_WRITE,
  );

So all methods except 'edit' are protected by SEC_LEVEL_READ.

Returns: the level for this user and this task.

B<_local_task>

This is an empty method in the GenericDispatcher, but you can create a
subclass of the dispatcher for your application to do application-wide
actions. For instance, if you had a tag in every handler that was to
be set in $R-E<gt>{page} and parsed by the main template to select a
particular 'tab' on your web page, you could do so in this method.

=head2 Utility

B<_create_object( \%params )>

Create an object from the information passed in via GET/POST and
C<\%params>.

Parameters:

 _id_field: \@ or $ with field name(s) used to find ID value
 _class:    $ with class of object to create

Returns: object created with information, C<undef> if object ID not
found, C<die> thrown if object class or ID field not given, or if the
retrieval fails.

B<date_process( 'yyyy-mm-dd' )>

WARNING: This method might be removed altogether.

Return a hashref formatted:

 { year  => 'yyyy',
   month => 'mm',
   day   => 'dd' }

B<date_read( $prefix, [ \%defaults ] )>

Read in date information from GET/POST information. The fields are:

 day    => ${prefix}_day
 month  => ${prefix}_month
 year   => ${prefix}_year

If you want a default set for the day, month or year, pass the
information in a hashref as the second argument.

=head1 NOTES

B<Discussion about Creating a 'Real' Dispatcher>

Think about making available to a handler its configuration
information from the action.perl file, so you can set information
there and have it available in your environment without having to know
how your handler was called.

For instance, in your C<action.perl> you might have:

 {
    'news' => { 
        language => 'en',
        class    => 'OpenInteract::Handler::News',
        security => 'no',
        title    => 'Weekly News',
        posted_on_format => "Posted: DATE_FORMAT( posted_on, '%M %e, %Y' )",
    },

    'nouvelles' => {
        language => 'fr',
        title    => 'Les Nouvelles',
        redir    => 'news',
        posted_on_format => "Les Post: DATE_FORMAT( posted_on, '%M %e, %Y' )",
    },

 }

A call to the URL '/nouvelles/' would make the information:

 { 
   language => 'fr',
   title    => 'Les Nouvelles',
   security => 'no',
   class    => 'OpenInteract::Handler::News', 
   posted_on_format => "Les Post: DATE_FORMAT( posted_on, '%M %e, %Y' )",
 }

available to the handler via the $p variable passed in:

 my $info = $p->{handler_info};
 # $info->{language} is now 'fr'

Use this as the basis for a new class:
'OpenInteract::ActionDispatcher' which you use to call all
actions. The ActionDispatcher can lookup the action (and remember all
its properties, even through 'redir' calls like outlined above), can
check the executor of an action for whether the task can be executed
or not (whether the task exists, whether the task is allowed) and can
check the security of the task as well. At each step the
ActionDispatcher has the option of running its automated checks (which
it might cache by website...) or checking callbacks defined in the
content handler.

So each content handler would get two arguments: its own class and a
hashref of metadata, which would include:

 - task called ('task')

 - action info compiled ('action_info', a hashref with basic things
 like 'class', 'security', 'title' as well as any custom modifications
 by the developer

 - the security level for this user and this task ('security_level'
 and 'security' to be backward compatible)

We will use 'can' to see whether the callback exists in the handler
class so the callback could also be defined in a superclass of the
handler. So I could define a hierarchy of content handlers and have
things just work. (You can do this now, but it is a little more
difficult.)

One sticky thing: every request for an action would have to be
rewritten to use the dispatcher, although we could create a wrapper in
OpenInteract::Request to try for backward compatibility
('lookup_request' and all).

=head1 TO DO

B<Move utility methods to separate class>

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
