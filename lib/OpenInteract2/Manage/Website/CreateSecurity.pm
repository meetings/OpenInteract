package OpenInteract2::Manage::Website::CreateSecurity;

# $Id: CreateSecurity.pm,v 1.4 2004/06/13 18:19:54 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error oi_param_error );

$OpenInteract2::Manage::Website::CreateSecurity::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

# METADATA

sub get_name {
    return 'create_security';
}

sub get_brief_description {
    return "Create security settings for multiple SPOPS objects at once.";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        scope => {
            description =>
                  "Scope security setting will have. Must be 'user', " .
                  "'group' or 'world'",
            is_required => 'yes',
        },
        scope_id => {
            description =>
                     "ID of scope to set. Required if 'scope' is 'user' or 'group'",
            do_validate => 'yes',
        },
        level => {
            description =>
                  "Security level to set. Must be 'none', 'read' or 'write'.",
            is_required => 'yes',
        },
        spops => {
            description =>
                  "SPOPS object tag for class you'd like to set security",
            is_required => 'yes',
        }
    };
}

# VALIDATE

# This is a little different than normal -- we're overriding this from
# OI2::Manage since the 'CreateSecurity' object validates for us. We
# need to create the context and the create-security objects here
# (rather than the more appropriate setup_task()) for this reason.

sub check_parameters {
    my ( $self ) = @_;
    $self->_setup_context;
    my $creator = OpenInteract2::CreateSecurity->new({
                         scope       => $self->param( 'scope' ),
                         scope_id    => $self->param( 'scope_id' ),
                         level       => $self->param( 'level' ),
                         class       => $self->param( 'spops' ),
                         website_dir => $self->param( 'website_dir' ),
    });
    unless ( $creator->validate ) {
        my $errors = $creator->errors_with_params;
        if ( $errors->{class} ) {
            $errors->{spops} = $errors->{class};
            delete $errors->{class};
        }
        oi_param_error "One or more parameters were invalid",
                       { parameter_fail => $errors };
    }
    $self->param( creator => $creator );
}

# RUN

# DO NOT DELETE: this is a no-op override from OI2::Manage::Website so
# we don't setup context again...

sub setup_task { return }

sub run_task {
    my ( $self ) = @_;
    my $creator = $self->param( 'creator' );
    my $count = $creator->run;
    my $msg = join( '', "Processed ", $creator->num_processed, " and ",
                        "encountered ", $creator->num_failed, " failures. " );
    $self->_ok( 'create security', $msg );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::CreateSecurity - Create security for multiple SPOPS objects

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my %PARAMS = (
    scope => 4,
    scope_id => 4,
    spops    => 'news',
    level    => 'read',
    website_dir => $website_dir,
 );
 my $task = OpenInteract2::Manage->new( 'create_security', \%PARAMS );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     my $ok_label      = ( $s->{is_ok} eq 'yes' )
                           ? 'OK' : 'NOT OK';
     print "Status OK?  $s->{is_ok}\n",
           "$s->{message}\n";
 }

=head1 REQUIRED OPTIONS

=over 4

=item B<scope>=(user|group|world)

Scope of security you're setting

=item B<scope_id>=ID of 'scope'

Scope ID of security you're setting. Not used with 'world' scope.

=item B<spops>=object-key

The key used for the SPOPS object you're trying to reindex. For
instance, 'news' if you're trying to reindex the objects from the
'OpenInteract2::News' class.

=back

=head1 STATUS INFORMATION

Each status hashref includes:

=over 4

=item B<is_ok>

Set to 'yes' if the task succeeded, 'no' if not.

=item B<message>

Success/failure message.

=back

=head1 SEE ALSO

L<OpenInteract2::CreateSecurity|OpenInteract2::CreateSecurity> (in
'base_security' package)

=head1 COPYRIGHT

Copyright (C) 2003-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

