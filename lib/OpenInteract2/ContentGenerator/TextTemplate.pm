package OpenInteract2::ContentGenerator::TextTemplate;

# $Id: TextTemplate.pm,v 1.6 2003/07/02 05:09:52 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::ContentGenerator::TemplateSource;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Text::Template;

$OpenInteract2::ContentGenerator::TextTemplate::VERSION  = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use constant SOURCE_CLASS => 'OpenInteract2::ContentGenerator::TemplateSource';

sub initialize {
    my $log = get_logger( LOG_INIT );
    $log->is_info &&
        $log->info( "Called initialize() for Text::Template CG (no-op)" );
}

sub process {
    my ( $class, $template_config, $template_vars, $template_source ) = @_;
    my $log = get_logger( LOG_TEMPLATE );

    # TODO: Check for cached content...

    my ( $source_type, $source ) = SOURCE_CLASS->identify( $template_source );
    if ( $source_type eq 'NAME' ) {
        my ( $template, $filename, $modified ) =
                        SOURCE_CLASS->load_source( $source );
        $source_type = 'STRING';
        $source      = $template;
        $log->is_debug &&
            $log->debug( "Loading from name $source" );
    }
    else {
        $log->is_debug &&
            $log->debug( "Loading from source $source_type" );
    }
    $template_config->{TYPE}   = $source_type;
    $template_config->{SOURCE} = ( ref $source eq 'SCALAR' )
                                   ? $$source : $source;
    my $template = Text::Template->new( %{ $template_config } );
    unless ( $template ) {
        my $msg = "Failed to create template parsing object: " .
                  $Text::Template::ERROR;
        $log->error( $msg );
        oi_error $msg;
    }
    my $content = $template->fill_in( HASH => $template_vars );
    unless ( $content ) {
        my $msg = "Failed to fill in template: $Text::Template::ERROR";
        $log->error( $msg );
        oi_error $msg ;
    }

    # TODO: Cache content before returning

    return $content;
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator::TextTemplate - Content generator using Text::Template

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
