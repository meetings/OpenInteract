package OpenInteract::SPOPS::DBI;

# $Id: DBI.pm,v 1.5 2001/08/12 18:00:19 lachoy Exp $

use strict;
use OpenInteract::SPOPS;

@OpenInteract::SPOPS::DBI::ISA     = qw( OpenInteract::SPOPS );
$OpenInteract::SPOPS::DBI::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub global_datasource_handle {
    my ( $self, $connect_key ) = @_;
    return OpenInteract::Request->instance->db( $connect_key );
}

sub global_db_handle { goto &global_datasource_handle }

sub connection_info {
    my ( $self, $connect_key ) = @_;
    my $R = OpenInteract::Request->instance;
    $connect_key ||= $self->CONFIG->{datasource} || $R->CONFIG->{default_connection_db};
    $connect_key = $connect_key->[0] if ( ref $connect_key eq 'ARRAY' );
    return \%{ $self->CONFIG->{db_info}->{ $connect_key } };
}

1;

=pod

=head1 NAME

OpenInteract::SPOPS::DBI - Common SPOPS::DBI-specific methods for objects

=head1 SYNOPSIS

 # In configuration file
 'myobj' => {
    'isa'   => [ qw/ ... OpenInteract::SPOPS::DBI ... / ],
 }

=head1 DESCRIPTION

This class provides common datasource access methods required by
L<SPOPS::DBI>.

=head1 METHODS

B<global_datasource_handle( [ $connect_key ] )>

Returns a DBI handle corresponding to the connection key
C<$connect_key>. If C<$connect_key> is not given, then the default
connection key is used. This is specified in the server configuration
file under the key 'default_connection_db'.

B<global_db_handle( [ $connect_key ] )>

Alias for C<global_datasource_handle()> (kept for backward
compatibility).

B<connection_info( [ $connect_key ] )>

Returns a hashref of DBI connection information. If no C<$connect_key>
is given then we get the value of 'datasource' from the object
configuration, and if that is not defined we get the default
datasource from the server configuration.

See the server configuration file for documentation on what is in the
hashref.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::DBI>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
