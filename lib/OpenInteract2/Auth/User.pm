package OpenInteract2::Auth::User;

# $Id: User.pm,v 1.6 2003/06/11 02:43:31 lachoy Exp $

use strict;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );

$OpenInteract2::Auth::User::VERSION  = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

sub get_user {
    my ( $class ) = @_;
    my $server_config = CTX->server_config;
    my ( $user, $user_id, $is_logged_in );

    # Check to see if the user is in the session

    my $user_refresh = $server_config->{session_info}{cache_user};
    ( $user, $user_id ) = $class->get_cached_user( $user_refresh );
    if ( $user ) {
        $is_logged_in++;
    }
    else {
        $user_id ||= $class->get_user_id;
        if ( $user_id ) {
            DEBUG && LOG( LDEBUG, "Found user ID [$user_id]; fetching user" );
            $user = eval { $class->fetch_user( $user_id ) };

            # If there's a failure fetching the user, we need to ensure that
            # this user_id is not passed back to us again so we don't keep
            # going through this process...

            if ( $@ or ! $user ) {
                my $error = $@ || 'User not found';
                $class->fetch_user_failed( $user_id, $error );
            }
            else {
                DEBUG && LOG( LDEBUG, "User found [$user->{login_name}]" );
                $class->check_first_login( $user );
                $class->set_cached_user( $user, $user_refresh );
                $is_logged_in++;
            }
        }
    }

    if ( $user ) {
        return ( $user, $is_logged_in );
    }

    DEBUG && LOG( LDEBUG, "No user ID found in session. Finding login..." );

    # If no user info found, check to see if the user logged in

    $user = $class->login_user_from_input;

    # If so, see if it's the first one and if we should 'remember' the
    # user (just changes the session expiration)

    if ( $user ) {
        $class->check_first_login( $user );
        $class->remember_login( $user );
        $class->set_cached_user( $user, $user_refresh );
        $is_logged_in++;
    }

    # If not, create a nonpersisted 'empty' user

    else {
        DEBUG && LOG( LDEBUG, "Creating the not-logged-in user." );
        my $session = CTX->request->session;
        if ( $session ) {
            delete $session->{user_id};
        }
        $user = $class->create_nologin_user;
    }
    return ( $user, $is_logged_in );
}


# TODO: I don't like that this returns a user and user_id...

sub get_cached_user {
    my ( $class, $user_refresh ) = @_;
    return unless ( $user_refresh > 0 );
    my ( $user, $user_id );
    my $session = CTX->request->session;
    if ( $user = $session->{_oi_cache}{user} ) {
        if ( time < $session->{_oi_cache}{user_refresh_on} ) {
            DEBUG && LOG( LDEBUG, "Got user from session ok" );
        }

        # If we need to refresh the user object, pull the id out
        # so we know what to refresh...

        else {
            DEBUG && LOG( LDEBUG, "User session cache expired" );
            $user_id = $user->id;
            delete $session->{_oi_cache}{user};
            delete $session->{_oi_cache}{user_refresh_on};
            $user = undef;
        }
    }
    return ( $user, $user_id );
}


# Just grab the user_id from somewhere

sub get_user_id {
    my ( $class ) = @_;
    my $session = CTX->request->session;
    return ( $session ) ? $session->{user_id} : undef;
}


# Use the user_id to create a user (don't use eval {} around the
# fetch(), this should die if it fails)

sub fetch_user {
    my ( $class, $user_id ) = @_;
    return CTX->lookup_object( 'user' )
              ->fetch( $user_id, { skip_security => 1 } );
}


# What to do if the user fetch fails

sub fetch_user_failed {
    my ( $class, $user_id, $error ) = @_;
    LOG( LERROR, "Failed to fetch user [$user_id]: $error" );
    CTX->request->session->{user_id} = undef;
}


# If no user found elsewhere, see if a login_name and password were
# passed in; if so, try and login the user and track the info

sub login_user_from_input {
    my ( $class ) = @_;
    my $server_config = CTX->server_config;

    my $login_field    = $server_config->{login}{login_field};
    my $password_field = $server_config->{login}{password_field};
    unless ( $login_field and $password_field ) {
        LOG( LERROR, "No login/password field configured; please set ",
                     "server configuration keys 'login.login_field' and ",
                     "'login.password_field'" );
        return undef;
    }

    my $request = CTX->request;
    my $login_name = $request->param( $login_field );
    unless ( $login_name ) {
        LOG( LDEBUG, "No login name found" );
        return undef;
    }
    DEBUG && LOG( LDEBUG, "Found login name [$login_name]" );

    my $user = eval { CTX->lookup_object( 'user' )
                         ->fetch_by_login_name( $login_name,
                                                { return_single => 1,
                                                  skip_security => 1 } ) };
    if ( $@ ) {
      LOG( LERROR, "Error fetching user by login name: $@" );
    }

    # TODO: implement error handling/message passing here
    unless ( $user ) {
        LOG( LWARN, "User with login [$login_name] not found." );
        return undef;
    }

    # Check the password

    my $password   = $request->param( $password_field );

    # TODO: implement error handling/message passing here
    unless ( $user->check_password( $password ) ) {
        LOG( LWARN, "Password check for [$login_name] failed" );
        return undef;
    }
    DEBUG && LOG( LDEBUG, "Passwords matched for UID ", $user->id );

    return $user;
}


# If there's a removal date, then this is the user's first login

# TODO: Check if this is working, if it's needed, ...

sub check_first_login {
    my ( $class, $user ) = @_;
    return unless ( $user->{removal_date} );

    # blank out the removal date and put the user in the public group

    DEBUG && LOG( LDEBUG, "First login for user! Do some cleanup." );
    $user->{removal_date} = undef;

    eval {
        $user->save({ skip_security => 1 });
        $user->make_public;
    };
    if ( $@ ) {
        LOG( LERROR, "Failed to save new user info at first login: $@" );
    }
}

# If we created a user, make the expiration transient unless told otherwise.

sub remember_login {
    my ( $class, $user ) = @_;
    my $server_config = CTX->server_config;
    if ( $server_config->{login}{always_remember} ) {
        DEBUG && LOG( LDEBUG, "Configured to always remember users" );
        return;
    }

    my $request = CTX->request;
    my $remember_field = $server_config->{login}{remember_field};
    unless ( $remember_field and $request->param( $remember_field ) ) {
        DEBUG && LOG( LDEBUG, "Not remembering user" );
        $request->session->{expiration} = undef;
    }
}

# Create a 'dummy' user

sub create_nologin_user {
    my ( $class ) = @_;
    my $default_theme_id = CTX->server_config->{default_objects}{theme};
    return CTX->lookup_object( 'user' )
              ->new({ login_name => 'anonymous',
                      first_name => 'Anonymous',
                      last_name  => 'User',
                      theme_id   => $default_theme_id,
                      user_id    => 99999 });
}

sub set_cached_user {
    my ( $class, $user, $user_refresh ) = @_;
    return unless ( $user_refresh > 0 );
    my $session = CTX->request->session;
    $session->{_oi_cache}{user} = $user;
    $session->{_oi_cache}{user_refresh_on} = time + ( $user_refresh * 60 );
    DEBUG && LOG( LDEBUG, "Set user to session cache, expires in ",
                          "[$user_refresh] minutes" );
}



1;

__END__

=head1 NAME

OpenInteract::Auth::User - Base class for creating OpenInteract users

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
