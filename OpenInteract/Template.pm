package OpenInteract::Template;

# $Id: Template.pm,v 1.3 2001/08/26 04:09:56 lachoy Exp $

use strict;

@OpenInteract::Template::ISA     = ();
$OpenInteract::Template::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub default_info {
    my ( $class ) = @_;
    my ( $pkg, $file, $line ) = caller;
    die depmsg( $pkg, $file, $line );
}

sub read_template {
    my ( $class ) = @_;
    my ( $pkg, $file, $line ) = caller;
    die depmsg( $pkg, $file, $line );
}

sub process_filename {
    my ( $class ) = @_;
    my ( $pkg, $file, $line ) = caller;
    die depmsg( $pkg, $file, $line );
}

sub depmsg {
    my ( $pkg, $file, $line ) = @_;
    return <<DEPMSG;
The class OpenInteract::Template is NOT USED ANY LONGER. Please see
OpenInteract::Template::Process, OpenInteract::Template::Provider and
OpenInteract::Template::Plugin for replacements.

Called by:

File: $file
Line: $line
DEPMSG
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Template - DEPRECATED

=head1 SYNOPSIS

DO NOT USE THIS CLASS

=head1 DESCRIPTION

OpenInteract::Template is not used any longer. It has been replaced by
L<OpenInteract::Template::Process>,
L<OpenInteract::Template::Provider> and
L<OpenInteract::Template::Plugin>.
=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
