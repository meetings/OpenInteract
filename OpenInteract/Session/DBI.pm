package OpenInteract::Session::DBI;

# $Id: DBI.pm,v 1.1 2001/07/11 12:33:04 lachoy Exp $

use strict;

@OpenInteract::Session::DBI::ISA     = qw( OpenInteract::Session );
$OpenInteract::Session::DBI::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub _create_session { 
    my ( $class, $session_id ) = @_;
    my $R = OpenInteract::Request->instance;
    my $session_class = $R->CONFIG->{session_info}->{class};
    my $session_params = $R->CONFIG->{session_info}->{params} || {};
    my %session = ();
    $R->DEBUG && $R->scrib( 1, "Trying to fetch session $session_id" );
    eval { 
        tie %session, $session_class, $session_id, 
                      { Handle => $R->db, %{ $session_params } }
    };
    if ( $@ ) {
        $R->throw( { code       => 310, type => 'session',
                     system_msg => $@,
                     extra      => { class      => $session_class, 
                                     session_id => $session_id } } );
        $R->scrib( 0, "Error thrown. Now clear the cookie" );
        return undef;
    }
    return \%session;
}

1;


__END__

=pod

=head1 NAME

OpenInteract::Session::DBI - Create sessions within a DBI data source

=head1 DESCRIPTION

Provide a '_create_session' method for L<OpenInteract::Session> so we
can use a DBI data source as a backend for L<Apache::Session>.

Note that failure to create the session throws a '310' error, which
clears out the session cookie so it does not keep happening. (See
L<OpenInteract::Error::System> for the code.)

=head1 METHODS

B<_create_session( $session_id )>

Overrides the method from parent C<OpenInteract::Session>.

=head1 BUGS 

None known.

=head1 TO DO

Nothing.

=head1 SEE ALSO

L<Apache::Session>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
