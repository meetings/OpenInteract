package OpenInteract2::ContentGenerator::TemplateSource;

# $Id: TemplateSource.pm,v 1.7 2003/08/27 15:50:18 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::ContentGenerator::TemplateSource::VERSION  = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub identify {
    my ( $class, $template_source ) = @_;
    my $log = get_logger( LOG_TEMPLATE );

    unless ( ref $template_source eq 'HASH' ) {
        $log->error( "Template source not hashref: ", ref $template_source );
        oi_error "Template source description must be passed as hashref";
    }

    my ( $source_type, $source, $name );

    if ( $template_source->{name} ) {
        $source_type = 'NAME';
        $name        = $template_source->{name};
        $source      = $name;
        $log->is_debug &&
            $log->debug( "Source template from name [$source]" );
    }

    elsif ( $template_source->{text} ) {
        $source_type = 'STRING';
        $source      = ( ref $template_source->{text} eq 'SCALAR' )
                         ? $template_source->{text}
                         : \$template_source->{text};
        $name        = '_anonymous_';
        $log->is_debug &&
            $log->debug( "Source template from raw text" );
    }

    elsif ( $template_source->{filehandle} ) {
        $source_type = 'FILE';
        $source      = $template_source->{filehandle};
        $log->is_debug &&
            $log->debug( "Source template from filehandle" );
    }

    elsif ( $template_source->{object} ) {
        $source_type = 'STRING';
        $source      = \$template_source->{object}{template};
        $name        = $template_source->{object}->create_name;
        $log->is_debug &&
            $log->debug( "Source template from template object [$name]" );
    }

    # TODO: Using 'db' will be deprecated soon...

    elsif ( $template_source->{db} ) {
        unless ( $template_source->{package} ) {
            oi_error  "Must give 'package' along with 'db' when processing ",
                      "template. [Given: $template_source->{db}]";
        }
        $source_type = 'NAME';
        $name        = join( '::', $template_source->{package},
                                   $template_source->{db} );
        $source      = $name;
        $log->is_debug &&
            $log->debug( "Source template from db/pkg [$name]" );
    }

    # Uh oh...

    else {
        $log->error( "No template to process! Information given for ",
                     "source:\n", Dumper( $template_source ) );
        oi_error "No template to process!";
    }

    if ( $name and CTX->controller->can( 'add_template_used' ) ) {
        CTX->controller->add_template_used( $name );
    }
    return ( $source_type, $source );
}

sub load_source {
    my ( $class, $name ) = @_;
    my $content_template = CTX->lookup_class( 'template' )->fetch( $name );
    unless ( $content_template ) {
       oi_error "Template with name [$name] not found.";
    }
    return ( $content_template->contents,
             $content_template->full_filename,
             $content_template->modified_on );
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator::TemplateSource - Common routines for loading content from OI2 templates

=head1 SYNOPSIS

 # Sample from Text::Template content generator
 
 sub process {
     my ( $class, $template_config, $template_vars, $template_source ) = @_;
     my $SOURCE_CLASS = 'OpenInteract2::ContentGenerator::TemplateSource';
     my ( $source_type, $source ) = SOURCE_CLASS->identify( $template_source );
     if ( $source_type eq 'NAME' ) {
         my ( $template, $filename, $modified ) =
                         SOURCE_CLASS->load_source( $source );
         $source_type = 'STRING';
         $source      = $template;
     }
     $template_config->{TYPE}   = $source_type;
     $template_config->{SOURCE} = $source;
     my $template = Text::Template->new( %{ $template_config } );
     unless ( $template ) {
         oi_error "Failed to create template parsing object: ",
                  $Text::Template::ERROR;
     }
     my $content = $template->fill_in( HASH => $template_vars );
     unless ( $content ) {
         oi_error "Failed to fill in template: $Text::Template::ERROR";
     }

=head1 CLASS METHODS

B<identify( \%template_source )>

Checks C<\%template_source> for template information and returns a
source type and source. Here are the types of information we check for
in C<\%template_source> and what's returned:

=over 4

=item *

Key B<name>: Set source type to 'NAME' and source to the value of the C<name> key.

=item *

Key B<text>: Set source type to 'STRING' and source to a scalar
reference with the value of the C<text> key. If C<text> is already a
reference it just copies the reference, otherwise it takes a reference
to the text in the key.

=item *

Key B<filehandle>: Set source type to 'FILE' and source to the
filehandle in C<filehandle>.

=item *

Key B<object>: Set source type to 'STRING' and source to a reference to
the content of the C<template> key of the
L<OpenInteract2::SiteTemplate|OpenInteract2::SiteTemplate> object in
C<object>.

=back

If none of these are found an exception is thrown.

Additionally, if we're able to pull a name from the template source
and the current L<OpenInteract2::Controller|OpenInteract2::Controller>
object can handle it, we call C<add_template_used()> on it, passing it
the template name.

Returns: two item list of source type and source.

B<load_source( $template_name )>

Fetches the template with the fully-qualified name C<$template_name>
and returns a three-item list with: contents, full filename, and the last
modified time.

If the template is not found we throw an exception, and any exception
thrown from the fetch propogates up.

Returns: a three-item list with: contents, full filename, and the last
modified time (which is a L<DateTime|DateTime> object).

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
