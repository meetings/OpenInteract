package OpenInteract2::ContentGenerator::TextTemplate;

# $Id: TextTemplate.pm,v 1.2 2003/06/11 02:43:30 lachoy Exp $

use strict;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::ContentGenerator::TemplateSource;
use OpenInteract2::Context   qw( DEBUG LOG CTX );
use OpenInteract2::Exception qw( oi_error );
use Text::Template;

use constant SOURCE_CLASS => 'OpenInteract2::ContentGenerator::TemplateSource';

sub initialize {
    # no-op
}

sub process {
    my ( $class, $template_config, $template_vars, $template_source ) = @_;
    my ( $source_type, $source ) = SOURCE_CLASS->identify( $template_source );
    if ( $source_type eq 'NAME' ) {
        my ( $template, $filename, $modified ) =
                        SOURCE_CLASS->load_source( $source );
        $source_type = 'TEXT';
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
