package OpenInteract::Session::DBI;

# $Id: DBI.pm,v 1.7 2002/01/02 02:43:53 lachoy Exp $

use strict;
use OpenInteract::Session;

@OpenInteract::Session::DBI::ISA     = qw( OpenInteract::Session );
$OpenInteract::Session::DBI::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub _create_session {
    my ( $class, $session_id ) = @_;
    my $R = OpenInteract::Request->instance;
    my $session_class  = $R->CONFIG->{session_info}{class};
    my $session_params = $R->CONFIG->{session_info}{params} || {};
    $session_params->{Handle} = $R->db( 'main' );

    # Detect Apache::Session::MySQL and modify parameters
    # appropriately

    if ( $session_class =~ /MySQL$/ ) {
        $session_params->{LockHandle} = $session_params->{Handle};
        $R->DEBUG && $R->scrib( 2, "Using MySQL session store, with LockHandle parameter" );
    }
    my %session = ();
    $R->DEBUG && $R->scrib( 1, "Trying to fetch session $session_id" );
    eval { tie %session, $session_class, $session_id, $session_params };
    if ( $@ ) {
        $R->throw({ code       => 310,
                    type       => 'session',
                    system_msg => $@,
                    extra      => { class      => $session_class,
                                    session_id => $session_id } });
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

Note that former users of C<OpenInteract::Session::MySQL> (now
defunct) should have no problems using this class -- just specify the
'session_class' as C<Apache::Session::MySQL> and everything should
work smoothly.

=head1 METHODS

B<_create_session( $session_id )>

Overrides the method from parent C<OpenInteract::Session>.

=head1 CONFIGURATION

The following configuration keys are used:

=over 4

=item *

B<session_info::class> ($)

Specify the session serialization implementation class -- e.g.,
C<Apache::Session::MySQL>, C<Apache::Session::Postgres>,
C<Apache::Session::File>.

=item *

B<session_info::params> (\%) (optional)

Parameters that get passed directly to the session serialization
implementation class.

=back

=head1 BUGS

None known.

=head1 TO DO

Nothing.

=head1 SEE ALSO

L<Apache::Session>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
