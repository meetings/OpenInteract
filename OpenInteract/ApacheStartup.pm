package OpenInteract::ApacheStartup;

# $Id: ApacheStartup.pm,v 1.16 2001/10/08 21:34:41 lachoy Exp $

use strict;
use OpenInteract::DBI;
use OpenInteract::Startup;

use constant DEBUG => 0;

$OpenInteract::ApacheStartup::VERSION   = '1.07';
$OpenInteract::ApacheStartup::Revision  = substr(q$Revision: 1.16 $, 10);

# Create a handler to put the X-Forwarded-For header into the IP
# address -- thanks Stas! (perl.apache.org/guide/)

my $PROXY_SUB = <<'PROXY';

  sub OpenInteract::ProxyRemoteAddr ($) {
    my ( $r ) = @_;
    return unless ( ref $r );
    if ( my ( $ip ) = $r->header_in( 'X-Forwarded-For' ) =~ /([^,\s]+)$/ ) {
      $r->connection->remote_ip( $ip );
    }
    return Apache::Constants::OK;
  }
PROXY

sub initialize {
    my ( $class, $bc_file ) = @_;

    DEBUG && _w( 1, "ApacheStartup: Reading in information for configuration: $bc_file" );

    # We read the base config in first, so we can snag the apache modules

    my $BASE_CONFIG = OpenInteract::Startup->read_base_config({ filename => $bc_file });
    unless ( $BASE_CONFIG ) { die "Cannot create base configuration from ($bc_file)!"; }
    DEBUG && _w( 1, " --base configuration read in ok." );

    # Read in all the Apache classes -- do this separately since we need
    # to ensure that Apache::DBI gets included before DBI
    #
    # Word of warning! We also need to do this before using the class
    # 'OpenInteract::DBI', since it 'use's the DBI module itself. Keeping
    # Apache::DBI before DBI is quite important, and if there's any
    # confusing in the future about it we might as well put the
    # 'PerlModule Apache::DBI' before the PerlRequire statement into the
    # modperl httpd.conf

    my $config_dir = join( '/', $BASE_CONFIG->{website_dir},
                                $BASE_CONFIG->{config_dir} );
    OpenInteract::Startup->require_module({ filename => "$config_dir/apache.dat" });
    DEBUG && _w( 1, " --apache modules read in ok." );

    # The big enchilada -- do just about everything here and get back the 
    # list of classes that need to be initialized along with the config object. 
    # Note that we do not pass the necessary parameters to initialize aliases
    # and to create/initialize the SPOPS classes -- we do that in the child
    # init handler below

    my ( $init_class, $C ) = OpenInteract::Startup->main_initialize({
                                   base_config => $BASE_CONFIG });
    unless ( $C ) { die "No configuration object returned from initialization!\n"; }
    DEBUG && _w( 1, " --main initialization completed ok." );

    OpenInteract::Startup->require_module({ class => $C->{session_info}{class} });
    DEBUG && _w( 1, " -- require the session class ok" );

    # Figure out how to do this more cleanly in the near future -- maybe
    # just do it by hand for this special class?

    push @{ $init_class }, 'OpenInteract::PackageRepository';

    # Initialize the DBI drivers. Stas Beckman (stas@stason.org) wrote
    # up a section in the mod_perl developer guide
    # (perl.apache.org/guide/) about how this 'DBI->install_driver()' thing
    # saves memory.

    my $db_info = $C->{db_info};
    my %dbd_installed = ();
    foreach my $db_key ( keys %{ $db_info } ) {
        next if ( $dbd_installed{ $db_info->{ $db_key }{driver_name} } );
        DBI->install_driver( $db_info->{ $db_key }{driver_name} );
        DEBUG && _w( 1, " --installed DBD driver ($db_info->{ $db_key }{driver_name}) ok." );
    }

    # Check to see if the proxy subroutine has been loaded; if not, create it

    eval { OpenInteract->ProxyRemoteAddr() };
    if ( $@ =~ /^Can\'t locate object method "ProxyRemoteAddr"/ ) {
        DEBUG && _w( 1, "Creating proxy subroutine" );
        eval $PROXY_SUB;
        die "Cannot create proxy subroutine! $@" if ( $@ );
        DEBUG && _w( 1, " --installed proxy subroutine ok." );
    }

    # Setup caching info for use in the child init handler below

    my $cache_info      = $C->{cache_info}{data};
    my $cache_class     = $cache_info->{class};
    my $ipc_cache_class = $C->{cache}{ipc}{class};

    # If we're told, cleanup the Template Toolkit compile directory

    if ( $C->{template_info}{compile_cleanup} ) {
        $class->cleanup_tt_cache( $C->get_dir( 'cache_tt' ) );
    }

    # Do these initializations every time, unless we're on Win32 (they
    # have just call the routine to call something else...)

    my ( $init_sub, $OS );
    unless ($OS = $^O) {
        require Config;
        $OS = $Config::Config{'osname'};
    }

    # See the second sub for comments...

    if ( $OS=~/Win/i ) {
        DEBUG && _w( 1, "Running initialization for Windows." );
        srand;
        $cache_class->class_initialize({ config => $C })     if ( $cache_info->{use} );
        $ipc_cache_class->class_initialize({ config => $C }) if ( $cache_info->{use_ipc} );

        my $REQUEST_CLASS = $BASE_CONFIG->{request_class};
        $REQUEST_CLASS->setup_aliases;

        OpenInteract::Startup->initialize_spops({ config => $C, class => $init_class });

        eval { OpenInteract::Error::Main->initialize({ config => $C }) };
        my $err_status  = ( $@ ) ? $@ : 'ok';
        DEBUG && _w( 1, sprintf( "%-40s: %-30s","init: Error Dispatcher", $err_status ) );
    }

    else {
        DEBUG && _w( 1, "Seeding childinit handler (non-Windows)" );

        my $init_sub = sub {

            DEBUG && _w( 1, "PerlChildInitHandler being executed for Child ($$)" );

            # seed the random number generator per child -- note that we can
            # probably take this out as of mod_perl >= 1.25

            srand;

            # Connect to the db but throw away the handle that is returned
            # -- this just 'primes the pump' and makes the DB connection
            # when the child is started versus when the first request is
            # received (probably not necessary using mysql, but for heavier
            # databases it can be a Good Thing)

            # TODO: See if this is the reason why we get the 'not
            # creating $R' problems discussed briefly at the bottom of
            # OpenInteract.pm

            foreach my $db_key ( keys %{ $db_info } ) {
                eval { OpenInteract::DBI->connect( $db_info->{ $db_key } ) };
                if ( $@ ) {
                    warn "Error trying to run first connect for database ",
                         "connection key ($db_key): $@\n";
                }
            }

            $cache_class->class_initialize({ config => $C })      if ( $cache_info->{use} );
            $ipc_cache_class->class_initialize({ config => $C })  if ( $cache_info->{use_ipc} );

            # Tell OpenInteract::Request to setup aliases if it hasn't already

            my $REQUEST_CLASS = $BASE_CONFIG->{request_class};
            $REQUEST_CLASS->setup_aliases;

            # Initialize all the SPOPS object classes

            OpenInteract::Startup->initialize_spops({ config => $C,
                                                      class  => $init_class });

            # Create a list of error handlers for our website

            eval { OpenInteract::Error::Main->initialize({ config => $C }) };
            my $err_status  = ( $@ ) ? $@ : 'ok';
            DEBUG && _w( 0, sprintf( "%-40s: %-30s","init: Error Dispatcher", $err_status ) );
        };
        Apache->push_handlers( PerlChildInitHandler => $init_sub );
    }

}


sub cleanup_tt_cache {
    my ( $class, $dir ) = @_;
    eval { opendir( TTC, $dir ) || die $! };
    if ( $@ ) {
        _w( 0, "Cannot open TT cache dir ($dir) for cleanup: $!" );
        return;
    }
    my @cache_files = grep { -f "$dir/$_" } readdir( TTC );
    closedir( TTC );
    for ( @cache_files ) { unlink( "$dir/$_" ) || _w( 0, "Cannot remove ($dir/$_): $!" ) }
    return;
}


sub _w {
    return unless ( DEBUG >= shift );
    my ( $pkg, $file, $line ) = caller;
    my @ci = caller(1);
    warn "$ci[3] ($line) >> ", join( ' ', @_ ), "\n";
}

1;

__END__

=pod

=head1 NAME

OpenInteract::ApacheStartup - Central module to call for initializing an OpenInteract website

=head1 SYNOPSIS

 # In an website's startup.pl file:

 #!/usr/bin/perl
 use strict;
 use OpenInteract::ApacheStartup;
 my $BASE_CONFIG = '/home/httpd/demo.openinteract.org/conf/base.conf';
 OpenInteract::ApacheStartup->initialize( $BASE_CONFIG );

 1;

=head1 DESCRIPTION

C<OpenInteract::ApacheStartup> should be run from the startup.pl file
of your website. (You can probably also load it directly from your
apache config as well, but we will stick with simple things for now :)

Its purpose is to load as many modules as possible into the parent
mod_perl process so we can share lots of memory. Sharing is good!

Most of the actual work is done in the C<OpenInteract::Startup>
module, so you might want to check the documentation for that if you
are curious how this works.

=head1 METHODS

B<initialize( $config_file )>

Your C<startup.pl> file should have a definition for a configuration
file and pass it to this method, which is the only one the module
contains.

=head1 TO DO

None.

=head1 BUGS

None known.

=head1 SEE ALSO

I<Configuration Guide to OpenInteract>, L<mod_perl>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
