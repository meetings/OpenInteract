package OpenInteract2::Manage::Website::CreateSuperuserPassword;

# $Id: CreateSuperuserPassword.pm,v 1.6 2003/07/16 12:22:02 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Utility;

$OpenInteract2::Manage::Website::CreateSuperuserPassword::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'create_password';
}

sub get_brief_description {
    return 'Change the superuser password';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        password => {
            description => "New password for superuser",
            is_required => 'yes',
        },
        website_dir => $self->_get_website_dir_param,
    };
}

# VALIDATE

sub validate_param {
    my ( $self, $param_name, $value ) = @_;
    if ( $param_name eq 'password' ) {
        unless ( $value ) {
            return ( "Parameter 'password' must be defined" );
        }
    }
    return $self->SUPER::validate_param( $param_name, $value );
}

# RUN

sub run_task {
    my ( $self ) = @_;
    my %status = ();
    my $password = $self->param( 'password' );
    my $root_id = CTX->default_object_id( 'superuser' );
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

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

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

