package OpenInteract2::Manage::Website::ThemeDump;

# $Id: ThemeDump.pm,v 1.6 2003/06/11 02:43:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Data::Dumper;
use OpenInteract2::Context qw( CTX );


$OpenInteract2::Manage::Website::ThemeDump::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'Dump a theme to a distributable format';
}

sub list_param_require {
    return [ 'theme_id', 'theme_file', 'website_dir' ];
}

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'theme_id' ) {
        return "ID of theme to export";
    }
    elsif ( $param_name eq 'theme_file' ) {
        return "Name of file to export the theme to";
    }
    return $self->SUPER::get_param_description( $param_name );
}

sub run_task {
    my ( $self ) = @_;
    my %status = ( is_ok => 'no' );
    my $theme_id = $self->param( 'theme_id' );
    my $theme    = eval {
        CTX->lookup_object( 'theme' )->fetch( $theme_id )
    };
    if ( $@ ) {
        $status{message} = "Error fetching theme [$theme_id]: $@";
        $self->_add_status( \%status );
        return;
    }

    my $properties = eval { $theme->themeprop };
    if ( $@ ) {
        $status{message} = "Error fetching theme properties: $@";
        $self->_add_status( \%status );
        return;
    }

    my @structure = (
         { theme_fields      => [ qw( title description credit ) ],
           theme_prop_fields => [ qw( prop value description ) ] },
         [ $theme->title, $theme->description, $theme->credit ]
    );

    foreach my $prop ( @{ $properties } ) {
        push @structure, [ $prop->prop, $prop->value, $prop->description ];
    }

    my $filename = $self->param( 'theme_file' );
    eval { open( THEMEBALL, "> $filename"  ) || die $! };
    if ( $@ ) {
        $status{message} = "Could not open themeball file [$filename]: $@";
        $self->_add_status( \%status );
        return;
    }
    print THEMEBALL Data::Dumper->Dump( [ \@structure ], [ 'themeball' ] );
    close THEMEBALL;
    $status{is_ok}    = 'yes';
    $status{message}  = "Themeball saved ok";
    $status{filename} = $filename;
    $self->_add_status( \%status );
    return;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ThemeDump - Dump a theme to a themeball

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'dump_theme', { website_dir => $website_dir,
                                      theme_id    => 5,
                                      theme_file  => 'my_themeball' } );
 my $status = $task->execute;
 print "Dumped?  $status->{is_ok}\n",
       "Filename $status->{filename}\n",
       "$status->{message}\n";
 }

=head1 DESCRIPTION

This task dumps a theme to a "themeball" which can be installed to
any other OpenInteract system.

=head1 STATUS MESSAGES

In addition to the normal entries, each status hashref includes:

=over 4

=item B<filename>

Set to the filename used for the dump; empty if the action failed.

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
