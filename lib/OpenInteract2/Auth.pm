package OpenInteract2::Auth;

# $Id: Auth.pm,v 1.8 2003/06/24 03:35:37 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Auth::VERSION  = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

my ( $AUTH_USER_CLASS, $AUTH_GROUP_CLASS, $AUTH_ADMIN_CLASS );
my ( $USE_CUSTOM, $CUSTOM_CLASS, $CUSTOM_METHOD, $CUSTOM_FAIL_METHOD );

sub login {
    my ( $class, $user, $groups ) = @_;
    unless ( $AUTH_USER_CLASS and $AUTH_GROUP_CLASS and $AUTH_ADMIN_CLASS ) {
        $class->_include_impl_classes;
    }

    my $log = get_logger( LOG_AUTH );
    my $request = CTX->request;

    my ( $is_logged_in );

    if ( $user ) {
        $is_logged_in = 'yes';
    }
    else {
        ( $user, $is_logged_in ) = $AUTH_USER_CLASS->get_user;
    }

    # TODO: Throw exception here?

    unless ( $user ) {
        $log->error( "No user returned from [$AUTH_USER_CLASS]" );
        return;
    }
    $request->auth_user( $user );
    $request->auth_is_logged_in( $is_logged_in );

    # Now that we have the user created we can create the theme

    $request->create_theme;

    unless ( ref $groups eq 'ARRAY' ) {
        $groups = $AUTH_GROUP_CLASS->get_groups( $user, $is_logged_in );
    }
    return unless ( ref $groups eq 'ARRAY' );
    $request->auth_group( $groups );

    my $is_admin = $AUTH_ADMIN_CLASS->is_admin( $user, $is_logged_in, $groups );
    $request->auth_is_admin( $is_admin );

    $class->run_custom_handler( $user, $is_logged_in, $groups, $is_admin );
}

sub run_custom_handler {
    my ( $class,  $user, $is_logged_in, $groups, $is_admin ) = @_;
    my $log = get_logger( LOG_AUTH );
    unless ( $USE_CUSTOM ) {
        $USE_CUSTOM = $class->_include_custom_class;
    }
    return if ( $USE_CUSTOM eq 'no' );
    $log->is_debug &&
        $log->debug( "Custom login handler/method being used: ",
                          "[$CUSTOM_CLASS] [$CUSTOM_METHOD]" );
    eval {
        $CUSTOM_CLASS->$CUSTOM_METHOD(
                $user, $is_logged_in, $groups, $is_admin )
    };
    if ( $@ ) {
        $log->error( "Custom login handler died with: $@" );
        if ( $CUSTOM_FAIL_METHOD ) {
            $log->is_debug &&
                $log->debug( "Custom login handler failure method: ",
                          "[$CUSTOM_CLASS] [$CUSTOM_FAIL_METHOD]" );
            eval {
                $CUSTOM_CLASS->$CUSTOM_FAIL_METHOD(
                        $user, $is_logged_in, $groups, $is_admin )
            };
            if ( $@ ) {
                $log->error( "Custom login handler failure method ",
                             "died with: $@" );
            }
        }
    }
}

sub _include_impl_classes {
    my ( $class ) = @_;
    $AUTH_USER_CLASS = CTX->server_config->{login}{auth_user_class};
    eval "require $AUTH_USER_CLASS";
    if ( $@ ) {
        oi_error "Failed to require user auth class $AUTH_USER_CLASS";
    }
    $AUTH_GROUP_CLASS = CTX->server_config->{login}{auth_group_class};
    eval "require $AUTH_GROUP_CLASS";
    if ( $@ ) {
        oi_error "Failed to require group auth class $AUTH_GROUP_CLASS";
    }
    $AUTH_ADMIN_CLASS = CTX->server_config->{login}{auth_admin_class};
    eval "require $AUTH_ADMIN_CLASS";
    if ( $@ ) {
        oi_error "Failed to require admin auth class $AUTH_ADMIN_CLASS";
    }
}

sub _include_custom_class {
    my ( $class ) = @_;
    my $log = get_logger( LOG_AUTH );
    my $server_config = CTX->server_config;
    $CUSTOM_CLASS = $server_config->{login}{custom_handler};
    unless ( $CUSTOM_CLASS ) {
        return 'no';
    }
    eval "require $CUSTOM_CLASS";
    if ( $@ ) {
        $log->error( "Tried to use custom login handler [$CUSTOM_CLASS]",
                     "but requiring the class failed: $@" );
        return 'no';
    }
    $CUSTOM_METHOD = $server_config->{login}{custom_method}
                     || 'handler';
    $CUSTOM_FAIL_METHOD = $server_config->{login}{custom_fail_method};
    return 'yes';
}

1;

__END__

=head1 NAME

OpenInteract2::Auth - Base class for logging in OpenInteract users

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
