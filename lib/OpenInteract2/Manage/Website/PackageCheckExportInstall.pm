package OpenInteract2::Manage::Website::PackageCheckExportInstall;

# $Id: PackageCheckExportInstall.pm,v 1.2 2004/02/17 04:30:20 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Cwd                      qw( cwd );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Manage::Website::PackageCheckExportInstall::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'package_all';
}

sub get_brief_description {
    return "Check, export and install a package";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        package_dir => {
            description    => 'Package to check, export and install (only one)',
            is_required    => 'yes',
            is_multivalued => 'no',
            default        => cwd(),
        },
    };
}

sub validate_param {
    my ( $self, $param_name, $param_value ) = @_;
    if ( $param_name eq 'package_dir' ) {
        my $package_conf_file = File::Spec->catfile( $param_value, 'package.conf' );
        unless ( -f $package_conf_file ) {
            return "Directory does not appear to be a package";
        }
    }
    return $self->SUPER::validate_param( $param_name, $param_value );
}

sub run_task {
    my ( $self ) = @_;

    my ( $is_ok, $subtask );
    ( $is_ok, $subtask ) = $self->_run_subtask( 'check_package' );
    return unless ( $is_ok );
    $self->_add_status({ action => 'check package',
                         is_ok  => 'yes' });

    ( $is_ok, $subtask ) = $self->_run_subtask( 'export_package' );
    return unless ( $is_ok );
    $self->_add_status({ action => 'export package',
                         is_ok  => 'yes' });
    my ( $package_file );
    foreach my $status ( $subtask->get_status ) {
        if ( $status->{message} =~ /^Exported package [\w\.\-]+ to/ ) {
            $package_file = $status->{filename};
        }
    }

    warn "Package file set to '$package_file'\n";

    ( $is_ok, $subtask )  = $self->_run_subtask( 'install_package',
                                                 package_file => $package_file );
    return unless ( $is_ok );
    $self->_add_status({ action => 'install package',
                         is_ok  => 'yes' });
}

sub _run_subtask {
    my ( $self, $task_name, %extra_params ) = @_;
    my $subtask = OpenInteract2::Manage->new( $task_name,
                                              { package_dir => $self->param( 'package_dir' ),
                                                website_dir => $self->param( 'website_dir' ),
                                                %extra_params } );
    eval { $subtask->execute() };
    if ( $@ ) {
        $self->_add_status({ action => $task_name,
                             is_ok  => 'no',
                             message => "Caught error: $@" });
        return 0;
    }
    my $is_ok = 1;
    foreach my $status ( $subtask->get_status ) {
        if ( $status->{is_ok} eq 'no' ) {
            $self->_add_status({ action => $task_name,
                                 is_ok  => 'no',
                                 message => $status->{message} });
            $is_ok = 0;
        }
    }
    return ( $is_ok, $subtask );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::PackageCheckExportInstall - Check, export and install a package in one fell swoop

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 
 # 'package_dir' is also necessary but will default to the current
 # directory
 
 my %PARAMS = ( website_dir => $website_dir );
 my $task = OpenInteract2::Manage->new( 'package_all', \%PARAMS );
 eval { $task->execute };
 foreach my $s ( $task->get_status ) {
     my $ok_label = ( $s->{is_ok} eq 'yes' )
                      ? 'OK' : 'NOT OK';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 NOTES

This task will fail if you have extra files in your directory beyond
the patterns defined in 'MANIFEST.SKIP'. So either keep extra files
out of your package directory or maintain the skiplist.

=head1 REQUIRED OPTIONS

=over 4

=item B<website_dir>=/path/to/website

=item B<package_dir>=/path/to/this-package

=back

=head1 STATUS INFORMATION

Each status hashref contains only standard information.

=head1 COPYRIGHT

Copyright (C) 2003-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

