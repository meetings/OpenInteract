package OpenInteract::Template::Process;

# $Id: Process.pm,v 1.7 2001/08/28 22:23:52 lachoy Exp $

use strict;
use OpenInteract::Template::Context;
use OpenInteract::Template::Plugin;
use OpenInteract::Template::Provider;
use Template;

$OpenInteract::Template::Process::VERSION  = '1.2';
$OpenInteract::Template::Process::Revision = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

# Display an OI document

sub handler {
    my ( $class, $template_config, $template_vars, $template_source ) = @_;
    my $R = OpenInteract::Request->instance;

    my ( $to_process );
    if ( $template_source->{text} ) {
        $to_process = \$template_source->{text};
        $R->DEBUG && $R->scrib( 1, "Using raw template source for processing" );
    }
    elsif ( $template_source->{object} ) {
        $to_process = \$template_source->{object}->{template};
        push @{ $R->{templates_used} }, $template_source->{object}->create_name;
        $R->DEBUG && $R->scrib( 1, "Using template object for processing" );
    }
    else {
        my $name = $template_source->{db} ||
                   $template_source->{file} ||
                   $template_source->{name};
        unless ( $name ) {
            die "No name given!";
        }

        # Fix this later to build and review the name properly, blah blah blah
        $to_process = ( $name =~ /::/ ) ? $name : $template_source->{package} . '::' . $name;
        push @{ $R->{templates_used} }, $to_process;
        $R->DEBUG && $R->scrib( 1, "Using template name ($to_process) for processing" );
    }

    # Grab the template object and the OI plugin, making the OI plugin
    # available to every template

    my $template = $R->template_object;
    $template_vars->{OI} = $template->context->plugin( 'OI' );
    my ( $html );
    $template->process( $to_process, $template_vars, \$html )
         || die "Cannot process template!", $template->error();
    return $html;
}


sub initialize {
    my ( $class ) = @_;
    $Template::Config::CONTEXT = 'OpenInteract::Template::Context';
    my $template = Template->new(
                       PLUGINS        => { OI => 'OpenInteract::Template::Plugin' },
                       COMPILE_DIR    => '/tmp/ttc',
                       COMPILE_EXT    => '.ttc',
                       LOAD_TEMPLATES => [ OpenInteract::Template::Provider->new ] )
                    || die Template->error();
    return $template;
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Template::Process - Process OpenInteract templates

=head1 SYNOPSIS

 # Specify an object by name and package

 my $html = $R->template->handler( {}, { key => 'value' },
                                   { db      => 'this_template',
                                     package => 'my_pkg' } );

 # Specify an object by fully-qualified name

 my $html = $R->template->handler( {}, { key => 'value' },
                                   { name => 'my_pkg::this_template' } );

 # Directly pass text to be parsed

 my $little_template = 'Text to replace -- here is my login name: ' .
                       '[% login.login_name %]';
 my $html = $R->template->handler( {}, { key => 'value' },
                                   { text => $little_template } );

 # Pass the already-created object for parsing (rare)

 my $site_template_obj = $R->site_template->fetch( 51 );
 my $html = $R->template->handler( {}, { key => 'value' },
                                   { object => $site_template_obj } );

 # Specify a file (rare)

 my $html = $R->template->handler( {}, { key => 'value' },
                                   { file => 'filename.tmpl' } );

 my $template_results = $R->template->handler( {}, { foo => 'bar' },
                                               { name => 'mypackage::mytemplate' });

=head1 DESCRIPTION

This class processes templates within OpenInteract. The main method is
C<handler()> -- just feed it a template name and a whole bunch of keys
and it will take care of finding the template (from a database,
filesystem, or wherever) and generating the finished content for you.

=head1 METHODS

B<handler( \%tmpl_params, \%tmpl_variables, \%tmpl_source )>

Generate template content, given keys in C<\%tmpl_variables> and a
template identifier in C<\%tmpl_source>.

Parameters:

=over 4

=item *

B<tmpl_params> (\%)

Configuration options for the template. Note that you can set defaults
for these at configuration time as well.

=item *

B<tmpl_variables> (\%)

The key/value pairs that will get plugged into the template. These can
be arbitrarily complex, since the Template Toolkit can do anything :-)

=item *

B<tmpl_source>

Tell the method how to find the source for the template you want to
process. There are a number of ways to do this:

Method 1: Name and package (separately)

 db      => 'template_name',
 package => 'package_name'

Note that both the template name and package are B<required>. This is
a change from older versions when the template package was optional.

Method 2: Use a combined name

 name    => 'template_name::package_name'

Method 3: Specify the text yourself

 text    => $scalar_with_text
 or
 text    => \$scalar_ref_with_text


Method 4: Specify an object of type C<OpenInteract::SiteTemplate>

 object => $site_template_obj

=back

B<initialize( \%config )>

Creates a TT processing object with our necessary parameters and
returns it.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<Template>

L<OpenInteract::Template::Context>

L<OpenInteract::Template::Plugin>

L<OpenInteract::Template::Provider>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
