package OpenInteract2::Controller;

# $Id: Controller.pm,v 1.8 2003/06/11 02:43:32 lachoy Exp $

use strict;
use base qw( Class::Accessor Class::Factory );
use OpenInteract2::Context   qw( DEBUG LOG CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

my @FIELDS = qw( type return_url initial_action request response );
__PACKAGE__->mk_accessors( @FIELDS );

my ( $NONE_ACTION, $NOTFOUND_ACTION );

sub initialize_default_actions {
    my ( $class ) = @_;
    return if ( $NONE_ACTION and $NOTFOUND_ACTION );
    $NONE_ACTION     = CTX->lookup_action_none;
    $NOTFOUND_ACTION = CTX->lookup_action_not_found;
}

sub new {
    my ( $class, $request, $response ) = @_;
    my $action = $class->_find_action( $request );
    my $impl_class = $class->_find_controller_implementation_class( $action );
    DEBUG && LOG( LDEBUG, "Controller for [Action: ", $action->name, "] ",
                          "to use [Class: $impl_class]" );

    my $self = bless( {}, $impl_class );
    $self->initial_action( $action );
    $self->type( $action->content_generator );
    $self->request( $request );
    $self->response( $response );
    $self->init;

    CTX->controller( $self );
    return $self;
}

sub init { return $_[0] }

sub execute {
    my $class = ref( $_[0] ) || $_[0];
    oi_error "Subclass [$class] must override execute()";
}


# Ask the request for the action and task name, then lookup the
# action. If it's defined and found use it; if it's defined and not
# found, use the $NOTFOUND_ACTION; if it's not defined use the
# $NONE_ACTION.

sub _find_action {
    my ( $class, $request ) = @_;
    my ( $action_name, $task_name ) =
               ( $request->action_name, $request->task_name );
    my ( $action );
    if ( $action_name ) {
        DEBUG && LOG( LDEBUG, "Trying action [$action_name -> $task_name] ",
                              "in controller" );
        $action = eval {
            CTX->lookup_action( $action_name,
                                { REQUEST_URL => $request->url_initial } )
        };
        if ( $@ ) {
            LOG( LWARN, "Caught exception from Context trying to looking ",
                        "up action [$action_name]: $@\nUsing action ",
                        "specified for 'notfound'" );
            $action = OpenInteract2::Action->new( $NOTFOUND_ACTION );
        }
        else {
            $action->task( $task_name );
        }
    }
    else {
        DEBUG && LOG( LDEBUG, "Using action specified for 'none': ",
                              $NONE_ACTION->name );
        $action = OpenInteract2::Action->new( $NONE_ACTION );
    }
    DEBUG && LOG( LDEBUG, 'Found action in controller [Name: ',
                          $action->name, '] [Task: ', $action->task, ']' );
    return $action;
}

sub _find_controller_implementation_class {
    my ( $class, $action ) = @_;
    my $generator_type = $action->content_generator;
    DEBUG && LOG( LDEBUG, "Lookup controller for [$generator_type]" );
    my $impl_class = eval {
        $class->get_factory_class( $generator_type )
    };
    my ( $error );
    if ( $@ ) {
        $error = "Failure to get factory class for [$generator_type]: $@";
    }
    elsif ( ! $impl_class ) {
        $error = "No implementation class defined for [$generator_type]";
    }
    if ( $error ) {
        DEBUG && LOG( LERROR, "Error getting controller for ",
                              "action: ", $action->name, ": $error" );

        # TODO: Have this output a static (no template vars) file
        oi_error "Hey chuckie, you don't have a content ",
                 "generator defined for action: ", $action->name;
    }
    return $impl_class;
}

# Note: These won't actually get loaded until someone tries to use them.

__PACKAGE__->register_factory_type(
               raw  => 'OpenInteract2::Controller::Raw' );
__PACKAGE__->register_factory_type(
               TT   => 'OpenInteract2::Controller::HTML' );
__PACKAGE__->register_factory_type(
               HTML => 'OpenInteract2::Controller::HTML' );
__PACKAGE__->register_factory_type(
               SOAP => 'OpenInteract2::Controller::SOAP' );

1;

__END__

=head1 NAME

OpenInteract2::Controller - Top-level controller to generate and place content

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 PROPERTIES

B<request> - The current
L<OpenInteract2::Request|OpenInteract2::Request> object

B<response> - The current
L<OpenInteract2::Response|OpenInteract2::Response> object

B<type> - Type of controller

B<initial_action> - The initial action used to generate content.

B<return_url> - URL to which the system should return after completing
various system tasks. It is a good idea to set this when possible so
when a user logs in she is returned to the same page.

B<page_title> - Title of the page to be generated.

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
