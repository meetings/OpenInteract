package OpenInteract2::Exception;

# $Id: Exception.pm,v 1.6 2003/06/11 02:43:32 lachoy Exp $

use strict;
use base qw( SPOPS::Exception Exporter );
use OpenInteract2::Exception::Security;

$OpenInteract2::Exception::VERSION   = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::Exception::EXPORT_OK = qw( oi_error oi_security_error );

my @FIELDS = qw( oi_package );
OpenInteract2::Exception->mk_accessors( @FIELDS );

sub get_fields { return ( $_[0]->SUPER::get_fields(), @FIELDS ) }

sub oi_error          {
    unshift @_, __PACKAGE__;
    goto &SPOPS::Exception::throw;
}

sub oi_security_error {
    unshift @_, 'OpenInteract2::Exception::Security';
    goto &SPOPS::Exception::throw;
}


1;

__END__

=head1 NAME

OpenInteract2::Exception - Base class for exceptions in OpenInteract

=head1 SYNOPSIS

 # Standard usage

 unless ( $user->check_password( $entered_password ) ) {
   OpenInteract2::Exception->throw( 'Bad login' );
 }

 # Pass a list of strings to form the message

 unless ( $user->check_password( $entered_password ) ) {
   OpenInteract2::Exception->throw( 'Bad login', $object->login_attemplated )
 }

 # Using the exported shortcut

 use OpenInteract2::Exception qw( oi_error );
 oi_error( "Bad login", $object->login_attempted );

 # Get all errors in a particular request

 my @errors = OpenInteract2::Exception->get_stack;
 print "Errors found during request:\n";
 foreach my $e ( @errors ) {
    print "ERROR: ", $e->message, "\n";
 }

 # Also get this information from the OpenInteract2::Context:

 CTX->throw( 'Bad login' );

 my $errors = CTX->get_exceptions;
 CTX->clear_exceptions;

=head1 DESCRIPTION

First, you should probably look at
L<SPOPS::Exception|SPOPS::Exception> for more usage examples, why we
use exceptions, what they are intended for, etc.

This is the base class for all OpenInteract exceptions. It only adds a
single optional field to the L<SPOPS::Exception|SPOPS::Exception>
class, but more importantly it allows you to distinguish between
errors percolating from the data layer and errors in the application
server.

It also adds a shortcut for throwing errors via the exported routine
C<oi_error>.

=head1 PROPERTIES

In addition to the properties outlined in
L<SPOPS::Exception|SPOPS::Exception>, this object has:

B<oi_package>

List the OpenInteract package from which the exception was
thrown. This is completely optional, for informational purposes only.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Exception|SPOPS::Exception>

L<OpenInteract2::Exception::Datasource|OpenInteract2::Exception::Datasource>

L<OpenInteract2::Exception::Parameter|OpenInteract2::Exception::Parameter>

L<OpenInteract2::Exception::Security|OpenInteract2::Exception::Security>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
