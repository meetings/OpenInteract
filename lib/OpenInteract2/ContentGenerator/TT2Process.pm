package OpenInteract2::ContentGenerator::TT2Process;

# $Id: TT2Process.pm,v 1.7 2003/07/02 05:09:45 lachoy Exp $

use strict;
use Data::Dumper             qw( Dumper );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::ContentGenerator::TemplateSource;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::ContentGenerator::TT2Context;
use OpenInteract2::ContentGenerator::TT2Plugin;
use OpenInteract2::ContentGenerator::TT2Provider;
use Template;

$OpenInteract2::ContentGenerator::TT2Process::VERSION  = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_COMPILE_EXT => '.ttc';
use constant DEFAULT_CACHE_SIZE  => 75;
use constant SOURCE_CLASS        => 'OpenInteract2::ContentGenerator::TemplateSource';

my ( $CUSTOM_VARIABLE_SUB, $CUSTOM_VARIABLE_NAME );

########################################
# GENERATE CONTENT

sub process {
    my ( $class, $template_config, $template_vars, $template_source ) = @_;
    my $log = get_logger( LOG_TEMPLATE );
    my $server_config = CTX->server_config;

    my ( $source_type, $source ) = SOURCE_CLASS->identify( $template_source );
    my ( $name );

    # TODO: We're losing information (name) if an object is passed in,
    # but that might be ok because (a) it's not done often (ever?) and
    # (b) it's only necessary for the custom_variable_class

    if ( $source_type eq 'NAME' ) {
        $name = $source;
        my ( $text, $filename, $modtime ) =
            SOURCE_CLASS->load_source( $name );
        $source = \$text;
    }
    else {
        $name = '_anonymous_';
    }

    $log->is_debug &&
        $log->debug( "Processing template [$name]" );

    # Grab the template object and the OI plugin, making the OI plugin
    # available to every template

    my $template         = CTX->template;
    $template_vars->{OI} = $template->context->plugin( 'OI' );

    if ( $CUSTOM_VARIABLE_SUB ) {
        $log->is_debug &&
            $log->debug( "Running custom template variable ",
                         "handler [$CUSTOM_VARIABLE_NAME]" );
        eval {
            $CUSTOM_VARIABLE_SUB->( $name, $template_vars )
        };
        if ( $@ ) {
            $log->error( "Custom template handler [$CUSTOM_VARIABLE_NAME] ",
                         "died; I'm going to keep processing. Error: $@" );
        }
        else {
            $log->is_debug &&
                $log->debug( "Ran custom template variable handler ok" );
        }
    }

    my ( $html );
    $template->process( $source, $template_vars, \$html )
                    || oi_error "Cannot process template [$name]: ", $template->error();
    $log->is_debug &&
        $log->debug( "Processed template ok" );
    return $html;
}

########################################
# INITIALIZATION

# Since each website gets its own template object, when we call
# initialize() all the website's information has been read in and
# setup so we should be able to ask the config object what plugin
# objects are defined, etc.

sub initialize {
    my ( $class ) = @_;
    my $log = get_logger( LOG_TEMPLATE );
    $log->is_debug &&
        $log->debug( "Starting template object init" );
    my $server_config = CTX->server_config;

    $Template::Config::CONTEXT = 'OpenInteract2::ContentGenerator::TT2Context';
    my $tt_config = $class->_init_tt_config;

    # Install various template configuration items (currently plugins)
    # as specified by packages

     $class->_package_template_config( $tt_config );

    # Create the configuration for this TT object and give the user a
    # chance to add to or modify it

    my $oi_tt_config = $server_config->{template_info};
    if ( my $init_class = $oi_tt_config->{custom_init_class} ) {
        eval "require $init_class";
        if ( $@ ) {
            $log->error( "Custom init class [$init_class] not available; ",
                         "continuing... Error: $@" );
        }
        else {
            my $init_method = $oi_tt_config->{custom_init_method}
                              || 'handler';
            my $init_desc = "$init_class\-\>$init_method";
            $log->is_debug &&
                $log->debug( "Running custom template init: [$init_desc]" );
            eval { $init_class->$init_method( $tt_config ) };
            if ( $@ ) {
                $log->error( "Failed custom template init [$init_desc]; ",
                             "continuing... Error: $@" );
            }
            else {
                $log->is_debug &&
                    $log->debug( "Custom template init ok" );
            }
        }
    }

    # Allow websites to modify the template variables passed to every
    # page -- initialize the subroutine here

    my $custom_variable_class = $server_config->{template_info}{custom_variable_class};
    if ( $custom_variable_class ) {
        eval "require $custom_variable_class";
        if ( $@ ) {
            $log->error( "Custom variable class [$custom_variable_class]",
                         "not available [$@]. Continuing..." );
        }
        else {
            my $custom_variable_method = $server_config->{template_info}{custom_variable_method}
                                         || 'handler';
            no strict 'refs';
            $CUSTOM_VARIABLE_NAME = join( '::', $custom_variable_class,
                                                $custom_variable_method );
            $CUSTOM_VARIABLE_SUB  = \&{ $CUSTOM_VARIABLE_NAME };
        }
    }

    # Put the configured OI provider in the mix. Note that we do this
    # AFTER the customization process so the user can set cache size,
    # compile directory, etc.

    my $oi_provider = OpenInteract2::ContentGenerator::TT2Provider->new(
                              CACHE_SIZE  => $tt_config->{CACHE_SIZE},
                              COMPILE_DIR => $tt_config->{COMPILE_DIR},
                              COMPILE_EXT => $tt_config->{COMPILE_EXT}, );
    unshift @{ $tt_config->{LOAD_TEMPLATES} }, $oi_provider;

    #DEBUG && LOG( LDEBUG, "TT Configuration:", Dumper( $tt_config ) );
    my $template = Template->new( %{ $tt_config } );
    unless ( $template ) {
        oi_error "Template object not created: ", Template->error();
    }

    # TODO: Assign the template to the same key used for the content
    # generator (so we can have multiple template objects)

    CTX->template( $template );
    $log->is_info &&
        $log->info( "Template Toolkit object created properly ",
                         "and assigned to CTX ok" );
    return;
}


sub _init_tt_config {
    my ( $class ) = @_;
    my $server_config = CTX->server_config;
    my $oi_tt_config  = $server_config->{template_info};

    # Default configuration -- this can be modified by each site

    my $cache_size  = ( defined $oi_tt_config->{cache_size} )
                        ? $oi_tt_config->{cache_size}
                        : DEFAULT_CACHE_SIZE;
    my $compile_ext = $oi_tt_config->{compile_ext} || DEFAULT_COMPILE_EXT;
    my $compile_dir = $server_config->{dir}{cache_tt};

    # If the compile_dir isn't specified, be sure to set it **and**
    # the extension to undef, otherwise TT will try to compile/save
    # the templates into the directory we find them (maybe: the custom
    # provider might override, but whatever)

    unless ( defined $compile_dir ) {
        $compile_ext = undef;
        $compile_dir = undef;
    }

    return { PLUGINS     => { OI => 'OpenInteract2::ContentGenerator::TT2Plugin' },
             CACHE_SIZE  => $cache_size,
             COMPILE_DIR => $compile_dir,
             COMPILE_EXT => $compile_ext };
}

sub _package_template_config {
    my ( $class, $config ) = @_;
    my $log = get_logger( LOG_TEMPLATE );

    # Find all the packages in this website

    my $pkg_list = CTX->packages;
    $log->is_debug &&
        $log->debug( "Packages read ok for template init" );

    # For each package in the site...

    foreach my $pkg ( @{ $pkg_list } ) {
        next unless ( ref $pkg->{template_plugin} eq 'HASH' );

        # ... read in the template plugins
        foreach my $plugin_tag ( keys %{ $pkg->{template_plugin} } ) {
            my $plugin_class = $pkg->{template_plugin}{ $plugin_tag };
            $log->is_debug &&
                $log->debug( "Template plugin [$plugin_tag] =>",
                             "[$pkg->{template_plugin}{ $plugin_tag }]" );
            eval "require $plugin_class";
            if ( $@ ) {
                $log->error( "Plugin [$plugin_tag] [$plugin_class] from ",
                             " package [$pkg->{name}] failed: $@" );
            }
            else {
                $config->{PLUGINS}{ $plugin_tag } = $plugin_class;
            }
        }
    }
}


1;

__END__

=head1 NAME

OpenInteract2::ContentGenerator::TT2Process - Process Template Toolkit templates in OpenInteract

=head1 SYNOPSIS

 # NOTE: You will probably never deal with this class. It's don'e
 # behind the scenes for you in the '$action->generate_content' method
 
 # Specify an object by fully-qualified name (preferrred)
 my $proc_class = 'OpenInteract2::ContentGenerator::TT2Process';
 my $html = $proc_class->process( { key => 'value' },
                                  { name => 'my_pkg::this_template' } );
 
 # Directly pass text to be parsed (fairly rare)
 
 my $little_template = 'Text to replace -- here is my login name: ' .
                       '[% login.login_name %]';
 my $html = $proc_class->process( {}, { key => 'value' },
                                  { text => $little_template } );
 
 # Pass the already-created object for parsing (rare)
 
 my $site_template_obj = CTX->template_class->fetch( 'base_main' );
 my $html = $proc_class->process( {}, { key => 'value' },
                                  { object => $site_template_obj } );

=head1 DESCRIPTION

This class processes templates within OpenInteract. The main method is
C<process()> -- just feed it a template name and a whole bunch of keys
and it will take care of finding the template (from a database,
filesystem, or wherever) and generating the finished content for you.

Shorthand used below: TT == Template Toolkit.

=head1 INITIALIZATION

B<initialize( \%config )>

Creates a TT processing object with necessary parameters and returns
it. We generally call C<initialize()> from
L<OpenInteract2::Context|OpenInteract2::Context> on the first request
for a template object. Each website running in the same process gets
its own template object.

Since we create one TT object per website, we can initialize that
object with website-specific information. So the initialization
process steps through the packages available in the website and asks
each one for its list of template plugins. Once retrieved, the TT
object is started up with them and they are available via the normal
means.

Package plugins created in this matter are available either via:

 [% USE MyPlugin %]

or by defining a C<custom_variable_class> for the template and setting
the plugin to be available without the TT 'use' statement. (See below
for details.)

Note that you can also define custom initialization methods (on a
global website basis) as described below.

=head2 Custom Initialization

You can define information in the server configuration of your website
that enables you to modify the configuration passed to the C<new()>
method of L<Template|Template>.

In your server configuration, define values for the keys
C<template_info.custom_init_class> and
C<template_info.custom_init_method>. The class/method combination (if
you do not specify a method name, 'handler' will be used) get passed
the template configuration hashref, which you can modify as you see
fit. There are many variables that you can change; learn about them at
L<Template::Manual::Config|Template::Manual::Config>.

Assume that TT can use the configuration variable 'SUNSET' to do
something. To set the variable:

 # In conf/server.ini
 
 [template_info]
 ...
 custom_init_class  = MyCustom::Template
 custom_init_method = initialize

 # In MyCustom/Template.pm:
 
 package MyCustom::Template;
 
 use strict;
 
 sub initialize {
     my ( $class, $template_config ) = @_;
     $template_config->{SUNSET} = '7:13 AM';
 }

Easy! Since this is a normal Perl method, you can perform any actions
you like here. For instance, you can retrieve templates from a website
via LWP, save them to your package template directory and process them
via PROCESS/INCLUDE as you normally would.

Note that C<initialize()> should only get executed once for every
website for every Apache child; most of the time this is fairly
infrequent, so you can execute code here that takes a little more time
than if it were being executed with every request.

=head1 PROCESSING

B<process( \%template_params, \%template_variables, \%template_source )>

Generate template content, given keys and values in
C<\%template_variables> and a template identifier in
C<\%template_source>.

Parameters:

=over 4

=item *

B<template_params> (\%)

Configuration options for the template. Note that you can set defaults
for these at configuration time as well.

=item *

B<template_variables> (\%)

The key/value pairs that will get plugged into the template. These can
be arbitrarily complex, since the Template Toolkit can do anything :-)

=item *

B<template_source>

Tell the method how to find the source for the template you want to
process. There are a number of ways to do this:

Method 1: Use a combined name (preferred method)

 name    => 'package_name::template_name'

Method 2: Specify the text yourself

 text    => $scalar_with_text
 or
 text    => \$scalar_ref_with_text

Method 3: Specify an object of type
L<OpenInteract2::SiteTemplate|OpenInteract2::SiteTemplate>

 object => $site_template_obj

=back

=head2 Custom Processing

You have the opportunity to step in during the executing of
C<process()> with every request and set template variables. To do so,
you need to define a handler and tell OI where it is.

To define the handler, just define a normal Perl class method that
gets two arguments: the name of the current template (in
'package::name' format) and the template variable hashref:

 sub my_variable {
     my ( $class, $template_name, $template_vars ) = @_;
     ...
 }

To tell OI where your handler is, in your server configuration file
specify:

 [template_info]
 custom_variable_class  = MyCustom::Template
 custom_variable_method = variable

Either the 'custom_variable_method' or the default method name
('handler') will be called.

You can set (or, conceivably, remove) information bound for every
template. Variables set via this method are available to the template
just as if they had been passed in via the C<process()> call.

Example where we make a custom plugin (see C<initialize()> above)
available to every template:

  # In server.ini:
 
  [template_info]
  custom_variable_class  = MyCustom::Template
  custom_variable_method = variable

  # In MyCustom/Template.pm:
 
  package MyCustom::Template;
 
  use strict;
 
  sub variable {
      my ( $class, $template_name, $template_vars ) = @_;
      $template_vars->{MyPlugin} = CTX->template               # gets the default template object...
                                      ->context                # ...gets the TT2 context
                                      ->plugin( 'MyPlugin' );  # ...sets our plugin
  }
 
  1;

Using this process, our templates will not need to execute a:

 [% USE MyPlugin %]

before using the methods in the plugin.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<Template|Template>

L<OpenInteract2::ContentGenerator::TT2Context|OpenInteract2::ContentGenerator::TT2Context>

L<OpenInteract2::ContentGenerator::TT2Plugin|OpenInteract2::ContentGenerator::TT2Plugin>

L<OpenInteract2::ContentGenerator::TT2Provider|OpenInteract2::ContentGenerator::TT2Provider>

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
