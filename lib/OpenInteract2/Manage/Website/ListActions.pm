package OpenInteract2::Manage::Website::ListActions;

# $Id: ListActions.pm,v 1.10 2004/02/17 04:30:20 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Action;
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Setup;

$OpenInteract2::Manage::Website::ListActions::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'list_actions';
}

sub get_brief_description {
    return 'List actions available in a website';
}

# get_parameters() inherited from parent

sub run_task {
    my ( $self ) = @_;
    my $action_table = CTX->action_table;
    foreach my $name ( sort keys %{ $action_table } ) {
        next unless ( $name );
        my $action_info = $action_table->{ $name };
        my $action = OpenInteract2::Action->new( $action_info );
        my $urls = $action->get_dispatch_urls;
        unless ( ref( $urls ) && $urls->[0] ) { 
            $urls = [ 'n/a' ];
        }
        $self->_add_status(
            { is_ok   => 'yes',
              action  => 'OpenInteract2 Action',
              message => "Action $name mapped to $urls->[0]",
              url     => $urls,
              name    => $name,
              type    => $action_info->{type},
              class   => $action_info->{class},
              method  => $action_info->{method},
              template => $action_info->{template} });
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ListActions - List all actions in a website

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'list_actions', { website_dir => $website_dir } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     print "Action [[$s->{name}]]\n",
           "Type:     $s->{type}\n",
           "Class:    $s->{class}\n",
           "Method:   $s->{method}\n",
           "Template: $s->{template}\n";
 }

=head1 DESCRIPTION

This task lists available actions in a website.

=head1 STATUS MESSAGES

In addition to the default entries, each status message includes:

=over 4

=item B<name>

Name of the action

=item B<url>

Arrayref of all URLs this action mapped to.

=item B<type>

Type of action (template, class, box, directory_handler)

=item B<class>

Class used for action

=item B<method>

Method used for action

=item B<template>

Template used for action

=back

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
