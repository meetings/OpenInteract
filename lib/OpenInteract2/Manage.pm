package OpenInteract2::Manage;

# $Id: Manage.pm,v 1.21 2003/07/03 03:42:47 lachoy Exp $

use strict;
use base qw( Exporter Class::Factory Class::Observable );
use File::Spec;
use Log::Log4perl            qw( get_logger :levels );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_param_error );
use OpenInteract2::Setup;

$OpenInteract2::Manage::VERSION = sprintf("%d.%02d", q$Revision: 1.21 $ =~ /(\d+)\.(\d+)/);

my $SYSTEM_PACKAGES = [ qw/ base
                            base_box
                            base_error
                            base_group
                            base_page
                            base_security
                            base_template
                            base_theme
                            base_user
                            full_text
                            news
                            lookup
                            object_activity
                            system_doc / ];

sub SYSTEM_PACKAGES { return $SYSTEM_PACKAGES }

my %PACKAGE_GROUPS = (
    SYSTEM => $SYSTEM_PACKAGES,
);

use constant DEV_LIST  => 'openinteract-dev@lists.sourceforge.net';
use constant HELP_LIST => 'openinteract-help@lists.sourceforge.net';

@OpenInteract2::Manage::EXPORT_OK = qw(
          SYSTEM_PACKAGES DEV_LIST HELP_LIST
);

########################################
# INTERFACE
# All are optional except run_task()

# Run at new()
sub init                {}

# Return the required parameters
sub list_param_required { return [] }

# Return the optional parameters (used for reflection)
sub list_param_optional { return [] }

# Return the parameters to validate
sub list_param_validate { return [] }

# Do the work!
sub run_task            { die "Define run_task() in subclass" }

# Do work before run_task()
sub setup_task          { return undef }

# Do cleanup after run_task()
sub tear_down_task      { return undef }

# Help out tools using your task and describe what it does
sub brief_description   { return 'No description available' }

# Do pre-validation transformations of parameters

sub param_initialize {
    my ( $self ) = @_;
    $self->_init_setup_packages;
}

# Return coderef to validate given param; a few are built-in for
# everyone to use

sub get_validate_sub {
    my ( $self, $param_name ) = @_;
    return \&_check_source_dir   if ( $param_name eq 'source_dir' );
    return \&_check_website_dir  if ( $param_name eq 'website_dir' );
    return \&_check_package_file if ( $param_name eq 'package_file' );
    return undef;
}

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'source_dir' ) {
        return "OpenInteract2 source directory, or at least a directory with " .
               "the 'pkg/' and 'sample/' directories from the distribution.";
    }
    elsif ( $param_name eq 'website_dir' ) {
        return "Functional OpenInteract2 website directory";
    }
    elsif ( $param_name eq 'package_list_file' ) {
        return "Filename with packages to process, one per line";
    }
    elsif ( $param_name eq 'package' ) {
        return "One or more packages to process";
    }
    return 'no description available';
}

########################################
# RUN

sub execute {
    my ( $self ) = @_;
    $self->check_parameters;
    $self->setup_task;

    # Track our current directory so the task can feel free to do what
    # it wants

    my $pwd = File::Spec->rel2abs( File::Spec->curdir );

    $self->notify_observers( progress => 'Starting task' );

    eval { $self->run_task };
    my $error = $@;
    if ( $@ ) {
        Carp::carp "Caught error: $@";
        $self->param( 'task_failed', 'yes' );
    }
    $self->tear_down_task;
    chdir( $pwd );
    if ( $error ) {
        oi_error $@;
    }
    $self->notify_observers( progress => 'Task complete' );
    return $self->get_status;
}


########################################
# PARAMETER CHECKING

# Wrapper for all check methods

sub check_parameters {
    my ( $self ) = @_;
    $self->param_initialize();
    $self->check_required_parameters();
    $self->check_valid_parameters();
}

sub check_required_parameters {
    my ( $self ) = @_;
    my $required = $self->list_param_require();
    my %not_found_errors = map { $_ => 'Required parameter not defined' }
                           grep { ! $self->param( $_ ) }
                           @{ $required };
    if ( scalar keys %not_found_errors ) {
        oi_param_error "A value for one or more required parameters ",
                       "was not found.",
                       { parameter_fail => \%not_found_errors };
    }
}

sub check_valid_parameters {
    my ( $self ) = @_;
    my %check_errors = ();
    my $check = $self->list_param_validate();
    foreach my $name ( @{ $check } ) {
        my $check_sub = $self->get_validate_sub( $name );
        unless ( ref $check_sub eq 'CODE' ) {
            oi_error "Cannot check validity of parameter [$name]: it is ",
                     "not a core system parameter and the task ",
                     "[", $self->task_name, "] does not provide the means ",
                     "to check it";
        }
        my $value = $self->param( $name );
        my @errors = $check_sub->( $self, $value );
        if ( scalar @errors ) {
            my $value_errors = grep { defined $_ } @errors;
            if ( $value_errors > 0 ) {
                $check_errors{ $name } = \@errors;
            }
        }
    }

    if ( scalar keys %check_errors ) {
        OpenInteract2::Exception::Parameter->throw(
                    "One or more parameters failed a validity check",
                    { parameter_fail => \%check_errors } );
    }
}

# These are referenced by get_validate_sub() up top

sub _check_source_dir {
    my ( $self, $source_dir ) = @_;
    unless ( -d $source_dir ) {
        return "Value for 'source_dir' must be a valid directory";
    }
    foreach my $distrib_dir ( qw( pkg sample ) ) {
        my $full_distrib_dir = File::Spec->catdir( $source_dir, $distrib_dir );
        unless ( -d $full_distrib_dir ) {
            return "The 'source_dir' must have valid subdirectory " .
                   "[$distrib_dir]";
        }
    }
    return;
}


sub _check_website_dir {
    my ( $self, $website_dir ) = @_;
    unless ( -d $website_dir ) {
        return "Value for 'website_dir' must be a valid directory";
    }
    return;
}


sub _check_package_file {
    my ( $self, $package_file ) = @_;
    unless ( -f $package_file ) {
        return "Value for 'package_file' must specify a valid file";
    }
    return;
}


########################################
# PARAMETER INITIALIZATION

# If package exist, reads in the SYSTEM value, the
# package_list_file, etc.

sub _init_setup_packages {
    my ( $self ) = @_;
    my $initial_packages = $self->param( 'package' );
    return unless ( $initial_packages );
    if ( ref $initial_packages ne 'ARRAY' ) {
        $self->param( package => [ $initial_packages ] );
    }
    $self->_init_setup_comma_packages;
    $self->_init_setup_package_groups;
    $self->_init_read_packages_from_file;

    # Remove dupes

    my $packages = $self->param( 'package' );
    if ( ref $packages eq 'ARRAY' ) {
        my %names = map { $_ => 1 } @{ $packages };
        $self->param( package => [ sort keys %names ] );
    }
}

# allows --package=x,y --package=z to be combined; assumes 'package'
# param is already an arrayref

sub _init_setup_comma_packages {
    my ( $self ) = @_;
    my $packages = $self->param( 'package' );
    $self->param( package => [ split( /\s*,\s*/, join( ',', @{ $packages } ) ) ] );
}


# Allow a special keyword for users to specify all the initial (base)
# packages. This allows something like:
#
#   oi_manage --package=SYSTEM ...
#   oi_manage --package=SYSTEM,mypkg,theirpkg ...
#
# and the keyword 'SYSTEM' will be replaced by all the system
# packages, which can be found by doing 'oi2_manage system_packages';
# assumes 'package' param is already an arrayref

sub _init_setup_package_groups {
    my ( $self ) = @_;
    my $packages = $self->param( 'package' );
    return unless ( ref $packages eq 'ARRAY' );
    my %pkg_names = map { $_ => 1 } @{ $packages };
    foreach my $group_key ( keys %PACKAGE_GROUPS ) {
        if ( exists $pkg_names{ $group_key } ) {
            $pkg_names{ $_ }++ for ( @{ $PACKAGE_GROUPS{ $group_key } } );
            delete $pkg_names{ $group_key };
        }
    }
    $self->param( package => [ sort keys %pkg_names ] )
}

# assumes 'package' param is already an arrayref

sub _init_read_packages_from_file {
    my ( $self ) = @_;
    my $filename = $self->param( 'package_list_file' );
    return unless ( $filename );
    unless ( -f $filename ) {
        oi_error "Failure reading package list file [$filename]: ",
                 "file does not exist";
    }
    eval { open( PKG, '<', $filename ) || die $! };
    if ( $@ ) {
        oi_error "Failure reading package list file [$filename]: $@";
    }
    my @read_packages = ();
    while ( <PKG> ) {
        chomp;
        next if /^\s*\#/;
        next if /^\s*$/;
        s/^\s+//;
        s/\s+$//;
        push @read_packages, $_;
    }
    close( PKG );

    # They can also specify --package, so add those too -- don't worry
    # about dupes, they get weeded out later

    $self->param( package => [ @read_packages,
                               @{ $self->param( 'package' ) } ] );
}


########################################
# CONSTRUCTOR

sub new {
    my ( $pkg, $task_name, $params, @extra ) = @_;
    my $class = $pkg->get_factory_class( $task_name );
    my $self = bless( { _status => [] }, $class );
    $self->task_name( $task_name );

    if ( ref $params eq 'HASH' ) {
        while ( my ( $name, $value ) = each %{ $params } ) {
            $self->param( $name, $value );
        }
    }
    $self->init( @extra );
    return $self;
}

########################################
# TASK LIST/CHECK

sub is_valid_task {
    my ( $class, $task_name ) = @_;
    my %tasks = map { $_ => 1 } $class->valid_tasks;
    return ( defined $tasks{ $task_name } );
}

sub valid_tasks {
    return __PACKAGE__->get_registered_types;
}

sub valid_tasks_description {
    my ( $self ) = @_;
    my %tasks = map { $_ => 1 } $self->valid_tasks;
    foreach my $task ( keys %tasks ) {
        my $task_class = $self->get_factory_class( $task );
        my $desc  = $task_class->brief_description;
        $tasks{ $task } = $desc;
    }
    return \%tasks;
}

########################################
# PARAMETERS

sub param {
    my ( $self, $key, $value ) = @_;
    return $self->{params}  unless ( $key );
    if ( $value ) {
        $self->{params}{ $key } = $value;
    }
    return $self->{params}{ $key };
}

sub param_copy {
    my ( $self, $other_task ) = @_;
    my $other_params = $other_task->param;
    while ( my ( $name, $value ) = each %{ $other_params } ) {
        $self->param( $name, $value );
    }
    return $self->param;
}

sub task_name {
    my ( $self, $task_name ) = @_;
    if ( $task_name ) {
        $self->{task_name} = $task_name;
    }
    return $self->{task_name};
}


########################################
# STATUS

sub _add_status {
    my ( $self, @status ) = @_;
    push @{ $self->{_status} }, @status;
    foreach my $hr ( @status ) {
        $self->notify_observers( status => $hr );
    }
    return $self->{_status};
}

sub _add_status_head {
    my ( $self, @status ) = @_;
    unshift @{ $self->{_status} }, @status;
    foreach my $hr ( @status ) {
        $self->notify_observers( status => $hr );
    }
    return $self->{_status};
}

sub get_status {
    my ( $self ) = @_;
    return @{ $self->{_status} };
}

sub merge_status_by_action {
    my ( $item, @status ) = @_;
    if ( scalar @status == 0
         and UNIVERSAL::isa( $item, 'OpenInteract2::Manage' ) ) {
        @status = $item->get_status;
    }
    my $current_action = '';
    my @tmp_status = ();
    my @new_status = ();
    foreach my $s ( @status ) {
        unless ( $current_action ) {
            $current_action = $s->{action};
        }
        if ( $s->{action} ne $current_action ) {
            push @new_status, { action => $current_action,
                                status => [ @tmp_status ] };
            @tmp_status = ();
            $current_action = $s->{action};
        }
        push @tmp_status, $s;
    }
    if ( scalar @tmp_status > 0 ) {
        push @new_status, { action => $current_action,
                            status => \@tmp_status };
    }
    return @new_status;
}


########################################
# INFRASTRUCTURE

sub setup_context {
    my ( $self, @params ) = @_;
    my $website_dir = $self->param( 'website_dir' );
    unless ( -d $website_dir ) {
        oi_error "Cannot open context with no website directory";
    }
    my $base_config = OpenInteract2::Config::Base->new({
                              website_dir => $website_dir });
    if ( $self->param( 'debug' ) ) {
        get_logger()->level( $DEBUG );
    }
    OpenInteract2::Context->create( $base_config, @params );
}

# This should register all the default tasks, but don't 'use' them or
# we'll get some side effects...

require OpenInteract2::Manage::Package;
require OpenInteract2::Manage::Website;
__PACKAGE__->register_factory_type(
    create_source_dir => 'OpenInteract2::Manage::CreateSourceDirectory' );

1;

__END__

=head1 NAME

OpenInteract2::Manage - Provide common functions and factory for management tasks

=head1 SYNOPSIS

 # Common programmatic use of management task:
 
 use strict;
 use OpenInteract2::Manage;
 
 my $task = OpenInteract2::Manage->new(
                    'install_package',
                    { filename    => '/home/httpd/site/uploads/file.tar.gz',
                      website_dir => '/home/httpd/site' } );
 my @status = eval { $task->execute };
 if ( $@ ) {
     if ( $@->isa( 'OpenInteract2::Exception::Parameter' ) ) {
         my $failures = $@->parameter_fail;
         while ( my ( $field, $reasons ) = each %{ $failures } ) {
             print "Field $field: ", join( ", ", @{ $reasons } ), "\n";
         }
     }
     exit;
 }
 
 foreach my $s ( @status ) {
     print "Status: ", ( $s->{is_ok} eq 'yes' ) ? 'OK' : 'NOT OK';
     print "\n$s->{message}\n";
 }
 
 # Every task needs to implement the following:
 
 sub run_task         {}
 
 # The task can implement this to initialize the object
 
 sub init             {}
 
 # The task can also implement these for setting up/clearing out the
 # environment
 
 sub setup_task       {}
 sub tear_down_task   {}
 
 # The task can also implement these for checking/validating
 # parameters
 
 sub list_param_required {}
 sub list_param_validate {}
 sub get_validate_sub    {}
 

 # This task is strongly advised to implement these to let the outside
 # world know about its purpose and parameters.
 
 sub brief_description {}
 sub get_param_description {}

=head1 DESCRIPTION

L<OpenInteract2::Manage|OpenInteract2::Manage> is the organizer,
interface and factory for tasks managing OpenInteract2. Its goal is to
make these tasks runnable from anywhere, not just the command-line,
and to provide output that can be parsed in a sufficiently generic
format to be useful anywhere.

Since it is an organizing module it does not actually perform the
tasks. You will want to see
L<OpenInteract2::Manage::Package|OpenInteract2::Manage::Package> or
L<OpenInteract2::Manage::Website|OpenInteract2::Manage::Website> to get
closer to that metal. You can also subclass this class directly, but
look first into the other subclasses as they may provide functionality
to make your task easier to implement.

Additionally, most people will probably use the C<oi2_manage>
front-end to this set of tasks, so you probably want to look there if
you're itching to do something quickly.

=head1 METHODS

B<new( $task, [ \%params, ], [ @extra_params ]  )>

Creates a new management task of type C<$task>. If type C<$task> is
not yet registered, the method throws an exception.

You can also pass any number of C<\%params> with which the management
task gets initialized (using C<init()>, below). These are blindly set
and not checked until you run C<execute()>.

All of the C<extra_params> are passed to C<init()>, which subclasses
may implement to do any additional initialization.

Returns: New management task object

B<execute()>

Runs through the methods C<check_parameters()>, C<setup_task()>,
C<run_task()>, C<tear_down_task()>.

Any of these methods can throw an exception, so it is up to you to
wrap the call to C<execute()> in an C<eval> block and examine C<$@>.

Returns: an arrayref of status hash references. These should include
the keys 'is_ok' (set to 'yes' if the item succeeded, 'no' if not) and
'message' describing the results. Tasks may set additional items as
well, all of which should be documented in the task.

You can also retrieve the status messages by calling C<get_status()>.

B<is_valid_task( $task_name )>

Returns true if C<$task_name> is a valid task, false if not.

B<valid_tasks()>

Query the class about what tasks are currently registered.

Returns: list of registered tasks

B<valid_tasks_description()>

Query the class about what tasks are currently registered, plus get a
brief description of each.

Returns: hashref of registered tasks (keys) and their descriptions
(values).

=head1 OBSERVERS

Every management task is observable. (See
L<Class::Observable|Class::Observable> for what this means.) As a
creator and user of a task you can add your own observers to it and
receive status and progress messages from the task as it performs its
work.

There are two types of standard observations posted from management
tasks. This type is passed as the first argument to your observer.

=over 4

=item *

B<status>: This is a normal status message. (See L<STATUS MESSAGES>
for what this means.) The second argument passed to your observer will
be the hashref representing the status message.

=item *

B<progress>: Indicates a new stage of the process has been reached or
completed. The second argument to your observer is a text message, the
optional third argument is a hashref of additional
information. Currently this has only one option: B<long> may be set to
'yes', and if so the task is telling you it's about to begin a
long-running process.

=back

For an example of an observer, see C<oi2_manage>.

=head1 PARAMETERS AND CHECKING

Every management task should be initialized with parameters that tell
the task how or where to perform its work. This parent class provides
the means to ensure required parameters are defined and that they are
valid. This parameter checking is very flexible so it is simple to
define your own validation checks and tell them to this parent class.

=head2 Access/Modify Parameters

B<param( $key, $value )>

If C<$key> is unspecified, returns all parameters as a hashref.

If C<$value> is unspecified, returns the current value set for
parameter C<$key>.

If both C<$key> and C<$value> are specified, sets the parameter
C<$key> to C<$value> and returns it.

Example:

 $task->param( 'website_dir', '/home/httpd/test' );
 $task->param( package => [ 'pkg1', 'pkg2' ] );
 my $all_params = $task->param;

Another way of setting parameters is by passing them into the
constructor. The second argument (hashref) passed into the C<new()>
call can be set to the parameters you want to use for the task. This
makes it simple to do initialization and execution in one step:

 my @status = OpenInteract2::Manage->new( 'create_website',
                                          { website_dir  => '/home/httpd/test' } )
                                   ->execute();

=head2 Checking Parameters: Flow

The management class has a fairly simple but flexible way for you to
ensure that your task gets valid parameters.

First, you can ensure that all the parameters required are defined by
the task caller. Simply create a method C<list_param_required()> which
returns an arrayref of parameters that require a value to be defined:

 sub list_param_required { return [ 'website_dir', 'package_dir' ] }

You can also override the method C<check_required_parameters()>, but
this requires you to throw the exceptions yourself.

Next, you need to ensure that all the parameters are valid. There are a couple of ways to do this

=head2 Checking Parameters: Methods

B<check_parameters()>

This method is really just a wrapper for parameter initialization,
required parameter checking and parameter validation.

It is called from C<execute()> before C<run_task()> is called. It
depends on the methods C<list_param_required()> and
C<list_param_validate()> being defined in your task.

The first action it performs is to call C<param_initialize()> so your
task can do any necessary parameter manipulation.

Next it calls C<check_required_parameters()>, which cycles through the
arrayref returned by C<list_param_required()> and ensures that a value
for each parameter exists.

Finally it calls C<check_valid_parameters()>, which ensures that
parameters requiring validation (those returned by
C<list_param_validated()>) are valid.

Any errors thrown by these methods are percolated up back to the
caller. Barring strange runtime errors they're going to be
L<OpenInteract2::Exception::Parameter|OpenInteract2::Exception::Parameter>
objects, which means the caller can do a filter as needed, displaying
more pertient information:

 eval { $task->execute }
 my $error = $@;;
 if ( $error ) {
     if ( $error->isa( 'OpenInteract2::Exception::Parameter' ) ) {
         print "Caught an exception with one or more paramters:\n";
         my $failed = $error->parameter_fail;
         while ( my ( $field, $fail ) = each %{ $failed } ) {
             my @failures = ( ref $fail eq 'ARRAY' ) ? @{ $fail } : ( $fail );
             foreach my $failure ( @failures ) {
                 print sprintf( "%-20s-> %s\n", $field, $failure );
             }
         }
     }
 }

B<param_initialize()>

This class implements this method to massage the 'package' parameter
into a consistent format.

You may want to implement it to modify your parameters before any
checking or validation. For instance, tasks dealing with packages
typically allow you to pass in a list or a comma-separated string, or
even use a keyword to represent multiple packages. The
C<param_initialize()> method can change each of these into a
consistent format, allowing the task to assume it will always be
dealing with an arrayref.

If you're a subclass you should always pass the call up to your parent
via C<SUPER>.

B<check_required_parameters()>

Calls C<list_param_require> and ensures that each parameter listed in
the returned arrayref has been set in the task. If not, it throws a
L<OpenInteract2::Exception::Parameter|OpenInteract2::Exception::Parameter>
error with the name of all undefined parameters.

B<check_valid_parameters()>

Calls C<list_param_validate> and ensures that each parameter listed is
valid. What 'valid' means depends on you: one of your parents may
implement a validation routine (e.g.,
L<OpenInteract2::Manage|OpenInteract2::Manage> or
L<OpenInteract2::Manage::Website|OpenInteract2::Manage::Website>) or
you may implement your own.

You create your own validation routine by returning a subroutine
reference from a call to C<get_validate_sub()> which includes the
parameter being validated as the argument. This subroutine should
return C<undef> if the parameter is valid or an error message if it is
not.

See an example of this in L<SUBCLASSING>.

C<get_validate_sub( $param_name )>

Return a parameter subroutine to validate parameter
C<$param_name>. The subroutine is passed the task object and the value
of parameter C<$param_name>. It should return nothing (C<undef> is ok)
if the parameter value is valid. Otherwise it should return an error
message.

If you're a subclass you should forward the request onto your parents
via C<SUPER>. (See example below.)

=head1 STATUS MESSAGES

Status messages are simple hashrefs with at least three entries:

=over 4

=item *

B<is_ok>: Set to 'yes' if this a successful status, 'no' if not.

=item *

B<action>: Name of the action.

=item *

B<message>: Message describing the action or the error encountered.

=back

Each message may have any number of additional entries. A common one
is B<filename>, which is used to indicate the file acted upon. Every
management task should list what keys its status messages support, not
including the three listed above.

Some tasks can generate a lot of status messages, so the method
C<merge_status_by_action> will merge all status messages with the same
C<action> into a single message with the keys C<action> (the action)
and C<status> (an arrayref of the collected status messages under that
action).

=head1 SUBCLASSING

The following is for developers creating new management tasks.

=head2 Mandatory methods

Management tasks must implement:

B<run_task()>

This is where you actually perform the work of your task. You can
indicate the status of your task with status hashrefs passed to
C<_add_status()> or C<_add_status_head()>. (See L<STATUS MESSAGES>
above.)

Errors are indicated by throwing an exception -- generally an
L<OpenInteract2::Exception|OpenInteract2::Exception> object, but if you
want to create your own there is nothing stopping you.

The task manager will set the parameter C<task_failed> to 'yes' if it
catches an error from C<run_task>. This allows you to do conditional
cleanup in C<tear_down_task>, discussed below.

Note that the caller ensures that the directory remains the same for
the caller, so you can C<chdir> to your heart's content.

=head2 Optional methods

B<init( @extra )>

This is called within the C<new()> method. All extra parameters sent
to C<new()> are passed to this method, since the main parameters have
already been set in the object.

B<brief_description()>

Return a string a sentence or two long describing what the task does.

B<get_param_description( $param_name )>

Return a description for parameter C<$param_name>. Once you've
exhausted the ones you want to describe be sure to pass the call back
up to SUPER so other classes have a chance to describe parameters:

 sub get_param_description {
     my ( $self, $param_name ) = @_;
     if ( $param_name eq 'my_param' ) {
         return '...';
     }
     return $self->SUPER::get_param_description( $param_name );
 }

B<setup_task()>

Sets up the environment required for this task. This might require
creating an L<OpenInteract2::Context|OpenInteract2::Context>, a database
connection, or some other action. (Some of these have shortcuts -- see
below.)

If you cannot setup the required environment you should throw an
exception with an appropriate message.

B<tear_down_task()>

If your task needs to do any cleanup actions -- closing a database
connection, etc. -- it should perform them here.

The task manager will set the parameter C<task_failed> to 'yes' if the
main task threw an error. This allows you to do conditional cleanup --
for instance,
L<OpenInteract2::Manage::Website::Create|OpenInteract2::Manage::Website::Create>
checks this field and if it is set will remove the directories created
and all the files copied in the halted process of creating a new
website.

B<list_param_required()>

This should return an arrayref of parameters. Before executing
C<run_task()> the parent class will ensure that all parameters
specified in the arrayref are defined before continuing.

=head2 Parameter Validation

Here's an example where we depend on the validation routine for
C<website_dir> from L<OpenInteract2::Manage|OpenInteract2::Manage>:

 sub list_param_validate { return [ 'website_dir' ] }

That's it! C<check_valid_parameters()> will see that you'd like to
validate 'website_dir', look for a routine to validate it and fine
one.

Now, say we want to validate a different parameter:

 sub list_param_validate { return [ 'game_choice' ] }
 
 sub get_validate_sub {
     my ( $self, $param_name ) = @_;
     if ( $param_name eq 'game_choice' ) {
         return \&_rock_scissors_paper;
     }
     return $self->SUPER::get_validate_sub( $param_name );
 }
 
 sub _rock_scissors_paper {
     my ( $self, $game_choice ) = @_;
     unless ( $game_choice =~ /^(rock|scissors|paper)$/i ) {
         return "Value must be 'rock', 'scissors' or 'paper'";
     }
     return undef;
 }

This ensures that the parameter 'game_choice' is either 'rock',
'scissors' or 'paper' (case-insensitive). your C<run_task()> method
will never be run unless all the parameter requirements and validation
checks are successful.

=head2 Status helper methods

These methods should only be used by management tasks themselves, not
by the users of those tasks.

Note: All status messages are sent to the observers as a 'status'
observation. These are sent in the order received, so the user may be
a little confused if you use C<_add_status_head()>.

B<_add_status( ( \%status, \%status, ...) )>

Adds status message C<\%status> to those tracked by the object.

B<_add_status_head( ( \%status, \%status, ... ) )>

Adds status messages to the head of the list of status messages. This
is useful for when your management task comprises several others. You
can collect their status messages as your own, then insert an overall
status as the initial one seen by the user.

=head2 Notifying Observers

All management tasks are observable. This means anyone can add any
number of classes, objects or subroutines that receive observations
you post. Notifying observers is simple:

 $self->notify_observers( $type, @extra_info )

What goes into C<@extra_info> depends on the C<$type>. The two types
of observations supported right now are 'status' and 'progress'. The
'status' observations are generated automatically when you use
C<_add_status()> or C<_add_status_head()> (see above).

Generally 'progress' notifications are accompanied by a simple text
message. You may also pass as a third argument a hashref. This hashref
gives us room to grow and the observers the ability to differentiate
among progress messages. For now, the hashref only supports one key:
C<long>. If you're posting a progress notification of a process that
will take a long time, set this to 'yes' so the observer can
differentiate -- let the user know it will take a while, etc.

 sub run_task {
     my ( $self ) = @_;
     $self->_do_some_simple( 'thing' );
     $self->notify_observers( progress => 'Simple thing complete' );
     $self->_do_some_other( @stuff );
     $self->notify_observers( progress => 'Other stuff complete' );
     $self->notify_observers( progress => 'Preparing complex task',
                              { long => 'yes' } );
     $self->_do_complex_task;
     $self->notify_observers( progress => 'Complex task complete' );
     # This fires an implicit observation of type 'status'
     $self->_add_status( { is_ok   => 'yes',
                           message => 'Foobar task ok' } );
 }

This is a contrived example -- if your task is very simple (like this)
you probably don't need to bother with observations. The notifications
generated by the status messages will be more than adequate.

However, if you're looping through a set of packages, or performing a
complicated set of operations, it can be very helpful for your users
to let them know things are actually happening.

=head2 Example

Here is an example of a direct subclass that just creates a file
'hello_world' in the website directory:

 package My::Task;
 
 use strict;
 use base qw( OpenInteract2::Manage );
 
 sub param_required { return [ 'website_dir' ] }
 
 sub run_task {
     my ( $self ) = @_;
     my $website_dir = $self->param( 'website_dir' );
     $website_dir =~ s|/$||;
     my $filename = File::Spec->catfile( $website_dir, 'hello_world' );
     my %status = ();
     if ( -f $filename ) {
         $status{message} = "Could not create [$filename]: already exists";
         $status{is_ok}   = 'no';
         $self->_add_status( \%status );
         return;
     }
     eval { open( HW, "> $filename" ) || die $! };
     if ( $@ ) {
         $status{message} = "Cannot write to [$filename]: $@";
         $status{is_ok}   = 'no';
     }
     else {
         print HW "Hello from My::Task!";
         close( HW );
         $status{is_ok}   = 'yes';
         $status{message} = "File [$filename] created ok";
     }
     $self->_add_status( \%status );
 }
 
 1;

And here is how you would register and run your task:

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 OpenInteract2::Manage->register_task( hello_world => 'My::Task' );
 
 my $task = OpenInteract2::Manage->new( 'hello_world',
                                       { website_dir => $ENV{OPENINTERACT2} } );
 my @status = eval { $task->execute };
 if ( $@ ) {
     print "Task failed to run: $@";
 }
 else {
     foreach my $s ( @status ) {
         print "Task OK? $s->{is_ok}\n",
               "$s->{message}\n";
     }
 }

=head1 BUGS

None yet.

=head1 TO DO

Get everything working...

=head1 SEE ALSO

L<Class::Factory|Class::Factory>

L<OpenInteract2::Manage::Package|OpenInteract2::Manage::Package>

L<OpenInteract2::Manage::Website|OpenInteract2::Manage::Website>

L<OpenInteract2::Setup|OpenInteract2::Setup>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
