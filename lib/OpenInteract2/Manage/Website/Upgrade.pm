package OpenInteract2::Manage::Website::Upgrade;

# $Id: Upgrade.pm,v 1.8 2003/06/11 02:43:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use File::Spec;
use OpenInteract2::Manage  qw( SYSTEM_PACKAGES );
use OpenInteract2::Config::TransferSample;

$OpenInteract2::Manage::Website::Upgrade::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'Upgrade your website to a new version of OpenInteract2';
}

sub list_param_require  { return [ 'website_dir', 'source_dir' ] }
sub list_param_optional { return [ 'skip_packages' ] }
sub list_param_validate { return [ 'website_dir', 'source_dir' ] }

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'skip_packages' ) {
        return "Indicates that we should not update the packages";
    }
    return $self->SUPER::get_param_description( $param_name );
}

sub run_task {
    my ( $self ) = @_;
    my $source_dir = $self->param( 'source_dir' );
    if ( $self->param( 'skip_packages' ) ) {
        $self->_add_status(
            { is_ok   => 1,
              action  => 'install package',
              message => 'Package install skipped, none installed' } );
    }
    else {
        $self->notify_observers( progress => 'Upgrading packages',
                                 { long => 'yes' } );
        $self->_install_packages( $source_dir, SYSTEM_PACKAGES );
        $self->notify_observers( progress => 'Package upgrade complete' );
    }

    my $widget_dir = File::Spec->catdir( $source_dir, 'template' );
    my $website_dir = $self->param( 'website_dir' );
    my $copied = OpenInteract::Config::TransferSample
                         ->new( $widget_dir )
                         ->run( $website_dir );
    foreach my $file ( @{ $copied } ) {
        $self->_add_status({ is_ok    => 'yes',
                             action   => 'copy updated template files',
                             filename => $file });
    }
    $self->notify_observers( progress => 'Widget copy complete' );
}


1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::Upgrade - Upgrade website from a new OpenInteract distribution

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $source_dir  = '/usr/local/src/OpenInteract-2.01';
 my $task = OpenInteract2::Manage->new(
                      'upgrade_website', { website_dir => $website_dir,
                                           source_dir  => $source_dir } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 STATUS MESSAGES

No additional entries in the status messages.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 COPYRIGHT

Copyright (C) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
