package OpenInteract2::Exception::Datasource;

# $Id: Datasource.pm,v 1.1 2002/11/17 17:24:58 lachoy Exp $

use strict;
use base qw( OpenInteract2::Exception );

$OpenInteract2::Exception::Datasource::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( datasource_name datasource_type connect_params );
OpenInteract2::Exception::Datasource->mk_accessors( @FIELDS );

sub get_fields { return ( $_[0]->SUPER::get_fields(), @FIELDS ) }

1;
