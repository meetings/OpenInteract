package OpenInteract2::Manage::Website::ListObjects;

# $Id: ListObjects.pm,v 1.5 2003/06/11 02:43:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Setup;

$OpenInteract2::Manage::Website::ListObjects::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'List SPOPS objects available in a website';
}

sub run_task {
    my ( $self ) = @_;
    my $spops_config = CTX->spops_config;
OBJECT:
    foreach my $alias ( sort keys %{ $spops_config } ) {
        next OBJECT unless ( $alias and $alias !~ /^_/ );
        my $object_info = $spops_config->{ $alias };
        my @alias_list = ( $alias );
        if ( ref $object_info->{alias} eq 'ARRAY' ) {
            push @alias_list, @{ $object_info->{alias} };
        }
        $self->_add_status(
            { is_ok   => 'yes',
              action  => 'OpenInteract2 SPOPS object',
              message => "SPOPS object $alias is a $object_info->{class}",
              name    => $alias,
              alias   => \@alias_list,
              class   => $object_info->{class},
              isa     => $object_info->{isa},
              rule    => $object_info->{rules_from} } );
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ListObjects - Task to list all SPOPS objects in a website

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'list_objects', { website_dir => $website_dir } );
 my @status = $task->execute;
 foreach my $s ( @status ) {
     print "Object [[$s->{name}]]\n",
           "Aliases:  ", join( ", ", $s->{alias} ), "\n",
           "Class:    $s->{class}\n",
           "ISA:      ", join( ", ", $s->{isa} ), "\n",
           "Rules:    ", join( ", ", $s->{rule} ), "\n";
 }

=head1 DESCRIPTION

Task to list all the objects currently known in a website.

=head1 STATUS MESSAGES

In addition to the default entries, each status hashref includes:

=over 4

=item B<name>

Name of the object (also the first alias)

=item B<alias> (\@)

All aliases by which this object is known

=item B<class>

Class used for object

=item B<isa> (\@)

Contents of the configuration 'isa'

=item B<rule> (\@)

Contents of the configuration 'rule_from'

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
