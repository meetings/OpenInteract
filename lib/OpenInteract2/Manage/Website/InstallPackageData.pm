package OpenInteract2::Manage::Website::InstallPackageData;

# $Id: InstallPackageData.pm,v 1.5 2003/06/11 02:43:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::SQLInstall;

$OpenInteract2::Manage::Website::InstallPackageData::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'Install the data for one or more packages to a website';
}

sub list_param_required {
    return [ 'website_dir', 'package' ];
}

sub run_task {
    my ( $self ) = @_;
    my $repository = CTX->repository;

PACKAGE:
    foreach my $package_name ( @{ $self->param( 'package' ) } ) {
        my $package = $repository->fetch_package( $package_name );
        unless ( $package ) {
            $self->_add_status(
                { is_ok   => 'no',
                  action  => 'install object data',
                  message => "Package $package_name not installed" } );
            next PACKAGE;
        }
        my $action = "install object data: " . $package->name;
        my $installer =
            OpenInteract2::SQLInstall->new_from_package( $package );
        unless ( $installer ) {
            $self->_add_status(
                { is_ok   => 'yes',
                  action  => $action,
                  package => $package_name,
                  message => "No SQL installer specified for $package_name" });
            next PACKAGE;
        }
        $installer->install_data;
        my @install_status = $installer->get_status;
        for ( @install_status ) {
            $_->{action}  = $action;
            $_->{package} = $package_name;
        }
        $self->_add_status( @install_status );
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::InstallPackageData - Install object/table data from packages

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'install_sql_data',
                      { website_dir => $website_dir } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Action:    $s->{action}\n",
           "Status OK? $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

Installs SQL and/or object data for one or more packages.

=head1 STATUS MESSAGES

In addition to the default entries, successful status messages
include:

=over 4

=item B<filename>

File used for processing

=item B<package>

Name of package this action spawmed from.

=back

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
