package OpenInteract2::App::BaseBox;

# $Id: BaseBox.pm,v 1.2 2005/03/10 01:24:56 lachoy Exp $

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::BaseBox::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::BaseBox::EXPORT  = qw( install );

my $NAME = 'base_box';

# Not a method, just an exported sub
sub install {
    my ( $website_dir ) = @_;
    my $manage = OpenInteract2::Manage->new( 'install_package' );
    $manage->param( website_dir   => $website_dir );
    $manage->param( package_class => __PACKAGE__ );
    return $manage->execute;
}

sub new {
    return OpenInteract2::App->new( $NAME );
}

sub get_brick {
    require OpenInteract2::Brick;
    return OpenInteract2::Brick->new( $NAME );
}

sub get_brick_name {
    return $NAME;
}

OpenInteract2::App->register_factory_type( $NAME => __PACKAGE__ );

1;

__END__

=pod

=head1 NAME

OpenInteract2::App::BaseBox - Manage input and output of independent boxes.

=head1 SYNOPSIS

 # Deposit all boxes in the current location on the page:
 [% OI.action_execute( 'boxes' ) %]
 
 # Define global box information in your server.ini
 [box]
 handler            = MyWebsite::Handler::Box
 default_template   = base_box::main_box_shell
 default_separator  = <br>
 default_method     = run_box
 system_box_handler = MyWebsite::Handler::SystemBoxes
 system_box_method  =
 custom_box_handler =
 custom_box_method  =
 
 # Define an OI action (in conf/action.ini) to be used for a box with
 # a class and method:
 [current_weather_box]
 class    = OpenInteract2::Action::Weather
 method   = box
 weight   = 5
 title    = Current Weather
 
 # Add a box ('name' maps to the above OI action):
 my $zip = $self->request->auth_user->{zipcode};
 my $box = { name   => 'current_weather_box',
             weight => 2,
             title  => "Weather in Zip Code $zip",
             params => { zip_code => $zip };
 $self->controller->add_box( $box );
 
 # Add the same box from a template:
 [% user_zip = OI.login.zip_code;
    OI.box_add( 'current_weather_box',
                weight   = 2,
                title    = "Weather in Zip Code $user_zip",
                zip_code = $user_zip ) -%]
 
 # Define an OI action (in conf/action.ini) to be used for a
 # template-only box:
 [frequent_links_box]
 name       = frequent_links_box
 template   = mypkg::box_frequent_links
 weight     = 8
 title      = Frequent Links
 security   = no
 
 # Add a template-only box, overriding weight and title:
 my $box = { name   => 'frequent_links_box',
             weight => 2,
             title  => "Most visited sites" };
 push $self->controller->add_box( $box );
 
 # Add the same box from a template, overriding title:
 [% OI.box_add( 'frequent_links_box',
                title  = 'Most visited sites' ) %]
 
 # Remove a box added in another part of the system
 $self->controller->remove_box( 'motd' );
 
 # Remove the same box from a template
 [% OI.box_remove( 'motd' ) %]

=head1 DESCRIPTION

See docs in L<OpenInteract2::Action::Box|OpenInteract2::Action::Box>
for everything you can do with boxes and how to configure them..

=head1 OBJECTS

No objects created by this package.

=head1 ACTIONS

The following actions are created by this package:

B<boxes>

Content component that returns all boxes with content generated and in
their shells.

B<object_modify_box>

Box for editing/removing an object. (Has aliases 'object_mod_box' and
'objectmodbox'.)

B<login_box>

Box with username/password for users to login.

B<user_info_box>

Box with username and link to page to edit information.

B<admin_tools_box>

Links to various administrator tools for maintaining the website.

B<powered_by_box>

Box with static content displaying the tools used in the website
(mod_perl, Template Toolkit, OpenInteract).

=head1 RULESETS

No rulesets created by this package.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

=cut
