package OpenInteract2::Manage::Package::Check;

# $Id: Check.pm,v 1.7 2003/06/11 02:43:29 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Package );

$OpenInteract2::Manage::Package::Check::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'Check the validity of a package';
}

sub list_param_require  { return [ 'package_dir' ] }
sub list_param_validate { return [ 'package_dir' ] }

sub param_initialize {
    my ( $self ) = @_;
    unless ( $self->param( 'package_dir' ) ) {
        $self->param(
            package_dir => File::Spec->rel2abs( File::Spec->curdir ) );
    }
    return $self->SUPER::param_initialize();
}

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'package_dir' ) {
        return "Directory of package to check";
    }
    return $self->SUPER::get_param_description( $param_name );
}

sub run_task {
    my ( $self ) = @_;
    my $package = OpenInteract2::Package->new({
                         directory => $self->param( 'package_dir' ) });
    my @check_status = $package->check;
    $self->_add_status( $_ ) for ( @check_status );
    return;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Package::Check - Check validity of a package

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $package_dir = '/home/me/work/pkg/mypkg';
 my $task = OpenInteract2::Manage->new(
                      'check_package', { package_dir => $package_dir } );
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

Run a whole bunch of checks on a package to see that all its
components are ok. See L<OpenInteract2::Package|OpenInteract2::Package>
docs under C<check()>.

=head1 STATUS MESSAGES

In addition to the default entries, each status message includes:

=over 4

=item B<filename>

File checked

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
