package OpenInteract2::Cache::File;

# $Id: File.pm,v 1.3 2003/06/11 02:43:31 lachoy Exp $

use strict;
use base qw( OpenInteract2::Cache );
use Cache::FileCache;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );

$OpenInteract2::Cache::File::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my $DEFAULT_SIZE   = 2000000;  # 10 MB -- max size of cache
my $DEFAULT_EXPIRE = 86400;    # 1 day

sub initialize {
    my ( $self ) = @_;

    # Allow values that are passed in to override anything
    # set in the config object

    my $server_config = CTX->server_config;
    my $cache_dir = $server_config->{dir}{cache_content};
    unless ( -d $cache_dir ) {
        warn "Sorry, I cannot create a filesystem cache without a ",
             "valid directory. (Given [$cache_dir])\n";
        return undef;
    }

    my $cache_info     = $server_config->{cache_info}{data};
    my $max_size       = $cache_info->{max_size};
    my $default_expire = $cache_info->{default_expire};
    my $cache_depth    = $cache_info->{directory_depth};

    # If a value isn't set, use the default from the class
    # configuration above.

    $max_size       ||= $DEFAULT_SIZE;
    $default_expire ||= $DEFAULT_EXPIRE;

    DEBUG && LOG( LINFO, "Using the following cache settings ",
                         "[Dir $cache_dir] [Size $max_size] ",
                         "[Expire $default_expire] [Depth $cache_depth]" );
    return Cache::FileCache->new({ default_expires_in => $default_expire,
                                   max_size           => $max_size,
                                   cache_root         => $cache_dir,
                                   cache_depth        => $cache_depth });
}


sub get_data {
    my ( $self, $cache, $key ) = @_;
    return $cache->get( $key );
}


sub set_data {
    my ( $self, $cache, $key, $data, $expires ) = @_;
    $cache->set( $key, $data, $expires );
    return 1;
}


sub clear_data {
    my ( $self, $cache, $key ) = @_;
    $cache->remove( $key );
    return 1;
}

1;

__END__

=head1 NAME

OpenInteract2::Cache::File -- Implement caching in the filesystem

=head1 DESCRIPTION

Subclass of L<OpenInteract2::Cache|OpenInteract2::Cache> that uses the
filesystem to cache objects.

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
