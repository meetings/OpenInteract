package OpenInteract::Template::Toolkit;

# $Id: Toolkit.pm,v 1.2 2001/07/19 17:19:30 lachoy Exp $

use strict;
use Data::Dumper   qw( Dumper );
use Template       ();
use HTML::Entities ();
use SPOPS::Utility ();

@OpenInteract::Template::Toolkit::ISA     = qw( OpenInteract::Template );
$OpenInteract::Template::Toolkit::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);


# Map all the subroutines to a name -- the name is how you call it in
# the template. The actual utilities are below 'handler'

my %UTILS = (
    comp             => \&comp,
    limit_string     => \&limit_string,
    javascript_quote => sub { $_[0] =~ s/\'/\\\'/g; return $_[0] },
    regex_chunk      => \&regex_chunk,
    now              => \&now,
    box_add          => \&box_add,
    add_context      => \&add_context,
    limit_sentences  => \&limit_sentences,
    date_into_hash   => \&date_into_hash,
    sprintf          => \&simulate_sprintf,
    percent_format   => \&percent_format,
    money_format     => \&money_format,
    object_info      => \&object_info,
    dump_it          => \&dump_it,
    ucfirst          => \&uc_first,
    html_encode      => \&html_encode,
    html_decode      => \&html_decode,
    isa              => \&class_isa,
);


sub handler {
    my ( $class, $template_config, $template_vars, $template_source ) = @_;
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 3, "Parameters passed in:\n", "Config: ", Dumper( $template_config ), "\n", 
                               "Vars:   ", Dumper( $template_vars ), "\n", 
                               "Other:  ", Dumper( $template_source ) );
    $R->DEBUG && $R->scrib( 2, "Parameter names passed in:\n", 
                               "Config: ", join( ' // ', keys %{ $template_config } ), "\n", 
                               "Vars: ", join( ' // ', keys %{ $template_vars } ), "\n", 
                               "Other: ", join( ' // ', keys %{ $template_source } ) );
    my $text = $template_source->{text} || $class->read_template( $template_source );
    unless ( $text ) {
        $R->throw({ code       => 201, 
                    type       => 'template', 
                    user_msg   => 'No text for template to parse!',
                    system_msg => "No text or filename to parse!\nTemplate source: ". 
                                  Dumper( $template_source ) });
        return '[[error processing directive]]';
    }

    # Grab default information and other stuff, see
    # OpenInteract::Template for the actual routine that we inherit.

    $class->default_info( $template_vars );
    $class->assign_utilities( $template_vars );

    # Process this bugger -- note that the template object is stored in
    # the stash class for this website and should be created when a new
    # Apache child is created (see OpenInteract::ApacheStartup)

    my $to_process = ( ref $text ) ? $text : \$text;
    my $html = undef;
    my $template = $R->template_object;
    my $result = $template->process( $to_process, $template_vars, \$html );
    unless ( $result ) {
        return $R->throw({ code       => 202, 
                           type       => 'template', 
                           user_msg   => 'Cannot parse template!',
                           system_msg => $template->error(), 
                           extra      => { filename => $template_source } });
    }
    $R->DEBUG && $R->scrib( 1, "Template processing went ok. Returning html." );
    $R->DEBUG && $R->scrib( 3, "Resulting html:\n$html" );
    return $html;
}


# Grab a template object and store it for parsing later -- note that
# 'template_object' is the key we stash it under and is also used as
# an alias from $R -- $R->template_object() returns this.template
# object.

sub initialize {
    my ( $class, $p ) = @_;
    die "No config object passed to initialize()!" unless ( ref $p->{config} );
    my $template = Template->new();
    my $stash_class = $p->{config}->{stash_class};
    $stash_class->set_stash( 'template_object', $template );
} 



# Define our utilities here; these are passed to every
# template in the Toolkit and are therefore always around.
# More in the perldoc.

# Actually assign the utility subroutines to the template variables;
# note: we should probably only do this once per request.

sub assign_utilities {
    my ( $class, $template_vars ) = @_;
    while ( my ( $key, $code ) = each %UTILS ) {
        $template_vars->{ $key } = $code;
    }
    return $class->_assign_utilities( $template_vars );
}

# For subclasses to override

sub _assign_utilities { return $_[1] };


# Stub to call the component processor

sub comp {
    my ( $name, @params ) = @_;

    # Put the parameters in a consistent format: all unnamed
    # parameters go into the key '_unnamed_' in the hashref, which
    # is what is passed to the actual component. Note that Template Toolkit
    # always passes the hashref of named parameters as the LAST parameter

    my $p = pop @params;
    $p->{_unnamed_} = \@params; 

    # Put the name of the component into the parameters (note: you cannot
    # use 'name' as a parameter)
  
    $p->{name} = $name;
  
    # Pass the information to the component processor
  
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 1, "Calling template component ($name)" );
    return $R->component->handler( $p );
}


# Limit $str to $len characters

sub limit_string { 
    my ( $str, $len ) = @_;
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 2, "limiting $str to $len characters" );
    return $str if ( length $str <= $len ); 
    return substr( $str, 0, $len ) . '...';
}


# Match $match from $str, which should have parentheses in it
# somewhere so that the match will be passed out (works?)

sub regex_chunk {
    my ( $str, $match ) = @_;
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 2, "Grabbing the match ($match) from string (($str))" );
    my ( $item ) = $str =~ /$match/m;
    $R->DEBUG && $R->scrib( 2, "Matched (($item)) from string." );
    return $item;
}


# Return the current date/time in the format passed in or using the
# default for Number::Format

sub now { return SPOPS::Utility->now({ format => $_[0] }); }


# Add the box named $box with $params

sub box_add {
    my ( $box, $params ) = @_;
    $params ||= {};
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 1, "Trying to add $box with ", Dumper( $params ) );
    push @{ $R->{boxes} }, { name => $box, params => $params };
    return undef;
}


# return GET-formatted unless the first arg is 'post'

sub add_context { 
    my $gid = OpenInteract::Request->instance->{group_context}->{group_id};
    return "gctxt=$gid;"  unless ( lc $_[0] eq 'post' );
    return qq(<input type="hidden" name="gctxt" value="$gid">);
}


# Limit $text to $num_sentences sentences (works?)

sub limit_sentences {
    my ( $text, $num_sentences ) = @_;
    return undef if ( ! $text );
    $num_sentences ||= 3;
    my @sentences = Text::Sentence::split_sentences( $text );
    my $orig_num_sentences = scalar @sentences;
    $sentences[ $num_sentences - 1 ] .= ' ...'  if ( $orig_num_sentences > $num_sentences );
    return join ' ', @sentences[ 0 .. ( $num_sentences - 1 ) ];
}


# Put a yyyy-mm-dd date into a hash with year, month and day as keys.

sub date_into_hash {
    my ( $date, $opt ) = @_;  
    return {} unless ( $date or $opt eq 'today' );
    my ( $y, $m, $d );
    if ( $date ) {
        ( $y, $m, $d ) = split /\D/, $date;
    }
    else {
        ( $y, $m, $d ) = split /\D/, SPOPS::Utility->now({ format => '%Y-%m-%e' });
    }
    $m =~ s/^0//;
    $d =~ s/^0//;
    return { year => $y, month => $m, day => $d };
}


# Use sprintf with $pat as the pattern and the remainder of the args
# feeding it.

sub simulate_sprintf {
    my ( $pat, @nums ) = @_;
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 1, "Trying to sprintf with $pat and @nums" );
    return sprintf( "$pat", @nums );
}


# Format $num as a percent to $places decimal places

sub percent_format {
    my ( $num, $places ) = @_;
    $places ||= 2;
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 1, "Trying to format $num as a percent" );
    my $pat = "%5.${places}f%%";
    return sprintf( $pat, $num * 100 );
}


# Format $num as US currency

sub money_format {
    my ( $num ) = @_;
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 1, "Trying to format $num as money" );
    return sprintf( '$%5.2f', $num );
}


# Return a hashref of information about $obj

sub object_info {
    my ( $obj ) = @_;
    return {} unless ( ref $obj );
    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( 2, "Object info: ", ref $obj, " (", $obj->id, ")" );
    return { class => ref $obj, oid => $obj->id, %{ $obj->object_description } };
}


# Return the args passed to Data::Dumper between <pre> tags

sub dump_it { return '<pre>' . Dumper( @_ ) . '</pre>' }


# Return the arg sent to ucfirst

sub uc_first { return ucfirst $_[0] }


# Return an HTML-encoded first argument

sub html_encode { 
    my ( $text ) = @_;
    $text =~ s/ /+/g;
    return HTML::Entities::encode( $text ) 
}


# Return an HTML-decoded first argument

sub html_decode { 
    return HTML::Entities::decode( $_[0] );
}


# Wrap the call in an eval{} just in case people pass us bad data.

sub class_isa {
    my ( $item, $class ) = @_;
    return eval { $item->isa( $class ) };
}
 
1;

__END__

=pod

=head1 NAME

OpenInteract::Template::Toolkit - Provide a wrapper for the Template Toolkit

=head1 SYNOPSIS

 my $template_class = $R->template;

 # Specify an object by name and package

 my $html = $template_class->handler( {}, { key => 'value' },
                                  { db => 'this_template',
                                    package => 'my_pkg' } );

 # Directly pass text to be parsed

 my $little_template = 'Text to replace -- here is my login name: ' .
                   '[% login.login_name %]';
 my $html = $template_class->handler( {}, { key => 'value' },
                                  { text => $little_template } );

 # Pass the already-created object for parsing (rare)
 
 my $site_template_obj = $R->site_template->fetch( 51 );
 my $html = $template_class->handler( {}, { key => 'value' },
                                  { object => $site_template_obj } );

 # Specify a file (rare)

 my $html = $template_class->handler( {}, { key => 'value' },
                                  { file => 'filename.tmpl' } );

=head1 DESCRIPTION

Just feed this class the following information. The first
two parameters are always the same:

B<template_config> (\%)

Configuration options for the template. Note that you can set
defaults for these at configuration time as well.

B<template_vars> (\%)

The key/value pairs that will get plugged into the template

The last parameters depend on where you are getting the 
text to fill in. You can pass:

 db  => 'template_name', package => 'package_name'

 text => $scalar_with_text (or \$scalar_ref_with_text)

 object => $site_template_obj
 
 file => 'filename'

(The difference between 'db' and 'file' is that with 'db' we first
look to see if we can locate a L<OpenInteract::SiteTemplate> object by
that name. If not, then we try a file with the same name and the
template extension bolted on the end. The template extension is set in
your server config using the key 'template_ext'.)

In either case, you will get a return value of the text with the
template keys filled in. Since we are using the Template Toolkit here,
the keys may be fairly complex.  Some people consider this a good
thing :)

=head1 METHODS

B<handler( \%, \%template_vars, \%text_method )>

Parses the text and returns the text with the values in the second
hashref plugged in.

B<initialize( \%params )>

Creates a template processing object and stores it in the stash class
for a website. This helps out with efficiency and also allows us (in
the future) to create a template provider for the Toolkit that deals
with caching, among other things.

B<assign_utilities( \%template_vars )>

Assign some simple utilities to the template environment. These are
generally simple text-munging actions, but you can add other behaviors
by subclassing this and defining a single class method
(_assign_utilities) that takes as its first argument the template_vars
hashref; assign your coderefs to it and they will be there!

Example:

 # $class is $_[0]; \%vars is $_[1]

 sub _assign_utilities { 
   $_[1]->{ickify} = sub { $_[0] =~ s/this/ick/g; return $_[0] }; 
 }

Creates a routine 'ick' that you can call within any template called
by your class; the call looks like this (see docs for Template
Toolkit):

 We had some [% ickify( 'this and that' ) %] as well as Oswald.

Which returns:

 We had some ick and that as well as Oswald.

Fun!

=head1 TO DO

B<Make 'Default Info' cacheable>

This overlaps with L<OpenInteract::Template>, but we would like to
minimize processing with each template. Currently we do some
assignment in L<OpenInteract::Template> so we do not pass the entire
request object ($R) to the template. (This would be bad, IMO.) We
should try to do this once for each request and then keep the results
around for the remainder of the templates processed in the request.

B<Investigate Built-ins to TT 2.0>

Many of the functions made available to templates from this module are
now built-in to Template Toolkit version 2+. We should eliminate the
duplicates and document (here and in the other templates docs) the
ones people are most likely to use.

B<Document the methods available to templates>

Explains itself. Note that part of this is done -- see the
documentation that ships with OpenInteract that is available when you
fire up your website at '/SystemDoc/'. It is also available in the
'doc/' subdirectory of the base installation directory for
OpenInteract and it should also be at the OpenInteract website:
http://www.openinteract.org/

B<Make an API for methods available to packages>

A package should be able to install behaviors to the templates,
similar to how metadata layers install behavior to individual SPOPS
data objects.

=head1 BUGS

=head1 SEE ALSO

L<OpenInteract::Template>

Template Toolkit: http://www.template-toolkit.org/

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
