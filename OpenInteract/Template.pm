package OpenInteract::Template;

# $Id: Template.pm,v 1.2 2001/07/19 17:40:53 lachoy Exp $

use strict;
use Data::Dumper  qw( Dumper );
use SPOPS::Secure qw( :level :scope );

@OpenInteract::Template::ISA     = ();
$OpenInteract::Template::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

my $SECURITY_CONSTANTS  = {
  level => {
     none => SEC_LEVEL_NONE, read => SEC_LEVEL_READ, write => SEC_LEVEL_WRITE
  },
  scope => {
     user => SEC_SCOPE_USER, group => SEC_SCOPE_GROUP, world => SEC_SCOPE_WORLD
  },
};


# Setup default information included with every template on every request

sub default_info {
    my ( $class, $info ) = @_;
    my $R = OpenInteract::Request->instance;
    $info->{security_level} = $SECURITY_CONSTANTS->{level};
    $info->{security_scope} = $SECURITY_CONSTANTS->{scope};
    $info->{login}          = $R->{auth}->{user};
    $info->{logged_in}      = $R->{auth}->{logged_in};
    $info->{login_group}    = $R->{auth}->{group};
    $info->{return_url}   ||= $R->{page}->{return_url} ||  $R->{path}->{original};
    $info->{group_context}  = $R->{group_context};
    $info->{group_context_default} = $R->CONFIG->{default_objects}->{group};
    if ( $R->{theme} ) {
        $R->{theme_values}  ||= $R->{theme}->all_values;
        $info->{th}           = $R->{theme_values};
        $R->DEBUG && $R->scrib( 2, "Theme values = ", Dumper( $info->{th} ) );
    }
    $info->{error_hold}   = $R->{error_hold};
    $info->{session}      = \%{ $R->{session} };
    $R->DEBUG && $R->scrib( 2, "Contents of default info:", Dumper( $info ) );
    return $class->_default_info( $info );
}


# Interface for subclasses to override

sub _default_info { return $_[1]; }


# Read in the template from either a file, database reference or an
# object

sub read_template {
    my ( $class, $p ) = @_;
    my $R = OpenInteract::Request->instance;
    my ( $text );
    my $tag = $p->{file} || $p->{db};
    my $cache_tag = lc join( '--', $tag, $p->{package} );

    # See if object was passed in
  
    if ( $p->{object} ) {
        $tag = $p->{object}->{name};
        $text = $p->{object}->{template};

        # Track the template object for later

        push @{ $R->{templates_used} }, $p->{object};
    }

    # See if database reference was passed in

    elsif ( $p->{db} ) {
        $R->DEBUG && $R->scrib( 1, "Trying to read template with DB tag: <<$p->{db}>> and package <<$p->{package}>>" );
        my $template = eval { $R->site_template->fetch_by_name( 
                                       $p->{db}, $p->{package} ) };
        if ( $@ or ! $template ) {
            $R->scrib( 0, "Failed to fetch site template ($p->{db}/$p->{package}) from database! ",
                          "Trying to use filesystem instead..." );

            # give the file a try before we bail...

            $p->{file} = $p->{db}; 
        }
        else { 
            $R->DEBUG && $R->scrib( 1, "Fetched template object ok" );
            $R->DEBUG && $R->scrib( 3, "Detail:", Dumper( $template ) ); 

            # Track the template object for later

            push @{ $R->{templates_used} }, $template;
            $text = $template->{template};
            if ( $template->{script} ) {
                $text .= qq(\n\n<script language="JavaScript">\n<!--\n\n) .
                         $template->{script} .
                         qq(\n\n// -->\n</script>\n\n);
            }
            $tag = $p->{db};
        }
  }

    # If nothing else has been read in, try the filesystem
  
    if ( ! $text and $p->{file} ) {
        my $filename = $class->process_filename({ file    => $p->{file}, 
                                                  package => $p->{package} });
        $R->DEBUG && $R->scrib( 1, "Filename retrieved from processing: ($filename)" );
        unless ( $filename ) {
            return $R->throw({ code       => 201, 
                               type       => 'template',
                               system_msg => "No proper filename to open for template",
                               extra      => { filename => $p->{file} } });
        }
        eval { open( TEXT, $filename ) || die $!; };
        if ( $@ ) {
            return $R->throw({ code       => 201, 
                               type       => 'template',
                               system_msg => "Failed to open filename. Error: $@",
                               extra      => { filename => $filename } });
        }
        $R->DEBUG && $R->scrib( 1, "File opened ok. Reading." );
        local $/ = undef;
        $text = <TEXT>;
        $tag  = $p->{file};
        close( TEXT );
    }
    return $text;
}

sub process_filename {
    my ( $class, $p ) = @_;
  
    # If the file already exists, great!
  
    return $p->{file}       if ( -f $p->{file} );
  
    my $R = OpenInteract::Request->instance;
    my $template_ext = $R->CONFIG->{template_ext};
  
    # If a package was passed in, check to see if the template is in the
    # package 'template' (templates?) directory
  
    if ( $p->{package} ) {
        $R->DEBUG && $R->scrib( 1, "Trying to create filename from package ($p->{package})" );
        my $repository = $R->repository->fetch( 
                                undef, { directory => $R->CONFIG->{dir}->{base} } );
        my $info = $repository->fetch_package_by_name({ name => $p->{package} });
        
        if ( $info ) {
            my $file = $R->package->find_file( $info, 
                                               "template/$p->{file}", 
                                               "template/$p->{file}.$template_ext" );
            if ( -f $file ) {
                $R->DEBUG && $R->scrib( 1, "Found existing file! Filename: ($file)" );
                return $file;
            }
        }
        else {
            $R->scrib( 0, "Cannot find template from filesystem because package ",
                          "information for ($p->{package}) not found in repository!" );
        }
    }

    # Otherwise, see if the file is in the application's 'template'
    # directory (a slim possibility, since everything is in packages
    # now...

    my $file = join( '/', $R->CONFIG->get_dir( 'template' ), $p->{file} );
    return $file                   if ( -f $file );
    return "$file.$template_ext"   if ( -f "$file.$template_ext" );
  
    # Nothing found, oh well

    return undef;
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Template - Common functions for all template wrappers

=head1 SYNOPSIS

 package OpenInteract::Template::MyTemplate;

 use OpenInteract::Template;

 @OpenInteract::Template::MyTemplate::ISA = qw( OpenInteract::Template );

=head1 DESCRIPTION

This module implements a number of utility methods all template
modules can use and provides an interface for template modules to
provide default information for all templates parsed by the system.

=head1 METHODS

B<read_template( \%params )>

Reads in a template from either an object, a name referring to an
object, or a static file. If the template is an object (either passed
in or fetched by the name), save the reference to the template in the
C<{templates_used}> arrayref found in $R.

Returns: scalar with content of template.

B<process_filename( \%params )>

Take the filename, which can be partial, and do some modifications to
see if it corresponds to a template file. These modifications are:
-add the template directory, add the template extension.

Example:

 my $tag = 'main';
 my $filename = OpenInteract::Template->process_file( { file => $tag } );
 print "File: ", $filename:
 >> File: /home/httpd/myproject/templates/main.tmpl;

B<default_info( \%tmpl_vars )>

Sets a number of common items for all templates to use. Most of them
can also be found in $R, but since the template does not (and should
not) have access to $R, we make aliases or copies of the information.

Note that you can assign other values by creating a subclass with the
routine '_default_info' which takes one argument, a hashref of
template variables.

=head2 Default Template Variables

The following variables are set in every template. Note that your
template implementation might set more -- see its documentation.

B<th>

A hashref with all the properties of The current theme. You will use
this a lot.

Example:

 <tr bgcolor="[% th.head_bgcolor %]">

B<login>

The object representing the user who is currently logged in.

Example:

 <p>Hi [% login.full_name %]! Anything new?</p>

B<login_group>

An arrayref of groups the currently logged-in user belongs to.

Example:

 <p>You are a member of groups:
 [% FOREACH group = login_group %]
   [% th.bullet %] [% group.name %]<br>
 [% END %]
 </p>

B<logged_in>

True/false determining whether the user is logged in or not.

Example:

 [% IF logged_in %]
   <p>You are very special, logged-in user!</p>
 [% END %]

B<session>

Contains all information currently held in the session. Note that
other handlers may during the request process have modified the
session. Therefore, what is in this variable is not guaranteed to be
already saved in the database. However, as the request progresses
OpenInteract will sync up any changes to the session database.

In addition, this information is B<read-only>. You will not get an
error if you try to set or change a value from the template, but the
information will persist only for that template.

Example:

 <p>Number of items in your shopping cart: 
    [% session.num_shopping_cart_items %]</p>

B<return_url>

What the 'return url' is currently set to. The return url is what we
come back to if we have to do something like logout.

B<error_hold>

A hashref representing a container with all error messages as
generated by error handlers. The error handler and the template need
to coordinate on a naming scheme so you know where to find your
messages.

Note that future work may restrict this to the errors for your
template only.

Example:

 <p>User [% error_hold.loginbox.login_name %] does not exist in the
    system.</p>

B<security_level>

A hashref with keys of 'none', 'read', and 'write' which gives you the
value used by the system to represent the security levels.

Example:

 [% IF obj.tmp_security_level < security_level.write %]
  ... do stuff ...
 [% END %]

B<security_scope>

A hashref with the keys of 'user', 'group' and 'world' which gives you
the value used by the system to represent the security scopes. This
will rarely be used but exists for completeness with
C<security_level>.

=head1 TO DO

B<Cache default info>

See 'TO DO' in L<OpenInteract::Template::Toolkit>.

B<Include only relevant error info to template>

Modify the default_info to see what template we are currently parsing
and include only relevant error information to the template from the
error_hold variable. That is, instead of qualifying it with the
template name, allow just the error name to be used:

 Old way: [% error_hold.loginbox.login_name %]

 New way: [% error_hold.login_name %]

=head1 BUGS

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
