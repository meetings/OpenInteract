package OpenInteract2::Action::Box;

# $Id: Box.pm,v 1.12 2005/03/18 04:09:42 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use Data::Dumper             qw( Dumper );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );

$OpenInteract2::Action::Box::VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @BOX_KEYS = qw( title weight base_template image image_alt );

my ( $BOX_CONFIG,
     $SYSTEM_REQUIRED, $SYSTEM_BOX_CLASS, $SYSTEM_BOX_METHOD,
     $CUSTOM_REQUIRED, $CUSTOM_BOX_CLASS, $CUSTOM_BOX_METHOD );

my $DEFAULT_WEIGHT = 5;
my $MAX_WEIGHT     = 100;

sub process_boxes {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    $BOX_CONFIG ||= CTX->lookup_box_config;

    my @base_actions = $self->_create_box_actions;
    push @base_actions, $self->_create_system_boxes;
    push @base_actions, $self->_create_custom_boxes;

    my $controller = CTX->controller;
    @base_actions = grep {
        ! $controller->is_box_removed( $_->{name} )
    } @base_actions;

    $log->is_info &&
        $log->info( "Found ", scalar( @base_actions ), " boxes to process ",
                    "after getting all boxes (added, system and custom) ",
                    "and ensuring that none of them are to be removed" );

    my @sorted_actions =
        sort { $a->param( 'weight' ) <=> $b->param( 'weight' ) ||
               $a->name cmp $b->name }
        @base_actions;
    my $shell_template = $self->_get_shell_template;
    my @box_content = $self->_generate_box_content( \@sorted_actions,
                                                    $shell_template );

    my $sep_string = CTX->request->theme_values->{box_separator}
                     || $BOX_CONFIG->{default_separator}
                     || '';
    return join( $sep_string, @box_content );
}

# First, do the system boxes -- this puts box information into the box
# holding area. (We need to be sure we always have access to the
# system box class...)

sub _create_system_boxes {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $SYSTEM_REQUIRED ) {
        $SYSTEM_BOX_CLASS = $BOX_CONFIG->{system_box_handler};
        eval "require $SYSTEM_BOX_CLASS";
        if ( $@ ) {
            $log->error( "FAILED: cannot include system box class ",
                         "'$SYSTEM_BOX_CLASS': $@" );
            $SYSTEM_BOX_CLASS = undef;
            return ();
        }
        else {
            $SYSTEM_BOX_METHOD = $BOX_CONFIG->{system_box_method}
                                 || $self->param( 'box_default_method' );
            $SYSTEM_REQUIRED++;
        }
    }

    return () unless ( $SYSTEM_BOX_CLASS and $SYSTEM_BOX_METHOD );
    my @boxes = eval { $SYSTEM_BOX_CLASS->$SYSTEM_BOX_METHOD() };
    if ( $@ ) {
        $log->error( "FAILED: cannot execute system box method ",
                     "$SYSTEM_BOX_CLASS->$SYSTEM_BOX_METHOD: $@" );
    }
    return @boxes;
}

# If a website has boxes that it's adding on every page it can do so
# in code rather than in a template. Note that this handler can call
# other handlers as it deems necessary, so that the framework doesn't
# care about the application-specific usage.

sub _create_custom_boxes {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $CUSTOM_REQUIRED ) {
        $CUSTOM_BOX_CLASS = $BOX_CONFIG->{custom_box_handler};
        if ( $CUSTOM_BOX_CLASS ) {
            eval "require $CUSTOM_BOX_CLASS";
            if ( $@ ) {
                $log->error( "FAILED: cannot require custom box class ",
                             "'$CUSTOM_BOX_CLASS': $@" );
                return ();
            }
            else {
                $CUSTOM_BOX_METHOD = $BOX_CONFIG->{custom_box_method}
                                     || $self->param( 'box_default_method' );
                $CUSTOM_REQUIRED++;
            }
        }
    }

    return () unless ( $CUSTOM_BOX_CLASS and $CUSTOM_BOX_METHOD );
    $log->is_info &&
        $log->info( "Calling custom box handler:",
                    "$CUSTOM_BOX_CLASS\->$CUSTOM_BOX_METHOD" );
    my @boxes = eval { $CUSTOM_BOX_CLASS->$CUSTOM_BOX_METHOD() };
    if ( $@ ) {
        $log->error( "FAILED: cannot call custom box handler ",
                     "$CUSTOM_BOX_CLASS\->$CUSTOM_BOX_METHOD: $@" );
    }
    return @boxes;
}

# Generate the action object for each box

sub _create_box_actions {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my @actions = ();

BOX:
    foreach my $box_info ( @{ CTX->controller->get_boxes } ) {
        my $use_info = ( ref $box_info )
                         ? $box_info : { name => $box_info };
        unless ( $use_info->{name} ) {
            $log->error( "Skipping box added without a name:\n",
                         Dumper( $use_info ) );
            next BOX;
        }

        # Now lookup box action

        my $box_action = eval { CTX->lookup_action( $use_info->{name} ) };
        if ( $@ and $use_info->{is_template} eq 'yes' ) {
            $box_action = eval { CTX->lookup_action( 'template_only' ) };
            if ( $@ ) {
                oi_error "Cannot create 'template_only' action -- this ",
                         "should be in the 'base' package but I could not ",
                         "find it."
            }
            $box_action->param( template => $use_info->{name} );
        }
        elsif ( $@ ) {
            $log->warn( "Skipping box '$use_info->{name}', not found in ",
                        "the action table and 'is_template' not set to 'yes'" );
            next BOX;
        }

        # Override the default keys with information set in the box
        # addition

        foreach my $box_key ( @BOX_KEYS ) {
            next unless ( $use_info->{ $box_key } );
            $box_action->param( $box_key, $use_info->{ $box_key } );
            $log->is_debug &&
                $log->debug( "Adding box_key parameter to box: '$box_key' '$use_info->{ $box_key }'" );
            delete $use_info->{ $box_key };
        }

        foreach my $param_name ( keys %{ $use_info->{params} } ) {
            $log->is_debug &&
                $log->debug( "Adding parameter to box: '$param_name' ",
                             "'$use_info->{params}{ $param_name }'" );
            $box_action->param( $param_name, $use_info->{params}{ $param_name } );
        }

        # Assign default weight if not already there and if the weight
        # is too large skip the box entirely

        unless ( $box_action->param( 'weight' ) ) {
            $box_action->param( 'weight', $DEFAULT_WEIGHT );
        }
        if ( $box_action->param( 'weight' ) > $MAX_WEIGHT ) {
            $log->warn( "Skipping box '$use_info->{name}' since ",
                        "its weight is more than the max of ", $MAX_WEIGHT );
            next BOX;
        }

        $log->is_debug &&
            $log->debug( "Putting box '$use_info->{name}' onto the",
                         "stack with weight '$use_info->{weight}'" );
        push @actions, $box_action;
    }
    return @actions;
}

# Grab the template that we'll plug the box content into

sub _get_shell_template {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $box_template_name = CTX->request->theme_values->{box_template}
                            || $BOX_CONFIG->{default_template}
                            || $self->param( 'box_default_template' );
    unless ( $box_template_name =~ /::/ ) {
        $log->warn( "Box shell '$box_template_name' is not a ",
                    "valid package::name spec; using naked boxes" );
        $box_template_name = undef;
    }
    $log->is_debug &&
        $log->debug( "Using box shell template '$box_template_name'" );
    return $box_template_name;
}


# Generate content for each box

sub _generate_box_content {
    my ( $self, $actions, $shell_template ) = @_;
    $log ||= get_logger( LOG_APP );

    my @content = ();
    $log->is_debug &&
        $log->debug( "Sorted boxes currently in the list:",
                     join( ' | ', map { $_->name } @{ $actions } ) );
ACTION:
    foreach my $action ( @{ $actions } ) {
        my $shell_params = {};

        # Treat the box as a component and get the html back

        my $base_content = $action->execute();

        # If the user has requested to keep this box 'naked', don't
        # wrap it in the shell

        if ( $action->param( 'base_template' ) eq
                 $self->param( 'box_blank_shell_template' ) ) {
            push @content, $base_content;
            $log->is_debug &&
                $log->debug( "No wrapper template used by request, ",
                             "box is naked! (cover your eyes)" );
            next ACTION;
        }
        $shell_params->{content} = $base_content;
        $shell_params->{label} = $action->message_from_key_or_param(
            'title', 'title_key' );
        $shell_params->{label_image_src} = $action->message_from_key_or_param(
            'title_image_src', 'title_image_src_key' );
        $shell_params->{label_image_alt} = $action->message_from_key_or_param(
            'title_image_alt', 'title_image_alt_key' );
        push @content, $action->generate_content( $shell_params,
                                                  { name => $shell_template } );
    }
    return @content;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::Box -- Handle input and output for independent "boxes"

=head1 SYNOPSIS

 # Deposit all boxes in the current location on the page:
 [% OI.action_execute( 'boxes' ) %]
 
 # Define global box information in server configuration
 # ($WEBSITE/conf/server.ini)
 
 [box]
 handler            = MyWebsite::Handler::Box
 default_template   = base_box::main_box_shell
 default_separator  = <br>
 default_method     = run_box
 system_box_handler = MyWebsite::Handler::SystemBoxes
 system_box_method  =
 custom_box_handler =
 custom_box_method  =
 
 # Define an OI action (in mypkg/conf/action.ini) to be used for a box
 # with a class and method:
 
 [current_weather_box]
 class    = OpenInteract2::Action::Weather
 method   = box
 weight   = 5
 title    = Current Weather

 # Add a box ('name' maps to the above OI action):
 
 my $zip = CTX->request->auth_user->{zipcode};
 my $box = { name   => 'current_weather_box',
             weight => 2,
             title  => "Weather in Zip Code $zip",
             params => { zip_code => $zip };
 CTX->controller->add_box( $box );

 # Add the same box from a template:
 
 [% user_zip = OI.login.zip_code;
    OI.box_add( 'current_weather_box',
                weight   = 2,
                title    = "Weather in Zip Code $user_zip",
                zip_code = $user_zip ) -%]

 # Define an OI action (in conf/action.ini) to be used for a
 # template-only box, using a localization key instead of a direct
 # title :
 
 [frequent_links_box]
 name       = frequent_links_box
 template   = mypkg::box_frequent_links
 weight     = 8
 title_key  = frequent_links.title
 security   = no

 # Add a template-only box, overriding weight and title:
 
 my $box = { name   => 'frequent_links_box',
             weight => 2,
             title  => "Most visited sites" };
 CTX->controller->add_box( $box );

 # Add the same box from a template, overriding title:
 
 [% OI.box_add( 'frequent_links_box',
                title  = 'Most visited sites' ) %]

 # Remove a box added in another part of the system
 
 CTX->controller->remove_box( 'motd' );

 # Remove the same box from a template
 
 [% OI.box_remove( 'motd' ) %]

=head1 DESCRIPTION

Boxes are standalone parcels of content that conform to a particular
format. Think of each box as an OpenInteract action: that action may
be a piece of code (method in a class) or it may simply be a template.

In either case, the action generates content and the box handler sorts
the boxes and places the content for each in a 'shell' so all the
boxes look the same. The standard box looks something like this:

 ------------------------- <-- 'shell'
 |      BOX TITLE        |
 -------------------------
 | Box content as        |
 | generated by an       |
 | action or a           |
 | template goes here    |
 -------------------------

But you can create your own shell by defining the key 'box_template'
in your theme to be a particular template (in the
'package::template_name' format) or by setting the global
configuration key 'box.default_template'.

=head1 CONFIGURATION

This module allows you to define default information in two separate
locations for a number of parameters.

=head2 Server Configuration

In the server configuration found in every OpenInteract website, you
can define certain information for your boxes under the 'box' key:

=over 4

=item *

B<handler> ($) (mandatory)

Define the class that will be used to process the boxes. Unless you
write your own class, this will B<always> be
C<OpenInteract2::Action:Box> and should not be changed.

=item *

B<separator> ($) (optional)

This is the string used to separate boxes. For instance, if you want
to put a short horizontal rule between each line, you could set this
to:

  separator = <hr width="50%" noshade/>

Or if you had a custom image you wanted to separate your boxes with:

  separator = <div align="center"><img src="/images/box_sep.gif" height="2" width="25"/></div>

This module defines the default separator as '<br>'. It will be used
only if there is no separator defined in the theme or in the server
configuration.

=item *

B<default_method> ($) (optional)

Define the method that will be used by boxes that do not specify
one. This module defines the default method as 'handler' and unless
you know what you are doing you should not change it.

=item *

B<default_template> ($) (optional)

This is the template into which every box content gets put. Normally
this is defined in the theme, but if for some reason someone blanked
the template out this will fill in.

The default template is C<base_box::main_box_shell>, which as the name
would indicate is installed with this package.

=item *

B<system_box_handler> ($) (optional)

Defines what we should run on every request to display system
boxes. See
L<OpenInteract2::Action::SystemBoxes|OpenInteract2::Action::SystemBoxes>
for what this includes.

It is okay if you blank this out, you just will not get the 'login',
'templates_used' and other boxes on every page.

=item *

B<system_box_method> ($) (optional)

Method to call on the C<system_box_handler> defined above.

=item *

B<custom_box_handler> ($) (optional)

If you want to call a custom handler to run every time B<in addition
to> the system handler named above, list the class here.

=item *

B<custom_box_method> ($) (optional)

Method to call on the C<custom_box_handler> named above.

=back

=head2 Theme Properties

Two properties of the boxes can be defined on a per-theme basis.

=over 4

=item *

B<box_template> ($) (optional)

This is the template into which the box content gets put. OpenInteract
ships with one theme which has this property set to 'main_box_shell',
which is used if you do not specify anything. However, you can define
additional themes and change the look of a box entirely by modifying
this template.

=item *

B<box_separator> ($) (optional, but recommended)

See the discussion of B<separator> above in the L<Server
Configuration> section.

=back

=head2 Box Properties

An individual box also has a say as to how it will be rendered as well
as the content it will have.

The simplest case is a call:

 CTX->controller->add_box( 'mypkg::my_box_template' );

Which simply uses the scalar passed in as the template name and the
box name, and uses all the defaults. However, you will likely get a
box with a title 'Generic Box', which is probably not what you want.

Another example:

 CTX->controller->add_box({ template => 'mypkg::mybox',
                            weight   => 1,
                            title    => 'My First Box' });

Each box can define the following parameters:

=over 4

=item *

B<name> ($)

Just used to identify the box; if not provided we use the 'template'
parameter.

=item *

B<title> ($) (optional)

Display name of box used in the 'shell' wrapper, if you elect to use
that.

=item *

B<title_key> ($) (optional)

Localization key to use for box title, generally used in place of
'title' and if both are present this will be used.

=item *

B<title_image_src> ($) (optional)

Display an image for the title to be used in the 'shell' wrapper.

=item *

B<title_image_src_key> ($) (optional)

Localization key to use for image title, generally used in place of
'title_image_src' and if both are present this will be used.

=item *

B<title_image_alt> ($) (optional)

Text to put in the 'alt' tag if using an image in the title.

=item *

B<title_image_alt_key> ($) (optional)

Localization key to use for the 'alt' tag in the image title,
generally used in place of 'title_image_alt' and if both are present
this will be used.

=item *

B<weight> ($)

Number between 1 (top) and 10 (bottom) indicating where you want the
box to be. If you do not specify the weight the constant from this
class DEFAULT_BOX_WEIGHT will be used. (Normally this is 5.)

=item *

B<box_template> ($) (optional)

If you specify the keyword '_blank_' then your box content will be
'naked' and not wrapped by anything else. If you leave this empty you
will use either the box_template property in your theme, the
'box_template' defined in your server configuration, or the
DEFAULT_TEMPLATE defined in this class.

=item *

B<params> (\%) (optional)

Whatever you pass here will passed through to the template or method
that is implementing the box.

=back

=head1 TO DO

B<Cache base templates (wrappers)>

The base template wrapper should be cached in the handler so we do not
need to fetch it every time.

B<Flexible base_template handling>

Right now we allow you to use either the default base_template wrapper
(defined in either the theme or the server config) or none at all. We
need to allow each box to define its own wrapper.

=head1 SEE ALSO

L<OpenInteract2::SiteTemplate|OpenInteract2::SiteTemplate>,
L<OpenInteract2::Theme|OpenInteract2::Theme>

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
