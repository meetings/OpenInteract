package HTTP::Daemon::OpenInteract2;

# $Id: OpenInteract2.pm,v 1.2 2003/06/11 02:43:33 lachoy Exp $

use strict;
use base qw( HTTP::Daemon );

my $VERSION = 1.90;

sub product_tokens {
    my ( $self ) = @_;
    return "OpenInteract/$VERSION " .  $self->SUPER::product_tokens;
}

1;

__END__

=head1 NAME

HTTP::Daemon::OpenInteract2 - Subclass of HTTP::Daemon for OpenInteract 2

=head1 SYNOPSIS

 my %options = ( LocalAddr => 'localhost',
                 LocalPort => 8081,
                 Proto     => 'tcp' );
 my $daemon = HTTP::Daemon::OpenInteract2->new( %options )
                     || die "Cannot create daemon! $!\n";
 print "OpenInteract now running at URL <", $daemon->url, ">\n";

=head1 DESCRIPTION

Subclass of L<HTTP::Daemon|HTTP::Daemon> that just overrides the
C<product_tokens()> method to add the current OpenInteract version to
the server header.

=head1 SEE ALSO

L<HTTP::Daemon|HTTP::Daemon>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
