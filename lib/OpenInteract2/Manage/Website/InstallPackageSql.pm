package OpenInteract2::Manage::Website::InstallPackageSql;

# $Id: InstallPackageSql.pm,v 1.7 2003/06/25 16:47:53 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Setup;

$OpenInteract2::Manage::Website::InstallPackageSql::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return "Run the 'install_sql_structure', 'install_sql_data' and " .
           "'install_sql_security' tasks in that order.";
}

sub list_param_require { return [ 'website_dir', 'package' ] }

sub setup_task {
    my ( $self ) = @_;
    $self->setup_context( { skip => 'activate spops' } );
}

sub run_task {
    my ( $self ) = @_;
    my $struct = OpenInteract2::Manage->new( 'install_sql_structure' );
    $struct->param_copy( $self );
    my $data = OpenInteract2::Manage->new( 'install_sql_data' );
    $data->param_copy( $self );
    my $security = OpenInteract2::Manage->new( 'install_sql_security' );
    $security->param_copy( $self );
    eval {
        $struct->execute;
        $self->_add_status( $struct->get_status );

        # Re-reads the SPOPS config now that the tables are created...

        my $setup = OpenInteract2::Setup->new;
        $setup->activate_spops_classes( CTX->spops_config );

        $data->execute;
        $self->_add_status( $data->get_status );
        $security->execute;
        $self->_add_status( $security->get_status );
    };
    if ( $@ ) {
        $self->_add_status_head( { is_ok   => 'no',
                                   message => "SQL installation failed: $@" });
        oi_error $@;
    }
    $self->_add_status_head( { is_ok   => 'yes',
                               message => 'SQL installation successful' } );
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::InstallPackageSql - Install SQL structures, object/SQL data and security objects

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'install_sql', \%PARAMS );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

This task is just a wrapper around the other database installation
tasks,
L<OpenInteract2::Manage::Website::InstallPackageStructure|OpenInteract2::Manage::Website::InstallPackageStructure>
(install_sql_structure),
L<OpenInteract2::Manage::Website::InstallPackageData|OpenInteract2::Manage::Website::InstallPackageData>
(install_sql_data) and
L<OpenInteract2::Manage::Website::InstallPackageSecurity|OpenInteract2::Manage::Website::InstallPackageSecurity>
(install_sql_security) so you don't need to call them all
individually.

=head1 STATUS INFORMATION

In addition to the default information, each status message includes:

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

Copyright (C) 2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

