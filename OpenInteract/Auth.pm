package OpenInteract::Auth;

# $Id: Auth.pm,v 1.5 2001/08/27 22:09:48 lachoy Exp $

use strict;
use Data::Dumper qw( Dumper );

@OpenInteract::Auth::ISA     = ();
$OpenInteract::Auth::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);


# Authenticate a user -- after calling this method if
# $R->{auth}->{logged_in} is true then $R->{auth}->{user} will be a
# user object.

sub user {
    my ( $class ) = @_;
    my $R = OpenInteract::Request->instance;
    if ( my $uid = $R->{session}{user_id} ) {
        $R->DEBUG && $R->scrib( 1, "Found session and uid ($uid); creating user." );

        # You MUST skip security here as a bootstrapping maneuver,
        # otherwise the superuser can never login (since WORLD has
        # SEC_LEVEL_NONE to the record)

        $R->{auth}{user} = eval { $R->user->fetch( $uid,
                                                     { skip_security => 1 } ) };

        # If there's a failure fetching the user, we need to ensure that
        # this user_id is not passed back to us again so we don't keep
        # going through this process...

        if ( $@ or ! $R->{auth}{user} ) {
            OpenInteract::Error->set( SPOPS::Error->get );
            $R->throw({ code => 311 });
            $R->{session}{user_id} = undef;
            return undef;
        }

        # We use this to note that the user is logged in, since we'll
        # shortly modify OI to create a record for a 'not-logged-in' user
        # instead of leaving it empty.

        $R->{auth}{logged_in} = 1;

        $R->DEBUG && $R->scrib( 2, "User: ", Dumper( $R->{auth}->{user} ) );
        $R->DEBUG && $R->scrib( 1, "User found: $R->{auth}->{user}->{login_name}" );

        # If there's a removal date, then this is the user's first
        # login

        # TODO: Check if this is working, if it's needed, ...

        if ( $R->{auth}{user}{removal_date} ) {
            $R->DEBUG && $R->scrib( 1, "First login for user! Do some cleanup." );
            $R->{auth}{user}{removal_date} = undef;

            # blank out the removal date -- note that this doesn't seem to
            # work properly, and put the user in the public group

            eval {
                $R->{auth}{user}->save;
                $R->{auth}{user}->make_public;
            };

            # need to check for save/security errors here
        }
        return undef;
    }
    $R->DEBUG && $R->scrib( 1, "No uid found in session. Finding login info." );

    # If the user didn't previously exist, try to create
    # from the fields login_name and password

    my $login_field    = $R->CONFIG->{login}{login_field};
    my $password_field = $R->CONFIG->{login}{password_field};
    my $remember_field = $R->CONFIG->{login}{remember_field};
    unless ( $login_field and $password_field ) {
        $R->throw({ code => 205, type => 'system' });
        return undef;
    }

    my $login_name = $R->apache->param( $login_field );
    return undef unless ( $login_name );
    $R->DEBUG && $R->scrib( 1, "Found login name from form: <<$login_name>>" );
    my $user = eval { $R->user->fetch_by_login_name( $login_name,
                                                     { return_single => 1,
                                                       skip_security => 1 } ) };
    if ( $@ ) {
      my $ei = SPOPS::Error->get;
      $R->scrib( 0, "Error when fetching by login name: $ei->{system_msg}\n" );
    }
    unless ( $user ) {
        $R->scrib( 0, "User with login ($login_name) not found. Throwing auth error" );
        $R->throw({ code  => 401,
                    type  => 'authenticate', 
                    extra => { login_name => $login_name } });
        return undef;
    }

    # Check the password

    my $password   = $R->apache->param( $password_field );
    $R->DEBUG && $R->scrib( 5, "Password entered: <<$password>>" );
    unless ( $user->check_password( $password ) ) {
        $R->scrib( 0, "Password check for ($login_name) failed. Throwing auth error" );
        $R->throw({ code  => 402,
                    type  => 'authenticate',
                    extra => { login_name => $login_name } });
        return undef;
    }
    $R->DEBUG && $R->scrib( 1, "Passwords matched; UID ($user->{user_id})" );

    # If the user was matched up to a login_name and the password
    # matched, put the user_id into the session and put the user into
    # $R. Also, make the expiration transient (expires when browser
    # closes) unless the user clicked the 'Remember Me' checkbox

    unless ( $R->apache->param( $remember_field ) ) {
        $R->{session}{expiration} = '';
    }
    $R->{auth}{logged_in} = 1;
    $R->{session}{user_id} = $user->id;
    $R->{auth}{user} = $user;
    return undef;
}


# If the user is logged in, retrieve the groups he/she/it belongs to

sub group {
    my ( $class ) = @_;
    my $R = OpenInteract::Request->instance;
    unless ( $R->{auth}{logged_in} ) {
        $R->DEBUG && $R->scrib( 1, "No logged-in user found, not retrieving groups." );
        return undef;
    }
    $R->DEBUG && $R->scrib( 1, "Authenticated user exists; getting groups." );
    $R->{auth}{group} = eval { $R->{auth}{user}->group };
    if ( $@ ) {
        OpenInteract::Error->set( SPOPS::Error->get );
        $R->throw({ code => 309 });
    }
    else {
        $R->DEBUG && $R->scrib( 2, "Retrieved groups: ",
                                   join( ', ', map { "($_->{name})" } @{ $R->{auth}{group} } ) );
    }
    return undef;
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Auth - Authenticate the user object and create its groups

=head1 SYNOPSIS

 # Authenticate the user based on the session information
 # or the login information

 OpenInteract::Auth->user;

 # Fetch the groups for the logged-in user

 OpenInteract::Auth->group;

=head1 DESCRIPTION

This class is responsible for authenticating users to the system. It
does this in one of two ways:

=over 4

=item 1.

Find the user_id in their session information and create a user object
from it.

=item 2.

Find the $LOGIN_FIELD and $PASSWORD_FIELD arguments passed in via
GET/POST and try to create a user with that login name and check the
password.

=back

If either of these is successful, then we create a user object and put
it into:

 $R->{auth}->{user}

where it can be retrieved by all other handlers, modules, etc.

The class also creates an arrayref of groups the user belongs to.

=head1 METHODS

Neither of these methods returns a value that reflects what they
did. Their success is judged by whether $R has entries for the user
and groups.

B<user()>

Creates a user object by whatever means possible and puts it into:

 $R->{auth}->{user}

Note that we also set:

 $R->{auth}->{logged_in}

which should be used to see whether the user is logged in or not. We
will be changing the interface slightly so that you can no longer just
check to see if $R-E<gt>{auth}-E<gt>{user} is defined. It will be
defined with the 'not-logged-in' user to prevent some a nasty bug from
happening.

In this method we check to see whether the user has typed in a new
username and password. By default, the method will check in the
variables 'login_login_name' for the username and 'login_password' for
the password. (Both are stored as constants in this module.)

However, you can define your own variable names in your
C<conf/server.perl> file. Just set:

 {
   login => { login_name => 'xxx',
              password   => 'xxx' },
 }

(If you modify the template for logging in to have new names under the
'INPUT' variables you will want to change these.)

B<group()>

If a user object has been created, this fetches the groups the user
object belongs to and puts the arrayref of groups into:

 $R->{auth}->{group}

=head1 TO DO

B<Ticket handling>

We should put checks in here to allow an application to check
for expired authentication tickets, or to allow a module to add an
authentication handler as a callback which implements its own logic
for this.

=head1 BUGS

None known.

=head1 SEE ALSO

L<OpenInteract::User>

L<OpenInteract::Group>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
