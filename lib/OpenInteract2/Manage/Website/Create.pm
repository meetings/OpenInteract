package OpenInteract2::Manage::Website::Create;

# $Id: Create.pm,v 1.21 2004/05/22 04:21:36 lachoy Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use File::Spec::Functions    qw( catdir );
use File::Path               qw( rmtree );
use OpenInteract2::Config::Readonly;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Manage    qw( SYSTEM_PACKAGES );
use OpenInteract2::Package;
use OpenInteract2::Repository;

$OpenInteract2::Manage::Website::Create::VERSION = sprintf("%d.%02d", q$Revision: 1.21 $ =~ /(\d+)\.(\d+)/);

# think about merging this with info from OI2::Manage::Website::SetDirectoryPermissions

my @WEBSITE_SUBDIR = (
   [ 0770, 'cache' ],
   [ 0770, 'cache', 'tt' ],
   [ 0770, 'cache', 'content' ],
   [ 0777, 'cgi-bin' ],
   [ 0777, 'conf' ],
   [ 0777, 'error' ],
   [ 0777, 'html' ],
   [ 0777, 'html', 'images' ],
   [ 0777, 'logs' ],
   [ 0777, 'mail' ],
   [ 0777, 'msg' ],
   [ 0777, 'overflow' ],
   [ 0777, 'pkg' ],
   [ 0777, 'template' ],
   [ 0777, 'uploads' ],
);

# METADATA

sub get_name {
    return 'create_website';
}

sub get_brief_description {
    return 'Create a new website from sample files shipped with OI2';
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        source_dir  => $self->_get_source_dir_param,
        website_dir => {
               description =>
                        "Directory where website will be created. It must " .
                        "not already exist when you run the task.",
               is_required => 'yes',
        },
    };
}

# VALIDATE

# Use a different check for 'website_dir' than our parent, since we
# want to ensure it DOES NOT exist

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'website_dir' ) {
        if ( -d $value ) {
            return "Website directory [$value] already exists; cannot " .
                   "create website over an existing site";
        }
        return;
    }
    return $self->SUPER::validate_param( $name, $value );
}

# RUN

# Define empty method so parent doesn't create context

sub setup_task {}


# If anything bails in run_task, this cleans it up

sub tear_down_task {
    my ( $self ) = @_;
    return unless ( $self->param( 'task_failed' ) );
    my $website_dir = $self->param( 'website_dir' );
    $self->notify_observers(
        progress => 'Some part of the task failed, cleaning up directory' );
    if ( -d $website_dir ) {
        eval { rmtree( $website_dir ) || die $! };
        if ( $@ ) {
            oi_error "Cannot cleanup website directory [$website_dir]: $@";
        }
    }
}


sub run_task {
    my ( $self ) = @_;
    my $website_dir = $self->param( 'website_dir' );
    my $source_dir  = $self->param( 'source_dir' );

    $self->_create_directories( $website_dir );
    $self->notify_observers( progress => 'Directories created' );

    $self->_copy_widgets( $website_dir, $source_dir );
    $self->notify_observers(
        progress => 'Global templates copied' );

    $self->_copy_cgi( $website_dir, $source_dir );
    $self->notify_observers(
        progress => 'CGI interface copied' );

    $self->_copy_messages( $website_dir, $source_dir );

    $self->_copy_server_conf( $website_dir, $source_dir );

    $self->_copy_apache_conf( $website_dir, $source_dir );

    $self->_copy_daemon_conf( $website_dir, $source_dir );
    $self->notify_observers(
        progress => 'OI2 and web server configuration copied' );

    # This will initialize the context to our new website...
    $self->_setup_context({ skip => 'initialize repository' });

    my $repository = OpenInteract2::Repository->new();
    $repository->website_dir( $website_dir );
    CTX->repository( $repository );

    $self->notify_observers( progress => 'Installing packages',
                             { long => 'yes' } );
    $self->_install_packages( $source_dir, SYSTEM_PACKAGES );
    $self->notify_observers( progress => 'Packages installed' );

    $self->_set_nowrite_files( $website_dir, $source_dir );
    $self->_add_status_head(
            { action  => 'create website',
              is_ok   => 'yes',
              message => 'All directories and files created, all ' .
                         'packages installed' });
}


# Create the main website directory and subdirectories

sub _create_directories {
    my ( $self, $website_dir ) = @_;
    eval { mkdir( $website_dir, 0775 ) || die $! };
    if ( $@ ) {
        oi_error "Cannot create website directory [$website_dir]: $@";
    }
    foreach my $sub_dir_info ( @WEBSITE_SUBDIR ) {
        my ( $perm, @subdirs ) = @{ $sub_dir_info };
        my $full_subdir = catdir( $website_dir, @subdirs );
        eval { mkdir( $full_subdir, $perm ) || die $! };
        if ( $@ ) {
            oi_error "Cannot create subdirectory in [$full_subdir]: $@";
        }
        $self->_add_status( { is_ok    => 'yes',
                              action   => 'create subdirectory',
                              filename => $full_subdir,
                              message  => 'Directory created' } );
    }
}

sub _copy_widgets {
    my ( $self, $website_dir, $source_dir ) = @_;
    my $source_widget_dir =
        catdir( $source_dir, 'sample', 'website', 'template' );
    my $transferred = OpenInteract2::Config::TransferSample
                         ->new( $source_widget_dir )
                         ->run( $website_dir );
    foreach my $copied ( @{ $transferred } ) {
        $self->_add_status( { is_ok   => 'yes',
                              action  => 'copy widget',
                              message => 'Copied file from sample site',
                              filename => $copied } );
    }
}

sub _copy_messages {
    my ( $self, $website_dir, $source_dir ) = @_;
    my $source_msg_dir = catdir( $source_dir, 'sample', 'website', 'msg' );
    my %vars = ( website_dir => $website_dir );
    my $transferred = OpenInteract2::Config::TransferSample
                         ->new( $source_msg_dir )
                         ->run( $website_dir, \%vars );
    foreach my $copied ( @{ $transferred } ) {
        $self->_add_status( { is_ok    => 'yes',
                              action   => 'copy localized messages',
                              message  => 'Copied file from sample site',
                              filename => $copied } );
    }
}

sub _copy_server_conf {
    my ( $self, $website_dir, $source_dir ) = @_;
    my $source_conf_dir = catdir( $source_dir, 'sample', 'website', 'conf' );
    my %vars = ( website_dir => $website_dir );
    my $transferred = OpenInteract2::Config::TransferSample
                         ->new( $source_conf_dir )
                         ->run( $website_dir, \%vars );
    foreach my $copied ( @{ $transferred } ) {
        $self->_add_status( { is_ok   => 'yes',
                              action  => 'copy server config',
                              message => 'Copied file from sample site',
                              filename => $copied } );
    }
}

sub _copy_cgi {
    my ( $self, $website_dir, $source_dir ) = @_;
    my $source_cgi_dir = catdir( $source_dir, 'sample', 'website', 'cgi-bin' );
    my %vars = ( website_dir => $website_dir );
    my $transferred = OpenInteract2::Config::TransferSample
                         ->new( $source_cgi_dir )
                         ->run( $website_dir, \%vars );
    foreach my $copied ( @{ $transferred } ) {
        $self->_add_status( { is_ok   => 'yes',
                              action  => 'copy CGI',
                              message => 'Copied file from sample site',
                              filename => $copied } );
        # OIN-10: hack just to ensure we get the right perms
        if ( $copied =~ /cgi$/ ) {
            chmod( 0755, $copied );
        }
    }
}


sub _copy_apache_conf {
    my ( $self, $website_dir, $source_dir ) = @_;
    $self->_copy_webserver_conf( $website_dir, $source_dir,
                                 'apache', 'apache 1.x' );
    $self->_copy_webserver_conf( $website_dir, $source_dir,
                                 'apache2', 'apache 2.x' );
}

sub _copy_webserver_conf {
    my ( $self, $website_dir, $source_dir, $type, $desc ) = @_;
    my $source_apache_dir = catdir( $source_dir, 'sample', $type );
    my %vars = ( website_dir => $website_dir );
    my $transferred = OpenInteract2::Config::TransferSample
                         ->new( $source_apache_dir )
                         ->run( $website_dir, \%vars );
    foreach my $copied ( @{ $transferred } ) {
        $self->_add_status( { is_ok   => 'yes',
                              action  => "copy $desc config",
                              message => 'Copied file from sample site',
                              filename => $copied } );
    }

}

sub _copy_daemon_conf {
    my ( $self, $website_dir, $source_dir ) = @_;
    my $source_daemon_dir = catdir( $source_dir, 'sample', 'daemon' );
    my %vars = ( website_dir => $website_dir );
    my $transferred = OpenInteract2::Config::TransferSample
                         ->new( $source_daemon_dir )
                         ->run( $website_dir, \%vars );
    foreach my $copied ( @{ $transferred } ) {
        $self->_add_status( { is_ok   => 'yes',
                              action  => 'copy standalone daemon config',
                              message => 'Copied file from sample site',
                              filename => $copied } );
    }
}

# Create nowrite flags for HTML and widget dirs

sub _set_nowrite_files {
    my ( $self, $website_dir ) = @_;
    my $action = 'set nowrite file';
    my $html_dir = catdir( $website_dir, 'html' );
    my $html_message = join( '', 'If a file is listed here it will not be ',
                                 'updated when the package to which it ',
                                 'belongs is updated.' );
    eval {
        OpenInteract2::Config::Readonly->write_config(
            $html_dir,
            { file    => [ 'index.html', 'main.css' ],
              comment => $html_message } )
        };
    if ( $@ ) {
        $self->_add_status( { is_ok    => 'no',
                              action   => $action,
                              filename => $html_dir,
                              message  => "$@" } );
    }
    else {
        $self->_add_status( { is_ok    => 'yes',
                              action   => $action,
                              filename => $html_dir,
                              message  => 'Read-only file created ok' } );
    }

    my $tmpl_dir = catdir( $website_dir, 'template' );
    my $tmpl_status = { action   => $action,
                        filename => $tmpl_dir };
    my $tmpl_message = join( '', 'These are templates that will not be ',
                                 'overwritten when you run refresh the ',
                                 'widgets (one template per line)'  );
    eval { OpenInteract2::Config::Readonly->write_config(
                                   $tmpl_dir,
                                   { file    => [ 'base_main', 'base_simple' ],
                                     comment => $tmpl_message } ) };
    if ( $@ ) {
        $self->_add_status( { is_ok    => 'no',
                              action   => $action,
                              filename => $tmpl_dir,
                              message  => "$@" } );
    }
    else {
        $self->_add_status( { is_ok    => 'yes',
                              action   => $action,
                              filename => $tmpl_dir,
                              message  => 'Read-only file created ok' } );
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::Manage::Website::Create - Create a new website

=head1 SYNOPSIS

 #!/usr/bin/perl
 
 use strict;
 use OpenInteract2::Manage;
 
 my $website_dir = '/home/httpd/mysite';
 my $source_dir  = '/usr/local/src/OpenInteract-2.01';
 my $task = OpenInteract2::Manage->new(
                      'create_website', { website_dir => $website_dir,
                                          source_dir  => $source_dir } );
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

Creates a new OpenInteract website. This entails creating a directory
for your website and all the necessary subdirectories, plus all the
packages, default configuration files, widgets, etc.

The directory specified in the 'website_dir' parameter must not exist
yet or the task will fail.

After running this command, you typically have to only edit some
configuration files and your website can be up and running! See the
file C<INSTALL.website> installed to your website's root directory for
more information.

=head1 STATUS MESSAGES

In addition to the default entries, each status message may include:

=over 4

=item B<filename>

The directory created or file copied over.

=back

Additionally, you should be aware that because this task does a lot of
work it generates a B<lot> of status messages. Accordingly it also
generates a few 'progress' observations along the way so you can get
feedback.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
