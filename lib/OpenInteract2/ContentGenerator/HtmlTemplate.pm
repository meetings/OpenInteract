package OpenInteract2::ContentGenerator::HtmlTemplate;

# $Id: HtmlTemplate.pm,v 1.4 2003/07/02 05:10:13 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::ContentGenerator::TemplateSource;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use HTML::Template;

$OpenInteract2::ContentGenerator::HtmlTemplate::VERSION  = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use constant SOURCE_CLASS => 'OpenInteract2::ContentGenerator::TemplateSource';

sub initialize {
    my $log = get_logger( LOG_INIT );
    $log->is_info &&
        $log->info( "Called initialize() for HTML::Template CG (no-op)" );
}

sub process {
    my ( $class, $template_config, $template_vars, $template_source ) = @_;
    my $log = get_logger( LOG_TEMPLATE );

    # TODO: Check for cached content...

    my %init_params = ( die_on_bad_params => 0 );

    my ( $source_type, $source ) = SOURCE_CLASS->identify( $template_source );
    if ( $source_type eq 'NAME' ) {
        my ( $template, $filename, $modified ) =
                        SOURCE_CLASS->load_source( $source );
        $log->is_debug &&
            $log->debug( "Loading from name $source" );
        $init_params{scalarref} = ( ref $template eq 'SCALAR' )
                                    ? $template : \$template;
        $init_params{option}    = 'value';
    }
    elsif ( $source_type eq 'FILE' ) {
        $init_params{filename} = $source;
        $init_params{option}   = 'value';
    }
    else {
        $log->error( "Don't know how to load from source $source_type" );
        return "Cannot process template from source $source_type";
    }

    my $template = HTML::Template->new( %init_params );
    $template->param( $template_vars );
    my $content = $template->output;
    unless ( $content ) {
        my $msg = "Failed to fill in template for some unknown reason...";
        $log->error( $msg );
        oi_error $msg ;
    }

    # TODO: Cache content before returning

    return $content;
}

1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator::HtmlTemplate - Content generator using HTML::Template

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
