package OpenInteract::Cache;

# $Id: Cache.pm,v 1.1 2001/07/11 12:33:04 lachoy Exp $

use strict;
use Digest::MD5 qw( md5 );

my $IPC_CLASS = undef;

# Returns: caching object (implementation-neutral)

sub new {
    my ( $pkg, $p ) = @_;
    my $class = ref $pkg || $pkg;
    if ( $p->{config} ) {
        $IPC_CLASS = $p->{config}->{cache_info}->{ipc}->{class}  if ( $p->{config}->{cache_info}->{data}->{use_ipc} );
    }
    my $self = bless( {}, $class );
    $self->initialize( @_ );
    return $self;
}


# Returns: data from the cache

sub get {
    my ( $class, $p ) = @_;
    my $key = $p->{key};
    my $is_object = 0;
    my $obj_class = undef;
    my $R = OpenInteract::Request->instance;
    if ( ! $key and $p->{class} and $p->{id} ) {
        $key = $class->_make_idx( $p->{class}, $p->{id} );
        $R->DEBUG && $R->scrib( 1, "Created key from class/id: (($key))" );
        $obj_class = $p->{class};
        $is_object++;
        return undef  unless ( $obj_class->pre_cache_get( $p->{id} ) );
    }
    return undef   if ( ! $key );
    my $data = $class->_get_data( $key );

    # If we're using IPC timestamps to ensure data consistency, 
    # check to see that the IPC timestamp matches the data timestamp;
    # if not, return nothing; if so, set $data to the data held in the 
    # cache (which is the result if we're not using IPC stuff)

    if ( $IPC_CLASS ) {
        return undef unless ( $IPC_CLASS->check_meta( $key, $data->{timestamp} ) );
        $data = $data->{data};
    }
    return undef   if ( ! $data );
    $R->DEBUG && $R->scrib( 1, "Cache hit! for <<$key>>" );
    if ( $is_object ) {
        return undef  unless ( $obj_class->post_cache_get( $data ) );
    }
    return $data;
}

sub set {
    my ( $class, $p ) = @_;
    my $is_object = 0;
    my $key  = $p->{key};
    my $data = $p->{data};
    my $timestamp = time;
    my ( $obj );
    my $R = OpenInteract::Request->instance;
    if ( $class->is_object( $data ) ) {
        $obj = $data;
        $key = $class->_make_idx( ref $obj, $obj->id );
        $R->DEBUG && $R->scrib( 1, "Created key from class/id: (($key))" );
        $is_object++;
        return undef  unless ( $obj->pre_cache_save );
        if ( $obj->isa( 'SPOPS' ) ) {
            $data = $obj->data;
        }
    }
    my $save_data = ( $IPC_CLASS ) 
                      ? { data => $data, timestamp => $timestamp } 
                      : $data;
    $class->_set_data( $key, $save_data );
    $IPC_CLASS->_set_meta( $key, $timestamp )  if ( $IPC_CLASS );
    if ( $obj and $obj->can( 'post_cache_save' ) ) {
        return undef  if ( $obj->post_cache_save );
    }
    return 1;
}

sub clear {
    my ( $class, $p ) = @_;
    if ( $class->is_object( $p->{data} ) ) {
        $p->{key} = $class->_make_idx( ref $p->{data}, $p->{data}->id );
    }
    return $class->_clear_data( $p->{key} );
}

sub is_object {
    my ( $class, $item ) = @_;
    my $typeof = ref $item;
    return undef if ( ! $typeof );
    return undef if ( $typeof =~ /^(HASH|ARRAY|SCALAR)$/ );
    return 1;
}

sub _make_idx { return join '--', $_[1], $_[2]; }


# Set a new timestamp in the IPC metadata store

sub ipc_set {
    return undef if ( ! $IPC_CLASS );
    my ( $class, $key ) = @_;
    return $IPC_CLASS->_set_meta( $key, time );
}

sub class_initialize { return undef; }
sub initialize       { return undef; }
sub _get_data        { return undef; }
sub _set_data        { return undef; }
sub clear_object     { return undef; }
sub size_objects     { return undef; }
sub size_bytes       { return undef; }


sub DESTROY {
    my ( $self ) = shift;
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 1, "Removing object ", ref $self, " from play." );
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Cache -- caches objects so we do not need to do a database fetch each time

=head1 SYNOPSIS

 use OpenInteract::Cache;
 use OpenInteract::Object;

 my $obj = OpenInteract::Object->new();
 $obj->id( 35 );
 $obj->name( 'Superior Tecnologies, Inc.' );
 $obj->save();

 my $cache = OpenInteract::Cache::CacheType->new();
 $cache->set( $obj );

 ...(later)...
 my $class = 'OpenInteract::Object';
 my $obj = $cache->get( $class, 35 ) || $class->fetch( 35 );

=head1 DESCRIPTION

The original purpose of this class is to be a generic holder for
various types of objects within the SPOPS (formerly Collection)
framework. However, we will be extending it to cache any kind of data,
given a key and a chunk of data. That data can be some HTML or a
hashref of theme values.

This class is meant to have a simple interface and is really only a
wrapper around a functional caching module. These implementations are
found in the subclasses.

=head1 METHODS

These are the methods for the cache:

B<get( \%params )>

Returns the data in the cache associated with a key; undef if data
corresponding to the key is not found.

Parameters:

If you want to retrieve an object with a particular ID, use:

=over 4

=item *

B<class>: Class of object

=item *

B<id>: ID of object

=back

This module will create a consistent key from these two items.

Otherwise, use:

=over 4

=item *

B<key>: Key for data to retrieve 

=back

B<set( \%params )>

Saves the data found in the {data} parameter into the cache,
referenced by the key {key} or by a key built from metadata if the
item in {data} is an object. Returns a true value if successful.

Note that your object may define the methods I<pre_cache_save> and
I<post_cache_save> which can act as callbacks during the caching
process. Failure to return a true value from either of these callbacks
will result in the data not being cached.

B<clear( [ $obj ] )>

If given the request object and a collection object, clears the cache
of that object. If not, clears the cache of all objects.

Note that your object may define the methods I<pre_cache_remove> and
I<post_cache_remove> which can act as callbacks when the object is
removed from the cache.

=head1 SUBCLASS METHODS

These are the methods that must be overridden by a subclass to
implement caching.

B<_get_data( $key )>

Returns an object if it is cached and 'fresh', however that
implementation defines fresh.

B<_set_data( $data, $key, [ $expires ] )>

Returns 1 if successful, undef on failure.

B<_clear_data( $key )>

Removes the specified data from the cache. Returns 1 if successful,
undef on failure (or inability to do so).

You may also provide the following:

B<class_initialize( \%params )>

This method is called B<once> when the class is first initialized
(currently via a mod_perl ChildInitHandler). Generally used to define
something (package variables, for instance) that can live throughout
the life of the class.

The hashref passed in for parameters typically contains just the
config object (using the key 'config'); but you can also pass
implementation-specific information to the functional module this way.

B<initialize( \%params )>

The cache object is held in the 'Stash Class' between requests, so it
does not need to be recreated every time. The I<initialize()>
procedure is only called after the cache object is first created.

B<size_objects()>

Returns the number of objects currently in the cache; undef if not
implemented.

B<size_bytes()>

Returns the size in bytes of the objects currently in the cache; undef
if not implemented.

=head1 TODO

Test and get working!

=head1 BUGS

B<Caching and development mode>

Do not use caching while you are in development mode. Old, incorrect
versions of objects will inevitably get cached and mess you up.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
