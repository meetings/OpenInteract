package OpenInteract2::Auth::Group;

# $Id: Group.pm,v 1.7 2003/06/24 03:35:38 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Auth::Group::VERSION  = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub get_groups {
    my ( $class, $user, $is_logged_in ) = @_;
    my $log = get_logger( LOG_AUTH );
    unless ( $is_logged_in ) {
        $log->is_debug &&
            $log->debug( "No logged-in user found, not retrieving groups." );
        return;
    }
    $log->is_debug &&
        $log->debug( "Authenticated user exists; getting groups." );

    # is group in the session?

    my $group_refresh = CTX->server_config->{session_info}{cache_group};
    my $groups = $class->get_cached_groups( $group_refresh );

    return $groups if ( $groups );

    # no, fetch from user record

    $groups = eval { $user->group({ skip_security => 'yes' }) };
    if ( $@ ) {
        $log->error( "Failed to fetch groups from ",
                     "[User: $user->{login_name}]: $@" );
    }

    # set group in session (as necessary)
    $class->set_cached_groups( $groups, $group_refresh );
    return $groups;
}


sub get_cached_groups {
    my ( $class, $group_refresh ) = @_;
    return unless ( $group_refresh > 0 );
    my $log = get_logger( LOG_AUTH );
    my $groups = [];
    my $session = CTX->request->session;
    if ( $groups = $session->{_oi_cache}{group} ) {
        if ( time < $session->{_oi_cache}{group_refresh_on} ) {
            $log->is_debug &&
                $log->debug( "Got groups from session ok" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Group session cache expired; refreshing from db" );
            delete $session->{_oi_cache}{group};
            delete $session->{_oi_cache}{group_refresh_on};
        }
    }
    return $groups;
}

sub set_cached_groups {
    my ( $class, $groups, $group_refresh ) = @_;
    unless ( ref $groups eq 'ARRAY'
                 and scalar @{ $groups } > 0
                 and $group_refresh > 0 ) {
        return;
    }
    my $log = get_logger( LOG_AUTH );
    my $session = CTX->request->session;
    $session->{_oi_cache}{group} = $groups;
    $session->{_oi_cache}{group_refresh_on} = time + ( $group_refresh * 60 );
    $log->is_debug &&
        $log->debug( "Set groups to session cache, expires in ",
                     "[$group_refresh] minutes" );
}

1;

__END__

=head1 NAME

OpenInteract2::Auth::Group - Retreive groups into OpenInteract

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
