package OpenInteract2::ContentGenerator;

# $Id: ContentGenerator.pm,v 1.5 2003/06/11 02:51:17 lachoy Exp $

use strict;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use OpenInteract2::Exception qw( oi_error );

my %GENERATOR = ();

sub initialize {
    my ( $class ) = @_;
    my $server_config = CTX->server_config;
    while ( my ( $name, $info ) =
                 each %{ $server_config->{content_generator} } ) {
        next if ( $name eq 'default' );
        next unless ( ref $info eq 'HASH' );
        my $generator_class = $info->{class};
        DEBUG && LOG( LDEBUG, "Trying to require and initialize ",
                              "[Name: $name] [Class: $generator_class]" );
        eval "require $generator_class";
        if ( $@ ) {
           LOG( LERROR, "Failed to require generator class ",
                        "[$generator_class]: $@" );
           next;
        }
        DEBUG && LOG( LDEBUG, "Require ok, now initializing generator" );
        eval { $generator_class->initialize };
        if ( $@ ) {
            LOG( LERROR, "Cannot initialize generator [$name]: $@" );
        }
        else {
            DEBUG && LOG( LDEBUG, "Successfully initialized generator [$name]" );
            my ( $gen_class, $gen_method ) = ( $info->{class}, $info->{method} );
            DEBUG && LOG( LDEBUG, "Generator [$name] assigned called ",
                                  "by [$gen_class]::[$gen_method]" );
            no strict 'refs';
            my $gen_sub = \&{ $gen_class . '::' . $gen_method };
            $GENERATOR{ $name } = { class  => $gen_class,
                                    method => $gen_method,
                                    sub    => $gen_sub,
                                    name   => $name };
        }
    }
}

sub instance {
    my ( $class, $name ) = @_;
    unless ( exists $GENERATOR{ $name } ) {
        oi_error "Content generator [$name] was never initialized";
    }
    return ( $GENERATOR{ $name }->{class},
             $GENERATOR{ $name }->{method},
             $GENERATOR{ $name }->{sub} );

}

sub instance_sub {
    my ( $class, $name ) = @_;
    unless ( exists $GENERATOR{ $name } ) {
        oi_error "Content generator [$name] was never initialized";
    }
    return $GENERATOR{ $name }->{sub};
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator - Coordinator for classes generating content

=head1 SYNOPSIS

 OpenInteract2::ContentGenerator->initialize;
 my ( $class, $method, $sub ) = OpenInteract2::ContentGenerator->instance( 'TT' );

=head1 DESCRIPTION

This is a simple coordinating front end for the classes that actually
generate the content -- template processors, SOAP response generators,
etc. (You could probably put some sort of image generation in here
too, but that would be mad.)

=head1 METHODS

B<initialize()>

Normally only called from L<OpenInteract2::Setup|OpenInteract2::Setup>
-- call the C<initialize()> method of each generator specified in the
configuration key C<content_generator>.

Returns: nothing. If errors occur in the generator classes we log
them. (XXX: We may throw an error in the future.)

B<instance( $generator_name )>

Return information about the given content generator. This takes the
form of a three-item list: a class name, a method name and a
subroutine reference.

If C<$generator_name> is not found an exception is thrown.

Returns: a three-item list with a class name, a method name and a
subroutine reference for the specified generator.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
