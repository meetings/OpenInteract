package OpenInteract::Template::Toolkit;

# $Id: Toolkit.pm,v 1.4 2002/01/02 02:43:53 lachoy Exp $

use strict;
use OpenInteract::Template::Process;

@OpenInteract::Template::Toolkit::ISA     = qw( OpenInteract::Template );
$OpenInteract::Template::Toolkit::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub handler {
    my ( $class, @params ) = @_;
    my ( $pkg, $file, $line ) = caller;
    warn depmsg( $pkg, $file, $line );
    return OpenInteract::Template::Process->handler( @params );
}


sub initialize {
    my ( $class, @params ) = @_;
    my ( $pkg, $file, $line ) = caller;
    warn depmsg( $pkg, $file, $line );
    return OpenInteract::Template::Process->initialize( @params );
}

sub depmsg {
    my ( $pkg, $file, $line ) = @_;
    return <<DEPMSG;
The class OpenInteract::Template::Toolkit is DEPRECATED. Please change your
code at

File: $file
Line: $line

to use OpenInteract::Template::Process instead. Interface is the same.
DEPMSG
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Template::Toolkit - DEPRECATED

=head1 SYNOPSIS

DEPRECATED

=head1 DESCRIPTION

This class is deprecated. Use L<OpenInteract::Template::Process>.

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
