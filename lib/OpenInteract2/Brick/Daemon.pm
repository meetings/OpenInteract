package OpenInteract2::Brick::Daemon;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'oi2_daemon.ini' => 'OI2_DAEMONINI',
);

sub get_name {
    return 'daemon';
}

sub get_resources {
    return (
        'oi2_daemon.ini' => [ 'conf oi2_daemon.ini', 'yes' ],
    );
}

sub load {
    my ( $self, $resource_name ) = @_;
    my $inline_sub_name = $INLINED_SUBS{ $resource_name };
    unless ( $inline_sub_name ) {
        OpenInteract2::Exception->throw(
            "Resource name '$resource_name' not found ",
            "in ", ref( $self ), "; cannot load content." );
    }
    return $self->$inline_sub_name();
}

OpenInteract2::Brick->register_factory_type( get_name() => __PACKAGE__ );

=pod

=head1 NAME

OpenInteract2::Brick::Daemon - Configuration used for creating the standalone webserver

=head1 SYNOPSIS

  oi2_manage create_website --website_dir=/path/to/site

=head1 DESCRIPTION

This class holds resources for configuring the standalone webserver daemon.

These resources are associated with OpenInteract2 version 1.99_06.

=head2 Resources

You can grab resources individually using the names below and
C<load_resource()> and C<copy_resources_to()>, or you can copy all the
resources at once using C<copy_all_resources_to()> -- see
L<OpenInteract2::Brick> for details.

=over 4


=item B<oi2_daemon.ini>


=back

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS


Chris Winters E<lt>chris@cwinters.comE<gt>


=cut


sub OI2_DAEMONINI {
    return <<'SOMELONGSTRING';
# The server name is for reporting purposes only
[server]
name = www.mycompany.com

# All options here passed directly to IO::Socket::INET
[socket]
LocalAddr = localhost
LocalPort = 8080
Proto     = tcp

# Declare any number of regular expressions that tell the daemon to
# serve up the file directly from the /html tree rather than pass it
# to OI2
[content]
static_path = ^/images
static_path = \.(css|pdf|gz|zip|jpg|gif|png|mp3|mpg|mpeg|avi|mov)$
SOMELONGSTRING
}

