package OpenInteract2::Exception::Parameter;

# $Id: Parameter.pm,v 1.1 2002/11/17 17:24:58 lachoy Exp $

# TODO: Add tests to exception.t

use strict;
use base qw( OpenInteract2::Exception );

$OpenInteract2::Exception::Parameter::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( parameter_fail );
OpenInteract2::Exception::Parameter->mk_accessors( @FIELDS );
sub get_fields { return ( $_[0]->SUPER::get_fields, @FIELDS ) }

1;
