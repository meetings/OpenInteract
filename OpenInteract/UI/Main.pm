package OpenInteract::UI::Main;

# $Id: Main.pm,v 1.4 2001/09/21 17:10:44 lachoy Exp $

use strict;

sub handler {
    my ( $class ) = @_;
    my $R = OpenInteract::Request->instance;

    # Put the Popup and other directives here. A 'directive' exists
    # before the actual url and should have been parsed out in the main
    # Apache handler (see pkg/base/OpenInteract.pm). The value for the
    # directive should be the key in the 'template_names' configuration
    # information which is used below. More information about directives
    # in the POD.

    if ( my $directive = $R->{ui}{directive} ) { 
        if ( $directive =~ /^(NoTmpl|NoTemplate)$/ ) {
            $R->{page}{_no_template_}++;
            $R->DEBUG && $R->scrib( 1, "Using NO window template" );
        }
        else {
            $R->{page}{_template_key_} = $R->CONFIG->{page_directives}{ $directive };
            $R->DEBUG && $R->scrib( 1, "Using template key from directive: ($R->{page}{_template_key_})" );
        }
    }

    # Parse the URL and the information for our first action

    my ( $action_class, $action_method ) = $R->lookup_action;
    $R->DEBUG && $R->scrib( 1, "Action info: $action_class / $action_method" );

    # Capture any die() commands thrown; note that any error handler that
    # throws a die() needs to also return content to display; otherwise
    # it will be a pretty boring (empty) page :)

    $R->{page}{content} = eval { $action_class->$action_method({
                                        path => $R->{path}{current} }) };
    if ( $@ ) {
        $R->{page}{content} = $@;
        $R->scrib( 0, "Action died. Here is what it left: $@" );
    }

    # Do our special content cases

    return undef                 if ( $R->{page}{send_file} );
    return $R->{page}{content} if ( $R->{page}{_no_template_} );

    # $template_key here is being used to lookup a template name within a
    # theme

    my $template_key  = $R->{page}{_template_key_};
    $template_key   ||= 'simple_template' if ( $R->{page}{_simple_} );
    $template_key   ||= 'main_template';
    my $db_template_name = $R->{page}{_template_name_} || 
                           $R->{theme}->property_value( $template_key );
    my ( $template_pkg, $template_name ) = $R->site_template->parse_name( $db_template_name );
    unless ( $template_pkg and $template_name ) {
        $template_name = $db_template_name;
        $template_pkg  = 'base_theme';
    }

    $R->DEBUG && $R->scrib( 1, "Using template <<$db_template_name>> for full page" );
    $R->{main_template_vars} ||= {};

    return $R->template->handler( {}, 
                                  { %{ $R->{main_template_vars} },
                                    page => $R->{page} },
                                  { db      => $template_name,
                                    package => $template_pkg } );
}

1;

__END__

=pod

=head1 NAME

OpenInteract::UI::Main - The primary user interface assembly 'conductor'

=head1 SYNOPSIS

 my $page = OpenInteract::UI::Main->handler();
 send_http_headers();
 print $page;

=head1 DESCRIPTION

This is the handler that puts the main content generated together with
the template that surrounds the content on every page.

The action has already been parsed from the URL for us so we look up
the class/method used to generate the content and call them. We then
put that content into the main template which is specified in our
theme, unless we have received another directive to use a separate
template or no template at all.

Another alternative is that the content handler needs to return a file
that is not HTML, such as a PDF, graphic, word processing document,
archive, or whatever. If so the content handler should put the
B<complete filename> in the $R-E<gt>{page}-E<gt>{send_file} key.

A content author can set a main template to use for the generated
content by setting:

 $R->{page}{_template_name_}

to the name of the template to use. (This, and all templates named
here, should be found in the 'base_theme' package.)

You can also set a template that might vary by theme. This is not the
name of the template directly but rather a placeholder within the
theme which holds the name of the template. For instance, say you
created a 'spooky_template' and implemented it in multiple
themes. Even though you as an author do not know what theme will be
used, you can still pick the right template by setting:

 $R->{page}{_template_key_}

And to use the 'simple' template, the author should set:

 $R->{page}{_simple_}

to a true value. The default 'simple' template is 'base_simple',
although you can set its name under the C<template_names> key of your
server configuration.

Finally, the author can also set:

 $R->{page}{_no_template_}

to display the content without a template at all.

=head2 Main Template Variables

Any content handler can send information to be placed directly onto
the main template by setting information using the
$R-E<gt>{main_template_vars} hashref. For instance:

 $R->{main_template_vars}{current_weather} = 'Rainy and cold';

would set the 'current_weather' template variable for display on the
main template and B<not> on any of the content handlers.

Note that while this sounds useful (and it can be), you will probably
use it only very rarely. The 'boxes' concept is more comprehensive and
full-featured and will almost certainly do what you need.

=head1 METHODS

B<handler()>

Single method that performs the actions described above. Returns
either a single scalar with the full page generated or undef, in which
case the information to be sent is likely a non-HTML page that needs
to be sent on its own.

=head1 DIRECTIVES

A directive (or 'page directive') is placed before the relevant action
in the URL and tells OpenInteract to display the content in a certain
manner.

For instance:

 /Popup/User/show/?user_id=716

Says that OI should use the template corresponding to 'Popup' to
display the action 'User'. The correspondence is currently done in
this handler but this will change shortly.

The directives used are listed in the C<server.perl> file for a
website, under the C<page_directives> key.

=head1 TO DO

Nothing known, beyond write different ones of these (SOAP, etc.)

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
