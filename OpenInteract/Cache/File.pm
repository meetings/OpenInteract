package OpenInteract::Cache::File;

# $Id: File.pm,v 1.1 2001/07/11 12:33:04 lachoy Exp $

use strict;
use vars qw( $AUTOLOAD );
use File::Cache;
use OpenInteract::Cache;

@OpenInteract::Cache::File::ISA     = qw( OpenInteract::Cache );
$OpenInteract::Cache::File::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

$AUTOLOAD = undef;

my $DEFAULT_SIZE   = 2000000;  # 10 MB -- max size of cache
my $DEFAULT_EXPIRE = 86400;    # 1 day

sub class_initialize { 
    my ( $class, $p ) = @_;

    # Allow values that are passed in to override anything 
    # set in the config object

    my $cache_dir   = $p->{cache_dir};
    my $max_size    = $p->{max_size};
    my $max_expire  = $p->{expires_in};
    my $cache_depth = $p->{cache_depth};

    # If we were given a config object, fill in the empty values

    if ( ref $p->{config} ) {
        my $cache_info = $p->{config}->{cache_info}->{data};
        $cache_dir   ||= $p->{config}->get_dir( 'cache' );
        $max_size    ||= $cache_info->{max_size};
        $max_expire  ||= $cache_info->{expire};
        $cache_depth ||= $cache_info->{depth};
    }

    my $R = OpenInteract::Request->instance;
    unless ( $cache_dir ) {
        warn " Sorry, I cannot create a filesystem cache without a directory.\n";
        return undef;
    }

    # If a value isn't set, use the default from the class
    # configuration above.

    $max_size   ||= $DEFAULT_SIZE;
    $max_expire ||= $DEFAULT_EXPIRE;

    # Set some extra values: they can be passed in or set via the 
    # config, but if they're not it's no big deal

    my ( %extra );
    $extra{cache_depth} = $cache_depth  if ( $cache_depth );

    $R->DEBUG && $R->scrib( 1, "Using the following settings:\n",
                               "Size: $max_size\n", 
                               "Expire: $max_expire\n"
                               "Dir: $cache_dir" );
    my $cache = File::Cache->new( { expires_in => $max_expire, 
                                    max_size   => $max_size, 				  
                                    cache_key  => $cache_dir,
                                    %extra } )
                             || warn " (Cache/File): Cannot create cache!\n";
    my $stash_class = $p->{config}->{stash_class};
    $stash_class->set_stash( 'cache', $cache );
    return 1;
}


# params: 0 = class ; 1 = key

sub _get_data { 
    my $R = OpenInteract::Request->instance;
    return $R->cache->get( $_[1] ); 
}

# params: 0 = class ; 1 = key; 2 = data ; 3 = expires (in seconds)

sub _set_data { 
    my $R = OpenInteract::Request->instance;
    return $R->cache->set( $_[1], $_[2], $_[3] ); 
}


sub _clear_data {
    my $R = OpenInteract::Request->instance;
    return $R->cache->set( $_[1], undef ); 
}


sub AUTOLOAD {
    my ( $class ) = @_;
    my $request = $AUTOLOAD;
    $request =~ s/^.*://;
    my $R = OpenInteract::Request->instance;
    my $cache = $R->cache;
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

OpenInteract::Cache::File -- Implement caching in the filesystem

=head1 DESCRIPTION

Subclass of L<OpenInteract::Cache> that uses the filesystem to 
cache objects.

One note: if file space becomes an issue, it would be a 
good idea to put this on the fastest drive (or drive
array) possible.

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
