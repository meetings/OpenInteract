package OpenInteract2::Filter;

# $Id: Filter.pm,v 1.3 2004/02/18 05:25:26 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Config::Ini;

$OpenInteract2::Filter::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub create_filter_filename {
    my ( $class ) = @_;
    my $conf_dir = CTX->lookup_directory( 'config' );
    return File::Spec->catfile( $conf_dir, 'filter.ini' );
}

# Note: $action_item can be a name or an object

sub add_filter_to_action {
    my ( $class, $filter_name, $action_item ) = @_;
    my $observed = $action_item;
    unless ( ref $observed ) {
        my $action_info = eval { CTX->lookup_action_info( $action_item ) };
        return if ( $@ or ref $action_info ne 'HASH' );
        $observed = $action_info->{class};
    }
    my $observer = CTX->lookup_filter( $filter_name );
    if ( ref $observer and ref $observer ne 'CODE' ) {
        $observer = $observer->new;   # create a new object
    }
    $observed->add_observer( $observer );
    return $observer;
}


sub register_filter {
    my ( $class, $filter_name, $filter_info, $registry ) = @_;
    $log ||= get_logger( LOG_OI );

    my ( $observer, $filter_type );
    if ( my $filter_class = $filter_info->{class} ) {
        my $error = $class->_require_module( $filter_class );
        unless ( $error ) {
            $observer = $filter_class;
            $filter_type = 'class';
        }
    }
    elsif ( my $filter_obj = $filter_info->{object} ) {
        my $error = $class->_require_module( $filter_obj );
        unless ( $error ) {
            $observer = eval { $filter_obj->new };
            if ( $@ ) {
                $log->error( "Failed to instantiate filter ",
                             "object '$filter_obj'" );
            }
            else {
                $filter_type = 'object';
            }
        }
    }
    elsif ( my $filter_sub = $filter_info->{sub} ) {
        $filter_sub =~ /^(.*)::(.*)$/;
        my ( $name_class, $name_sub ) = ( $1, $2 );
        my $error = $class->_require_module( $name_class );
        unless ( $error ) {
            no strict 'refs';
            $observer = *{ $name_class . '::' . $name_sub };
            $filter_type = 'sub';
        }
    }
    else {
        $log->error( "No filter registered for '$filter_name': must specify",
                     " 'class', 'object' or 'sub' in filter information. ",
                     "(See docs for OpenInteract2::Action under ",
                     "'OBSERVABLE ACTIONS')" );
    }
    if ( $observer ) {
        $registry->{ $filter_name } = $observer;
    }
    return $observer;
}


sub initialize {
    my ( $class ) = @_;
    my $log_init = get_logger( LOG_INIT );

    my $filter_file = $class->create_filter_filename;
    return unless ( -f $filter_file );
    my $filter_ini = OpenInteract2::Config::Ini->new(
                                   { filename => $filter_file });
    if ( $@ ) {
        $log_init->error( "Failed to read [$filter_file]: $@" );
        return;
    }

    my $filter_registry =
        $class->_register_initial_filters( $filter_ini->{filters},
                                           CTX->packages );
    CTX->set_filter_registry( $filter_registry );
    if ( ref $filter_ini->{filter_action} eq 'HASH' ) {
        while ( my ( $action_name, $filter_name ) =
                        each %{ $filter_ini->{filter_action} } ) {
            $class->add_filter_to_action( $filter_name, $action_name );
        }
    }
    return;
}

sub _register_initial_filters {
    my ( $class, $ini_filters, $packages ) = @_;
    my $log_init = get_logger( LOG_INIT );

    my %filter_map = ();

    # First register filters in packages; entries in 'filter.ini' will
    # override packages since it's assumed people editing it know what
    # they're doing...

    foreach my $pkg ( @{ $packages } ) {
        my $pkg_filters = $pkg->config->filter;
        next unless ( ref $pkg_filters eq 'HASH' );
        while ( my ( $filter_name, $filter_class ) = each %{ $pkg_filters } ) {
            $log_init->is_info &&
                $log_init->info( "Registering filter '$filter_name' as ",
                                 "'$filter_class' from package ", $pkg->full_name );
            $filter_map{ $filter_name } = { class => $filter_class };
        }
    }

    # Now cycle through the INI

    while ( my ( $filter_name, $filter_info ) = each %{ $ini_filters } ) {
        $log_init->is_info &&
            $log_init->info( "Registering filter '$filter_name' from ",
                             "server config" );
        if ( $filter_map{ $filter_name } ) {
            $log_init->warn( "WARNING: Overwriting previously registered ",
                             "filter '$filter_name'" );
        }
        $filter_map{ $filter_name } = $filter_info;
    }

    my %filter_registry = ();

    # Now that they're collected, be sure we can
    # require/reference/instantiate each

    while ( my ( $filter_name, $filter_info ) = each %filter_map ) {
        $class->register_filter( $filter_name,
                                 $filter_info,
                                 \%filter_registry );
    }
    return \%filter_registry;
}

sub _require_module {
    my ( $class, $to_require ) = @_;
    $log ||= get_logger( LOG_OI );

    eval "require $to_require";
    my $error = $@;
    if ( $error ) {
        $log->error( "Failed to require [$to_require]: $error" );
    }
    return ( $error ) ? $error : undef;
}

1;

__END__

=head1 NAME

OpenInteract2::Filter - Initialize and manage content filters

=head1 SYNOPSIS

 # Declare a filter 'allcaps' in $WEBSITE_DIR/conf/filter.ini
 
 [filters allcaps]
 class = OpenInteract2::Filter::AllCaps
 
 # You can also declare it in your package's package.conf file
 
 name           mypackage
 version        2.00
 author         Kilroy (kilroy@washere.com)
 filter         allcaps   OpenInteract2::Filter::AllCaps
 
 # Associate the filter with an action
 
 [filter_action]
 news = allcaps
 
 # Create the filter
 
 package OpenInteract2::Filter::AllCaps;
 
 use strict;
 
 sub update {
     my ( $class, $action, $type, $content ) = @_;
     return unless ( $type eq 'filter' );
     $$content =~ s/^(.*)$/\U$1\E/;
 }
 
 # Programmatically add a new filter
 
 CTX->add_filter( 'foobar', { class => 'OpenInteract2::Filter::Foobar' } );

=head1 DESCRIPTION

This class provides methods for initializing filters and attaching
them to action objects or action classes.

=head1 METHODS

All methods are class methods (for now). Note that when we discuss a
'filter' it could mean a class name, instantiated object or subroutine
reference. (A filter is just an observer, see
L<Class::Observable|Class::Observable> for what constitutes an
observer.)

B<create_filter_filename()>

Returns the full path to the server filter file, normally
C<$WEBSITE_DIR/conf/filter.ini>.

B<add_filter_to_action( $filter_name, $action | $action_name )>

Registers the filter referenced by C<$filter_name> to the action
C<$action> or the action class referenced by C<$action_name>. If you
pass in C<$action> the filter will go away when the object is disposed
at the end of the request; with C<$action_name> the filter will
persist until the server is shutdown.

Returns: assigned filter

B<register_filter( $filter_name, \%filter_info, \%filter_registry )>

Creates a filter with the name C<$filter_name> and saves the
information in C<\%filter_registry>. If the filter cannot be created
(due to a library not being available or an object not being
instantiable) an error is logged but no exception thrown.

Returns: created filter, undef if an error encountered

B<initialize()>

Reads filters declared in packages and in the server's C<filter.ini>
file, brings in the libraries referenced by the filters, creates a
filter name-to-filter registry and saves it to the context.

Note that filters declared at the server will override filters
declared in a package if they share the same name.

You'd almost certainly never need to call this as it's called from
L<OpenInteract2::Setup|OpenInteract2::Setup>.

Returns: nothing

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
