package OpenInteract2::Manage::Website::ListPackages;

# $Id: ListPackages.pm,v 1.6 2003/06/11 02:43:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context qw( CTX );

$OpenInteract2::Manage::Website::ListPackages::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'List packages available in a website';
}

sub run_task {
    my ( $self ) = @_;
    foreach my $pkg ( @{ CTX->packages } ) {
        my ( $name, $version ) = ( $pkg->name, $pkg->version );
        $self->_add_status(
            { is_ok        => 'yes',
              message      => "Package $name-$version in site",
              name         => $pkg->name,
              version      => $pkg->version,
              install_date => $pkg->installed_date,
              directory    => $pkg->directory } );
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ListPackages - List packages installed to a website

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'list_packages', { website_dir => $website_dir } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     print "Package [[$s->{name}-$s->{version}]]\n",
           "Installed on:  $s->{install_date}\n",
           "Directory:     $s->{directory}\n";
 }


=head1 DESCRIPTION

Task to list all packages installed to a website. Note that this only
displays the current version of each package, not all old versions.

=head1 STATUS MESSAGES

In addition to the default entries, each status hashref includes:

=over 4

=item B<name>

Name of the package

=item B<version>

Version of the package

=item B<install_date>

Date the package was installed

=item B<directory>

Full path to package

=back

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
