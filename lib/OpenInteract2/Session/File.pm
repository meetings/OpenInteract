package OpenInteract2::Session::File;

# $Id: File.pm,v 1.4 2003/06/11 02:43:26 lachoy Exp $

use strict;
use base qw( OpenInteract2::Session );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Session::File::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub _create_session {
    my ( $class, $session_config, $session_id ) = @_;
    my $impl_class = $session_config->{impl_class};
    my $session_params = $session_config->{params};
    DEBUG && LOG( LINFO, "Trying to fetch File session [$session_id] ",
                         "with [Dir: $session_params->{Directory}] ",
                         "[LockDir: $session_params->{LockDirectory}] ",
                         "[Impl: $impl_class]" );
    my %session = ();
    tie %session, $impl_class, $session_id, $session_params;
    return \%session;
}


sub _validate_config {
    my ( $class, $session_config ) = @_;
    my @error_msg = ();
    unless ( $session_config->{impl_class} ) {
            join( '', "Cannot use file-based session storage without the ",
                      "parameter 'session_info.impl_class' set to the",
                      "correct session implementation. (Normally: ",
                      "Apache::Session::File)" );
    }
    my $dir = $session_config->{params}{Directory};
    unless ( -d $dir ) {
        push @error_msg,
            join( '', "Server configuration key 'session_info.params.Directory' ",
                      "must refer to a valid directory. (Given: $dir)" );
    }
    my $lock_dir = $session_config->{params}{LockDirectory};
    unless ( -d $lock_dir ) {
        push @error_msg,
            join( '', "Server configuration key 'session_info.params.LockDirectory' ",
                      "must refer to a valid directory. (Given: $lock_dir)" );
    }
    return @error_msg;
}

1;

__END__

=head1 NAME

OpenInteract2::Session::File - Create sessions within a filesystem

=head1 SYNOPSIS

 # In your configuration file

 [session_info]
 class         = OpenInteract2::Session::File
 impl_class    = Apache::Session::File
 ...
 [session_info.params]
 Directory     = /home/httpd/oi/sessions/data
 LockDirectory = /home/httpd/oi/sessions/lock

=head1 DESCRIPTION

Provide a '_create_session' method for
L<OpenInteract2::Session|OpenInteract2::Session> so we can use a
filesystem as a backend for L<Apache::Session|Apache::Session>.

=head1 METHODS

B<_validate_config( $session_config )>

Ensure our configuration is valid.

=over 4

=item *

B<session_info.params.Directory> (REQUIRED)

Specify the directory in which to store sessions.

=item *

B<session_info.params.LockDirectory> (REQUIRED)

Specify the directory in which to store lock information. No default
is currently defined.

=back

B<_create_session( $session_config, [ $session_id ] )>

Overrides the method from parent
L<OpenInteract2::Session|OpenInteract2::Session>. See configuration
discussion in C<_validate_config> and in the implementation class
(e.g., L<Apache::Session::File|Apache::Session::File>.

=head1 SEE ALSO

L<Apache::Session::File|Apache::Session::File>

L<OpenInteract2::Session|OpenInteract2::Session>

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
