package OpenInteract2::ContentGenerator;

# $Id: ContentGenerator.pm,v 1.13 2004/02/18 05:25:26 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

# Each value in %GENERATOR is a singleton for a particular content
# generator, retrieved via instance()

my %GENERATOR = ();

my ( $log );

########################################
# FACTORY

sub initialize_all_generators {
    my ( $class ) = @_;
    my $log_init = get_logger( LOG_INIT );

    $log_init->is_debug &&
        $log_init->debug( "Initializing all content generators" );
    my $all_generator_info = CTX->lookup_content_generator_config;

BIG_GENERATOR:
    while ( my ( $name, $generator_data ) = each %{ $all_generator_info } ) {
        next if ( $name eq 'default' );
        my $generator_class = $generator_data->{class};
        unless ( $generator_class ) {
            $log_init->error( "Cannot use generator '$name': no class ",
                              "specified in key 'class'" );
            next BIG_GENERATOR;
        }
        my $full_name = "[Name: $name] [Class: $generator_class]";
        $log_init->is_debug &&
            $log_init->debug( "Trying to require and initialize $full_name" );
        eval "require $generator_class";
        if ( $@ ) {
           $log_init->error( "Failed to require generator $full_name: $@" );
           next BIG_GENERATOR;
        }
        my ( $generator );
        eval {
            $generator = $generator_class->new( $name, $generator_class );
            $generator->initialize( $generator_data );
        };
        if ( $@ ) {
            $log_init->error( "Require ok, but cannot initialize generator ",
                              "$full_name. Error: $@" );
        }
        else {
            $log_init->is_debug &&
                $log_init->debug( "Successfully required and initialized ",
                                  "generator $full_name" );
            $GENERATOR{ $name } = $generator;
        }
    }
}


sub instance {
    my ( $class, $name ) = @_;
    $log ||= get_logger( LOG_TEMPLATE );
    unless ( exists $GENERATOR{ $name } ) {
        my $msg = "Content generator '$name' was never initialized";
        $log->error( $msg );
        oi_error $msg;
    }
    return $GENERATOR{ $name };

}

########################################
# CONSTRUCTOR (internal)

sub new {
    my ( $pkg, $name, $gen_class ) = @_;
    my ( $package, @etc ) = caller;
    unless ( __PACKAGE__ eq $package ) {
        oi_error "Cannot call 'new()' from anywhere except " . __PACKAGE__;
    }
    return bless( { name  => $name,
                    class => $gen_class }, $pkg );
}


########################################
# READ-ONLY ACCESSORS

sub name  { return $_[0]->{name} }
sub class { return $_[0]->{class} }


########################################
# SUBCLASSES OVERRIDE

sub initialize { return }

sub generate {
    my ( $self ) = @_;
    oi_error "Class ", ref( $self ), " must implement 'generate()'";
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator - Coordinator for classes generating content

=head1 SYNOPSIS

 # In server startup
 
 OpenInteract2::ContentGenerator->initialize_all_generators;

 # Whenever you want a generator use either of these. (This is handled
 # behind the scenes in OI2::Action->generate_content for most uses.)
 
 my $generator = OpenInteract2::ContentGenerator->instance( 'TT' );
 my $generator = CTX->content_generator( 'TT' );
 
 # Every content generator implements 'generate()' which marries the
 # parameters with the template source and returns content
 
 $content = $generator->generate( \%template_params,
                                  \%content_params,
                                  \%template_source );

=head1 DESCRIPTION

This is a simple coordinating front end for the classes that actually
generate the content -- template processors, SOAP response generators,
etc. (You could probably put some sort of image generation in here
too, but that would be mad.)

=head1 METHODS

=head2 Class Methods

B<initialize_all_generators()>

Normally only called from
L<OpenInteract2::Setup|OpenInteract2::Setup>. This cycles through the
data in the configuration key C<content_generator>, performs a
C<require> on each class specified there, instantiates an object of
that class and calls C<initialize()> on it, passing in the data
(hashref) from the respective 'content_generator' configuration
section as the only argument.

This object is a singleton and will be returned whenever you call
C<instance()> (below). So you can save state that may be used by your
generator many times throughout its lifecycle. Note that it is not
cleared out per-request, so the data it stores should not be specific
to a particular user or session.

Returns: nothing. If errors occur in the generator classes we log
them.

B<instance( $generator_name )>

Return an object representing the given content generator. If
C<$generator_name> is not found an exception is thrown.

Returns: an object with 
L<OpenInteract2::ContentGenerator|OpenInteract2::ContentGenerator>
as a parent.

=head2 Subclass Implementation Methods

B<initialize( \%configuration_params )>

Object method that gets called only once. Since this is normally at
server startup you can execute processes that are fairly intensive if
required.

The C<\%configuration_params> are pulled from the respective
'content_generator' section of the server configuration. So if you
had:

 [content_generator Foo]
 class     = OpenInteract2::ContentGenerator::Foo
 max_size  = 2000
 cache_dir = /tmp/foo

You would get the following hashref passed into
C<OpenInteract2::ContentGenerator::Foo>-E<gt>C<initialize>:

 {
   class     => 'OpenInteract2::ContentGenerator::Foo',
   max_size  => '2000',
   cache_dir => '/tmp/foo',
 }

You may also store whatever data in the object hashref required. The
parent class only uses 'name' and 'class', so as long as you keep away
from them you have free rein.

B<generate( \%template_params, \%content_params, \%template_source )>

Actually generates the content. This is the fun part!

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
