package OpenInteract2::ContentGenerator;

# $Id: ContentGenerator.pm,v 1.8 2003/07/02 05:20:08 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

my %GENERATOR = ();

sub initialize {
    my ( $class ) = @_;
    my $log = get_logger( LOG_INIT );

    $log->is_debug &&
        $log->debug( "Initializing content generators" );
    my $generators = CTX->lookup_content_generator;
    while ( my ( $name, $info ) = each %{ $generators } ) {
        next if ( $name eq 'default' );
        next unless ( ref $info eq 'HASH' );

        my $generator_class = $info->{class};
        $log->is_debug &&
            $log->debug( "Trying to require and initialize ",
                         "[Name: $name] [Class: $generator_class]" );
        eval "require $generator_class";
        if ( $@ ) {
           $log->error( "Failed to require generator class ",
                        "[$generator_class]: $@" );
           next;
        }
        $log->is_debug &&
            $log->debug( "Require ok, now initializing generator" );
        eval { $generator_class->initialize };
        if ( $@ ) {
            $log->error( "Cannot initialize generator [$name]: $@" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Successfully initialized generator [$name]" );
            my ( $gen_class, $gen_method ) = ( $info->{class}, $info->{method} );
            $log->is_debug &&
                $log->debug( "Generator [$name] assigned called ",
                             "by [$gen_class]::[$gen_method]" );
            no strict 'refs';
            my $gen_sub = \&{ $gen_class . '::' . $gen_method };

            # Each value in %GENERATOR is a singleton for a particular
            # content generator

            $GENERATOR{ $name } = bless( { class  => $gen_class,
                                           method => $gen_method,
                                           sub    => $gen_sub,
                                           name   => $name }, __PACKAGE__ );
        }
    }
}

sub instance {
    my ( $class, $name ) = @_;
    my $log = get_logger( LOG_TEMPLATE );
    unless ( exists $GENERATOR{ $name } ) {
        my $msg = "Content generator [$name] was never initialized";
        $log->error( $msg );
        oi_error $msg;
    }
    return $GENERATOR{ $name };

}

# TODO: is this used anywhere? (it shouldn't be)
sub instance_sub {
    my ( $class, $name ) = @_;
    my $log = get_logger( LOG_TEMPLATE );
    unless ( exists $GENERATOR{ $name } ) {
        my $msg = "Content generator [$name] was never initialized";
        $log->error( $msg );
        oi_error $msg;
    }
    return $GENERATOR{ $name }->{sub};
}

########################################
# OBJECT METHODS

sub execute {
    my $self = shift @_;
    my $log = get_logger( LOG_TEMPLATE );

    $log->is_debug &&
        $log->debug( "Executing content generator [$self->{class}]" );

    my $content = eval { $self->{sub}->( $self->{class}, @_ ) };
    if ( $@ ) {
        $log->error( "Failed to execute content generator ",
                     "[Name: $self->{name}] [Class: $self->{class}]: $@" );
    }
    else {
        $log->is_debug &&
            $log->debug( "Content generator executed ok" );
    }
    return $content;
}

# Read-only accessors

sub name  { return $_[0]->{name} }
sub class { return $_[0]->{class} }

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator - Coordinator for classes generating content

=head1 SYNOPSIS

 # In server startup
 
 OpenInteract2::ContentGenerator->initialize;

 # Whenever you want a generator use either of these. (This is handled
 # behind the scenes in OI2::Action->generate_content for most uses.)
 
 my $generator = OpenInteract2::ContentGenerator->instance( 'TT' );
 my $generator = CTX->content_generator( 'TT' );
 $content = $generator->execute( \%template_params,
                                 \%content_params,
                                 \%template_source );

=head1 DESCRIPTION

This is a simple coordinating front end for the classes that actually
generate the content -- template processors, SOAP response generators,
etc. (You could probably put some sort of image generation in here
too, but that would be mad.)

=head1 METHODS

=head2 Class Methods

B<initialize()>

Normally only called from L<OpenInteract2::Setup|OpenInteract2::Setup>
-- call the C<initialize()> method of each generator specified in the
configuration key C<content_generator>.

Returns: nothing. If errors occur in the generator classes we log
them.

B<instance( $generator_name )>

Return an object representing the given content generator. If
C<$generator_name> is not found an exception is thrown.

Returns: an
L<OpenInteract2::ContentGenerator|OpenInteract2::ContentGenerator>
object.

=head2 Object Methods

B<execute( \%template_params, \%content_params, \%template_source )>

Passes along the parameters to the appropriate content generator class
and return the content.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
