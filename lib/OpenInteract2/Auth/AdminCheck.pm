package OpenInteract2::Auth::AdminCheck;

# $Id: AdminCheck.pm,v 1.5 2003/06/24 03:35:38 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Auth::AdminCheck::VERSION  = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub is_admin {
    my ( $class, $user, $is_logged_in, $groups ) = @_;
    my $log = get_logger( LOG_AUTH );
    unless ( $is_logged_in ) {
        $log->is_debug &&
            $log->debug( "User not logged in: NOT admin" );
        return 0;
    }
    my $server_config = CTX->server_config;
    if ( $user->id eq $server_config->{default_objects}{superuser} ) {
        $log->is_debug &&
            $log->debug( "User is superuser: IS admin" );
        return 1;
    }

    my $site_admin_id = $server_config->{default_objects}{site_admin_group};
    my $supergroup_id = $server_config->{default_objects}{supergroup};
    foreach my $group ( @{ $groups } ) {
        my $group_id = $group->id;
        if ( $group_id eq $site_admin_id or $group_id eq $supergroup_id ) {
            $log->is_debug &&
                $log->debug( "User in group [$group_id]: IS admin" );
            return 1;
        }
    }
    return 0;
}

1;

__END__

=head1 NAME

OpenInteract2::Auth::AdminCheck - See whether user is admin

=head1 SYNOPSIS

 # Set admin users/groups in server config
 [default_objects]
 superuser        = 1
 supergroup       = 1
 site_admin_group = 3

=head1 DESCRIPTION

B<is_admin( $user, $is_logged_in, \@groups )>

Returns true if C<$user> is superuser or if an admin group is passed
in C<\@groups>.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
