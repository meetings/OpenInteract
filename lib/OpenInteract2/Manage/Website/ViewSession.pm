package OpenInteract2::Manage::Website::ViewSession;

# $Id: ViewSession.pm,v 1.5 2003/06/11 02:43:27 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Data::Dumper qw( Dumper );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$Data::Dumper::Indent = 1;

$OpenInteract2::Manage::Website::ViewSession::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'View the contents of a particular session';
}

sub list_param_require { return [ 'session_id', 'website_dir' ] }

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'session_id' ) {
        return "ID of session to view";
    }
}

sub run_task {
    my ( $self ) = @_;
    my $config     = CTX->server_config;
    my $session_id = $self->param( 'session_id' );
    my $session_class = $config->{session_info}{class};
    eval "require $session_class";
    if ( $@ ) {
        oi_error "Could not require [$session_class]: $@";
    }
    my $params  = $config->{session_params} || {};
    my $ds_name = $config->{session_info}{datasource};
    $params->{Handle} = CTX->datasource( $ds_name );
    if ( $session_class =~ /MySQL$/ ) {
        $params->{LockHandle} = $params->{Handle};
    }
    my %data = ();
    eval { tie %data, $session_class, $session_id, $params };
    my %status = ( action     => 'View Session',
                   session_id => $session_id );
    if ( $@ ) {
        $status{is_ok} = 'no';
        $status{message} = "Caught error trying to tie session: $@";
    }
    else {
        $status{is_ok} = 'yes';
        $status{message} = "Contents of session:\n" . Dumper( \%data );
    }
    $self->_add_status( \%status );
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ViewSession - View contents of a session

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'view_session', { website_dir => $website_dir,
                                        session_id  => shift @ARGV } );
 my ( $status ) = $task->execute;
 print "Session [[$status->{session_id}]]\n",
       "OK? $status->{is_ok}\n",
       "$status->{message}\n";

=head1 DESCRIPTION

This task displays the contents of a session.

=head1 STATUS MESSAGES

Only one status hashref is returned in the list. It has additional
keys:

=over 4

=item B<session_id>

The ID used to retrieve the session

=back

The B<message> key holds any errors found or the session information
as displayed by L<Data::Dumper|Data::Dumper>.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
