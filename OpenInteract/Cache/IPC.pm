package OpenInteract::Cache::IPC;

# $Id: IPC.pm,v 1.1 2001/07/11 12:33:04 lachoy Exp $

use strict;
use vars qw( $AUTOLOAD );
use IPC::Cache;

@OpenInteract::Cache::IPC::ISA     = ();
$OpenInteract::Cache::IPC::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

$AUTOLOAD = undef;

my $DEFAULT_EXPIRE = 0;

sub class_initialize { 
    my ( $class, $p ) = @_;

    # Allow values that are passed in to override anything 
    # set in the config object

    my $max_expire  = $p->{expires_in};
    my $cache_key   = $p->{key};

    # If we were given a config object, fill in the empty values
  
    if ( ref $p->{config} ) {
        my $cache_info = $p->{config}->{cache_info}->{ipc};
        $max_expire  ||= $cache_info->{max_expire};
        $cache_key   ||= $cache_info->{key};
    }
  
    # If a value isn't set, use the default from the class
    # configuration above.

    $max_expire ||= $DEFAULT_EXPIRE;

    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 1, "Using the following settings:\n", "Expire: $max_expire\n   Key: $cache_key" );
    my $cache = IPC::Cache->new( { expires_in => $max_expire, 
                                   cache_key  => $cache_key } )
                               || warn " (Cache/IPC): Cannot create cache!\n";
    my $stash_class = $p->{config}->{stash_class};
    $stash_class->set_stash( 'ipc-cache', $cache );
    return 1;
}


# params: 0 = class ; 1 = key

sub _get_meta { 
    return OpenInteract::Request->instance->get_stash( 'ipc-cache' )->get( $_[1] );
}


# params: 0 = class ; 1 = key ; 2 = data ; 3 = expires (in seconds)

sub _set_meta { 
    return OpenInteract::Request->instance->get_stash( 'ipc-cache' )->set( $_[1], $_[2], $_[3] );
}


# params: 0 = class ; 1 = key ; 2 = data for comparison

sub check_meta { 
    return $_[2] == OpenInteract::Request->instance->get_stash( 'ipc-cache' )->get( $_[1] );
}


sub AUTOLOAD {
    my ( $class ) = @_;
    my $request = $AUTOLOAD;
    $request =~ s/^.*://;
    my $R = OpenInteract::Request->instance;
    my $cache = $R->get_stash( 'ipc-cache' );
    unless ( $cache ) {
        $R->scrib( 0, "Hey! Cache isn't defined yet! <<$request>>" );
    }
    elsif ( $cache->can( $request ) ) {
        return $cache->$request( @_ );
    }
    $R->scrib( 0, "Do not know how to process <<$request>>" );
    return undef;
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Cache::IPC -- Implement caching of metadata via IPC for quick access

=head1 DESCRIPTION

We use shared-memory to cache metadata from the main cache. Normally
this will be something like a timestamp associated with a bunch of
data. If the timestamp does not match, the main cache is signaled to
return undef instead of the data it holds.

=head1 TO DO

- Actually use and test!

- Will this work on Win32?

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
