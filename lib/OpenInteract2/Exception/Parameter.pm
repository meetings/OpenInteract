package OpenInteract2::Exception::Parameter;

# $Id: Parameter.pm,v 1.5 2004/02/18 05:25:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Exception Class::Accessor::Fast );

$OpenInteract2::Exception::Parameter::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( parameter_fail );
OpenInteract2::Exception::Parameter->mk_accessors( @FIELDS );
sub Fields { return @FIELDS }

sub full_message {
    my ( $self ) = @_;
    my $failures = $self->parameter_fail;
    my $valid_msg = join( '; ', map { "$_: " . $failures->{ $_ } } keys %{ $failures } );
    return "One or more parameters were not valid: $valid_msg";
}

1;

__END__

=head1 NAME

OpenInteract2::Exception::Parameter - Parameter exceptions

=head1 SYNOPSIS

 # Use the shortcut
 
 use OpenInteract2::Exception qw( oi_param_error );
 use SPOPS::Secure qw( :level );
 
 oi_security_error "Validation failure",
                   { field_one => "Not enough characters (found: 15)",
                     field_two => "Too many vowels (found: 5)" };

=head1 DESCRIPTION

Custom exception for parameter violations.

=head1 SEE ALSO

L<OpenInteract2::Exception|OpenInteract2::Exception>

L<Exception::Class|Exception::Class>

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
