package OpenInteract2::Manage::Website::ThemeInstall;

# $Id: ThemeInstall.pm,v 1.7 2003/06/11 02:43:28 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use Data::Dumper;
use OpenInteract2::Context qw( CTX );

$OpenInteract2::Manage::Website::ThemeInstall::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub brief_description {
    return 'Install a theme dumped from a website to your website';
}

sub list_param_require  { return [ 'theme_file', 'website_dir' ] }
sub list_param_validate { return [ 'theme_file', 'website_dir' ] }

sub get_param_description {
    my ( $self, $param_name ) = @_;
    if ( $param_name eq 'theme_file' ) {
        return "Name of file to import the theme from";
    }
    return $self->SUPER::get_param_description( $param_name );
}

sub get_validate_sub {
    my ( $self, $name ) = @_;
    return \&_check_theme_file if ( $name eq 'theme_file' );
    return $self->SUPER::get_validate_sub( $name );
}


sub _check_theme_file {
    my ( $self, $theme_file ) = @_;
    unless ( $theme_file and -f $theme_file ) {
        return "Must be a valid filename";
    }
    my $data = eval { _open_file( $theme_file ) };
    if ( $@ ) {
        return "Error with file: $@";
    }
}


sub run_task {
    my ( $self ) = @_;
    my %status = ( is_ok => 0 );
    my $themeball = _open_file( $self->param( 'theme_file' ) );
    my $theme_meta = shift @{ $themeball };
    my $theme_data = $self->_map_fields( $theme_meta->{theme_fields},
                                         shift @{ $themeball } );
    my $theme = CTX->lookup_object( 'theme' )->new( $theme_data );
    eval { $theme->save };
    if ( $@ ) {
        $status{message} = "Cannot save theme: $@";
        $self->_add_status( \%status );
        return;
    }

    my $themeprop_class = CTX->lookup_object( 'themeprop' );
    my $prop_count = 0;
    foreach my $prop_raw ( @{ $themeball } ) {
        my $prop_data = $self->_map_fields( $theme_meta->{theme_prop_fields},
                                            $prop_raw );
        my $prop = $themeprop_class->new( $prop_data );
        $prop->{theme_id} = $theme->id;
        eval { $prop->save };
        $prop_count++;
    }
    $status{message} = "Theme and [$prop_count] properties saved ok";
    $status{is_ok}   = 'yes';
    $self->_add_status( \%status );
    return;
}


sub _map_fields {
    my ( $self, $fields, $data ) = @_;
    my %map = ();
    for ( my $i = 0; $i < scalar @{ $fields }; $i++ ) {
        $map{ $fields->[ $i ] } = $data->[ $i ];
    }
    return \%map;
}


sub _open_file {
    my ( $theme_file ) = @_;
    eval { open( THEMEBALL, "< $theme_file" ) || die $! };
    die "cannot open - $@" if ( $@ );

    local $/ = undef;
    my $contents = <THEMEBALL>;
    my ( $data );
    {
        no strict 'vars';
        $data = eval $contents;
        die "invalid data - $@" if ( $@ );
    }
    close( THEMEBALL );
    return $data;
}

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::ThemeInstall - Install a theme from a themeball

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use OpenInteract2::Manage;

 my $website_dir = '/home/httpd/mysite';
 my $task = OpenInteract2::Manage->new(
                      'install_theme', { website_dir => $website_dir,
                                         theme_file  => 'my_themeball' } );
 my $status = $task->execute;
 print "Installed?  $status->{is_ok}\n",
       "$status->{message}\n";
 }

=head1 DESCRIPTION

This task installs a theme from a "themeball", dumped using the
'dump_theme' task.

=head1 STATUS MESSAGES

No additional entries in the status messages.

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
