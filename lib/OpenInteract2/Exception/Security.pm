package OpenInteract2::Exception::Security;

# $Id: Security.pm,v 1.2 2003/04/26 19:55:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Exception );
use SPOPS::Secure qw( :verbose :level );

$OpenInteract2::Exception::Security::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( security_required security_found );
OpenInteract2::Exception::Security->mk_accessors( @FIELDS );

my %LEVELS = (
   SEC_LEVEL_NONE()    => SEC_LEVEL_NONE_VERBOSE,
   SEC_LEVEL_SUMMARY() => SEC_LEVEL_SUMMARY_VERBOSE,
   SEC_LEVEL_READ()    => SEC_LEVEL_READ_VERBOSE,
   SEC_LEVEL_WRITE()   => SEC_LEVEL_WRITE_VERBOSE,
);

sub get_fields { return ( $_[0]->SUPER::get_fields, @FIELDS ) }

sub to_string {
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
