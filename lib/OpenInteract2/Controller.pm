package OpenInteract2::Controller;

# $Id: Controller.pm,v 1.21 2004/05/22 14:47:53 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast Class::Factory );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Controller::VERSION  = sprintf("%d.%02d", q$Revision: 1.21 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( type generator_type initial_action );
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
    $log ||= get_logger( LOG_ACTION );

    my $action = $class->_find_action( $request );
    my $impl_type = $action->controller;
    my $impl_class = $class->_get_controller_implementation_class( $impl_type );
    $log->is_debug &&
        $log->debug( "Controller for [Action: ", $action->name, "] ",
                     "to use [Controller Type: $impl_type] ",
                     "[Controller class: $impl_class]" );

    my $self = bless( {}, $impl_class );
    $self->type( $impl_type );

    $self->initial_action( $action );

    # This will probably remain undocumented for a bit... it would be
    # nice to be able to add other observers at request-time to an
    # action but I don't want to create a framework without any use
    # cases...

    # Add a filter at runtime to the main action. So you could do:
    #
    # /news/display/?news_id=55&OI_FILTER=pittsburghese
    #
    # and have the news item be translated to da burg. You could even
    # do:
    #
    # /news/display/?news_id=55&OI_FILTER=pittsburghese&OI_FILTER=bork
    #
    # and have it run through the yinzer AND the bork filter.

    my @filter_add = $request->param( 'OI_FILTER' );
    if ( scalar @filter_add ) {
        foreach my $filter_name ( @filter_add ) {
            OpenInteract2::Filter->add_filter_to_action( $filter_name, $action );
        }
    }

    # TODO: Why not do this with the class? hmm...

    my $controller_info = CTX->lookup_controller_config( $impl_type );
    $self->generator_type( $controller_info->{content_generator} );

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
    $log ||= get_logger( LOG_ACTION );

    my ( $action_name, $task_name ) =
               ( $request->action_name, $request->task_name );
    my ( $action );
    if ( $action_name ) {
        $log->is_debug &&
            $log->debug( "Trying [Action: $action_name] [Task: $task_name] ",
                         "in controller" );
        $action = eval {
            CTX->lookup_action( $action_name,
                                { REQUEST_URL => $request->url_initial } )
        };
        if ( $@ ) {
            $log->warn( "Caught exception from Context trying to lookup ",
                        "action [$action_name]: $@\nUsing action ",
                        "specified for 'notfound'" );
            $action = $NOTFOUND_ACTION->clone();
        }
        else {
            $action->task( $task_name ) if ( $task_name );
        }
    }
    else {
        $log->is_debug &&
            $log->debug( "Using action specified for 'none': ",
                         "[", $NONE_ACTION->name, "]" );
        $action = $NONE_ACTION->clone();
    }
    $log->is_debug &&
        $log->debug( 'Found action in controller ',
                     '[Action: ', $action->name, '] ',
                     '[Task: ', $action->task, ']' );
    return $action;
}

sub _get_controller_implementation_class {
    my ( $class, $controller_type ) = @_;
    $log ||= get_logger( LOG_ACTION );

    $log->is_debug &&
        $log->debug( "Lookup controller for '$controller_type'" );
    my $impl_class = eval {
        $class->get_factory_class( $controller_type )
    };
    my ( $error );
    if ( $@ ) {
        $error = "Failure to get factory class for '$controller_type': $@";
    }
    elsif ( ! $impl_class ) {
        $error = "No implementation class defined for '$controller_type'";
    }
    if ( $error ) {
        $log->error( "Cannot create controller '$controller_type': $error" );

        # TODO: Have this output a static (no template vars) file
        oi_error "Hey chuckie, you don't have a controller ",
                 "defined for type '$controller_type'";
    }
    return $impl_class;
}

sub factory_log {
    my ( $self, @msg ) = @_;
    get_logger( LOG_ACTION )->info( @msg );
}

sub factory_error {
    my ( $self, @msg ) = @_;
    get_logger( LOG_ACTION )->error( @msg );
    die @msg, "\n";
}

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

B<generator_type> - Type of content generator

B<initial_action> - The initial action used to generate content.

B<return_url> - URL to which the system should return after completing
various system tasks. It is a good idea to set this when possible so
when a user logs in she is returned to the same page.

=head1 COPYRIGHT

Copyright (c) 2001-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
