package OpenInteract2::Manage::Website::RemovePackage;

# $Id: RemovePackage.pm,v 1.3 2003/06/11 02:43:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );

$OpenInteract2::Manage::Website::RemovePackage::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'Remove a package from a website';
}

sub list_param_require  { return [ 'website_dir', 'package' ] }
sub list_param_validate { return [ 'website_dir', 'package' ] }

sub setup_task {
    my ( $self ) = @_;
}


sub run_task {
    my ( $self ) = @_;
}


sub tear_down_task {
    my ( $self ) = @_;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::RemovePackage - Managment task

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
