package OpenInteract2::Manage::Website::InstallPackage;

# $Id: InstallPackage.pm,v 1.7 2003/06/11 02:43:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Data::Dumper           qw( Dumper );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Repository;

$OpenInteract2::Manage::Website::Install::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'Install a package distribution to a website';
}

sub list_param_require  { return [ 'website_dir', 'package_file' ] }
sub list_param_validate { return [ 'website_dir', 'package_file' ] }

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'package_file' ) {
        return "Package distribution filename to install to website";
    }
    return $self->SUPER::get_param_description( $param_name );
}

sub run_task {
    my ( $self ) = @_;
    my $package_file = $self->param( 'package_file' );
    my %status = (
        action   => 'install package',
        filename => $package_file,
    );
    my $package = eval {
        OpenInteract2::Package->install({
                    package_file => $package_file,
                    repository   => CTX->repository })
    };
    if ( $@ ) {
        $status{is_ok}   = 'no';
        $status{message} = "Error: $@";
    }
    else {
        $status{is_ok}   = 'yes';
        $status{package} = $package->name;
        $status{version} = $package->version;
        $status{message} = sprintf( 'Installed package %s-%s to website %s',
                                    $package->name, $package->version,
                                    $self->param( 'website_dir' ) );
    }
    $self->notify_observers(
        progress => "Finished with installation of $package_file" );
    $self->_add_status( \%status );
    return;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::InstallPackage - Install a package distribution to a website

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $package_file = '/home/me/mypkg-1.11.zip';
 my $website_dir  = '/home/httpd/testsite';
 my $task = OpenInteract2::Manage->new(
                      'install_package', { package_file => $package_file,
                                           website_dir => $website_dir } );
 my ( $status ) = $task->execute;
 print "Action:    $s->{action}\n",
       "Status OK? $s->{is_ok}\n",
       "Package:   $s->{package_name} $s->{package_version}\n",
       "$s->{message}\n";
 }

=head1 DESCRIPTION

Installs a package from a distribution to a website. It does B<not>
install data structures, data, security information, or anything
else. See the 'install_sql*' tasks for that.

=head1 STATUS MESSAGES

In addition to the default entries, each status message includes:

=over 4

=item B<filename>

Package file installed

=item B<package>

Name of package installed

=item B<version>

Version of package installed

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
