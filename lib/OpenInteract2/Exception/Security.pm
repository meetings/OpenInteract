package OpenInteract2::Exception::Security;

# $Id: Security.pm,v 1.4 2003/06/25 14:39:01 lachoy Exp $

use strict;
use base qw( OpenInteract2::Exception Class::Accessor );
use SPOPS::Secure qw( :verbose :level );

$OpenInteract2::Exception::Security::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( security_required security_found );
OpenInteract2::Exception::Security->mk_accessors( @FIELDS );
sub Fields { return @FIELDS }

my %LEVELS = (
   SEC_LEVEL_NONE()    => SEC_LEVEL_NONE_VERBOSE,
   SEC_LEVEL_SUMMARY() => SEC_LEVEL_SUMMARY_VERBOSE,
   SEC_LEVEL_READ()    => SEC_LEVEL_READ_VERBOSE,
   SEC_LEVEL_WRITE()   => SEC_LEVEL_WRITE_VERBOSE,
);

sub full_message {
    my ( $self ) = @_;
    my $req = ( $self->security_required )
                ? $LEVELS{ $self->security_required }
                : 'none specified';
    my $fnd = ( $self->security_found )
                ? $LEVELS{ $self->security_found }
                : 'none specified';
    return "Security violation. Object requires [$req] but got [$fnd]";
}

1;

__END__

=head1 NAME

OpenInteract2::Exception::Security - Security exceptions

=head1 SYNOPSIS

 # Use the shortcut
 
 use OpenInteract2::Exception qw( oi_security_error );
 use SPOPS::Secure qw( :level );
 
 oi_security_error "Cannot fetch object",
                   { security_found => SEC_LEVEL_READ,
                     security_required => SEC_LEVEL_WRITE };
 
 # Be explicity
 
 use OpenInteract2::Exception::Security;
 use SPOPS::Secure qw( :level );
 
 OpenInteract2::Exception::Security->throw(
                    "Cannot fetch object",
                    { security_found => SEC_LEVEL_READ,
                      security_required => SEC_LEVEL_WRITE } );

=head1 DESCRIPTION

Custom exception for security violations.

=head1 SEE ALSO

L<OpenInteract2::Exception|OpenInteract2::Exception>

L<Exception::Class|Exception::Class>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
