package OpenInteract2::Manage::Website::CreateSuperuserPassword;

# $Id: CreateSuperuserPassword.pm,v 1.2 2003/06/11 02:51:16 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context qw( CTX DEBUG LOG );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Utility;

$OpenInteract2::Manage::Website::CreateSuperuserPassword::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);


sub brief_description {
    return 'Change the superuser password';
}

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'password' ) {
        return "New password for superuser";
    }
    return $self->SUPER::get_param_description( $param_name );
}


sub list_param_required {
    return [ 'website_dir', 'password' ];
}

sub list_param_validate {
    return [ 'website_dir', 'password' ];
}

sub get_validate_sub {
    my ( $self, $param_name ) = @_;
    return \&_validate_password if ( $param_name eq 'password' );
    return $self->SUPER::get_validate_sub( $param_name );
}

sub _validate_password {
    my ( $self, $password ) = @_;
    unless ( $password ) {
        return ( "Parameter 'password' must be defined" );
    }
    return ();
}

sub run_task {
    my ( $self ) = @_;
    my %status = ();
    my $password = $self->param( 'password' );
    my $root_id = CTX->server_config->{default_objects}{superuser};
    my $root = eval {
        CTX->lookup_object( 'user' )
           ->fetch( $root_id, { skip_security => 1 } )
    };
    if ( $@ ) {
        $status{is_ok}   = 'no';
        $status{message} = "Error fetching superuser: $@";
    }
    else {
        my $set_password = ( CTX->server_config->{login}{crypt_password} )
                             ? SPOPS::Utility->crypt_it( $password )
                             : $password;
        $root->{password} = $set_password;
        eval { $root->save({ skip_security => 1 }) };
        if ( $@ ) {
            $status{is_ok}   = 'no';
            $status{message} = "Error saving superuser with new password: $@";
        }
        else {
            $status{is_ok}   = 'yes';
            $status{message} = "Changed password for superuser";
        }
    }
    $self->notify_observers( progress => 'Password change complete' );
    $self->_add_status( \%status );
    return;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::CreateSuperuserPassword - Change password for superuser

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'create_password', { password => 'foobar',
                                           website_dir => '/path/to/mysite' } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 REQUIRED OPTIONS

=over 4

=item B<option>=value

=back

=head1 STATUS INFORMATION

Each status hashref includes:

=over 4

=item B<is_ok>

Set to 'yes' if the task succeeded, 'no' if not.

=item B<message>

Success/failure message.

=back

=head1 COPYRIGHT

Copyright (C) 2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

