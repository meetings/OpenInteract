package OpenInteract2::Manage::Website::TestLDAP;

# $Id: TestLDAP.pm,v 1.5 2003/06/11 02:43:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );

$OpenInteract2::Manage::Website::TestLDAP::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'Test all configured LDAP connections in a website';
}

sub run_task {
    my ( $self ) = @_;
    my $datasource_config = CTX->datasource_config;
    my ( $error_msg );

    # Perform initial sanity checks

    unless ( ref $datasource_config ne 'HASH' and
              scalar keys %{ $datasource_config } ) {
        $self->_add_status(
            { is_ok   => 'yes',
              message => "No datasources defined; no connection attempted." } );
        return;
    }

    my $ldap_ds = 0;
    my @status = ();
    my $default_ldap = CTX->server_config->{datasource_info}{default_connection_ldap};

    # Initial checks are done, now scroll through each of the
    # connection hashrefs and try to make a connection

DATASOURCE:
    while ( my ( $name, $ds_conf ) = each %{ $datasource_config } ) {
        next unless ( $ds_conf->{type} eq 'LDAP' );
        $ldap_ds++;
        my %s = ( name => $name, is_ok => 'no' );
        $s{is_default} = ( $default_ldap eq $name ) ? 'yes' : 'no';
        unless ( $ds_conf->{host} ) {
            $s{message} = "You must define 'host' in the datasource " .
                          "configuration";
            $self->_add_status( \%s );
            next DATASOURCE;
        }
        unless ( $ds_conf->{base_dn} ) {
            $s{message} = "You must define 'base_dn' in the datasource " .
                          "configuration";
            $self->_add_status( \%s );
            next DATASOURCE;
        }
        my $ldap = eval { CTX->datasource( $name ) };
        if ( $@ ) {
            $s{message} = $@;
            $self->_add_status( \%s );
            next DATASOURCE;
        }
        unless ( $ldap and UNIVERSAL::isa( $ldap, 'Net::LDAP' ) ) {
            $s{message} = "Connect failed (no error, but no LDAP " .
                          "handle returned)";
            $self->_add_status( \%s );
            next DATASOURCE;
        }
        $s{is_ok} = 'yes';
        $s{message} = "Connected and bound to directory ok";
        $self->_add_status( \%s );
    }
    return @status;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::TestLDAP - Task to test configured LDAP connections

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'test_ldap', { website_dir => $website_dir } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     my $default_label = ( $s->{is_default} eq 'yes' )
                           ? ' (default) ' : '';
     print "Connection: $s->{name} $default_label\n",
           "Status:     $ok_label\n",
           "$s->{message}\n";
 }

=head1 DESCRIPTION

This command simply tests all LDAP connections defined in the server
configuration. That is, all C<datasource> entries that are of type
'LDAP'. Bind parameters, if setup, are also tested.

=head1 STATUS MESSAGES

In addition to the normal entries, each status hashref includes:

=over 4

=item B<name>

Name of the connection

=item B<is_default>

Set to 'yes' if the connection is the default LDAP connection, 'no' if
not.

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
