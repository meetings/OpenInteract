package OpenInteract::Template::Provider;

# $Id: Provider.pm,v 1.19 2002/01/02 02:43:53 lachoy Exp $

use strict;
use Data::Dumper       qw( Dumper );
use Digest::MD5        qw();
use File::Spec         qw();
use Template::Provider;

@OpenInteract::Template::Provider::ISA      = qw( Template::Provider );
$OpenInteract::Template::Provider::VERSION  = '1.2';
$OpenInteract::Template::Provider::Revision = sprintf("%d.%02d", q$Revision: 1.19 $ =~ /(\d+)\.(\d+)/);


use constant DEFAULT_MAX_CACHE_TIME       => 60 * 30;
use constant DEFAULT_TEMPLATE_EXTENSION   => 'template';
use constant DEFAULT_PACKAGE_TEMPLATE_DIR => 'template/';
use constant DEFAULT_TEMPLATE_TYPE        => 'filesystem';
use constant OI_TYPE_SPOPS_OBJECT         => 'object';
use constant OI_TYPE_COMMON_FILE          => 'common_file';
use constant OI_TYPE_PACKAGE_FILE         => 'package_file';
use constant DEBUG_LEVEL                  => 2;

# Copied from Template::Provider since they're not exported

use constant PREV   => 0;
use constant NAME   => 1;
use constant DATA   => 2;
use constant LOAD   => 3;
use constant NEXT   => 4;
use constant STAT   => 5;


# This should return a two-item list: the first is the template to be
# processed, the second is an error (if any). $name is a simple name
# of a template, which in our case is often of the form
# 'package::template_name'.

sub fetch {
	my ( $self, $text ) = @_;
    my $R = OpenInteract::Request->instance;

	my ( $name );

	# if scalar or glob reference, then get a unique name to cache by

	if ( ref( $text ) eq 'SCALAR' ) {
		$R->DEBUG && $R->scrib( DEBUG_LEVEL, "anonymous template passed in" );
		$name = $self->_get_anon_name( $text );
	}
    elsif ( ref( $text ) eq 'GLOB' ) {
		$R->DEBUG && $R->scrib( DEBUG_LEVEL, "GLOB passed in to fetch" );
        $name = $self->_get_anon_name( $text );
    }

    # Otherwise, it's a 'package::template' name or a unique filename
    # found in '$WEBSITE_DIR/template', both of which are handled in
    # _load() below. Also check that the template name doesn't have
    # any invalid characters (e.g., '../../../etc/passwd')

    else {
        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "info passed in is site filename or package::template;",
                                             "will check file system or database for ($text)" );
        $name = $text;
        undef $text;
        eval { $self->_validate_template_name( $name ) };
        if ( $@ ) { return ( $@, Template::Constants::STATUS_ERROR ) }
	}

    # If we have a directory to compile the templates to, create a
    # unique filename for this template

    # Generally we keep the compile name the same as the name passed
    # in, (replacing '::' with '-') although if necessary we might
    # prepend the server name so we can keep these unique among
    # different sites running in the same modperl process.

    my ( $compile_file );

	if ( $self->{COMPILE_DIR} ) {
		my $ext = $self->{COMPILE_EXT} || '.ttc';
        my $compile_name = $name;
        $compile_name =~ s/::/-/g;
		$compile_file = File::Spec->catfile( $self->{COMPILE_DIR}, $compile_name . $ext );
        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "compiled output filename: ($compile_file)" );
	}

    my ( $data, $error );

	# caching disabled (cache size is 0) so load and compile but don't cache

	if ( $self->{SIZE} == 0 ) {
		$R->DEBUG && $R->scrib( DEBUG_LEVEL, "fetch( $name ) [caching disabled]" );
		( $data, $error ) = $self->_load( $name, $text );
		( $data, $error ) = $self->_compile( $data, $compile_file ) unless ( $error );
		$data = $data->{data}                                       unless ( $error );
	}

	# cached entry exists, so refresh slot and extract data

    elsif ( $name and ( my $cache_slot = $self->{LOOKUP}{ $name } ) ) {
		$R->DEBUG && $R->scrib( DEBUG_LEVEL, "fetch( $name ) [cached (limit: $self->{SIZE})]" );
		( $data, $error ) = $self->_refresh( $cache_slot );
		$data = $cache_slot->[ DATA ] unless ( $error );
	}

	# nothing in cache so try to load, compile and cache

    else {
		$R->DEBUG && $R->scrib( DEBUG_LEVEL, "fetch( $name ) [uncached (limit: $self->{SIZE})]" );
		( $data, $error ) = $self->_load( $name, $text );
		( $data, $error ) = $self->_compile( $data, $compile_file ) unless ( $error );
		$data = $self->_store( $name, $data )                       unless ( $error );
	}

	return( $data, $error );
}


# NOTE: You should NEVER even check to see if $name exists anywhere
# else on the filesystem besides under the $WEBSITE_DIR.

# From Template::Provider -- here's what the hashref includes:
#
#   name    filename or $content, if provided, or 'input text', etc.
#   text    template text
#   time    modification time of file, or current time for handles/strings
#           (we also use this for the 'last_update' field of an SPOPS object)
#   load    time file/object was loaded (now!)
#
# And we add (for our files/SPOPS objects):
#
#   oi_type The type of template in OpenInteract (see the 'OI_TYPE' constants)

sub _load {
    my ( $self, $name, $content ) = @_;

    my $R = OpenInteract::Request->instance;
	$R->DEBUG && $R->scrib( DEBUG_LEVEL, "_load(@_[1 .. $#_])\n" );

    # If no name, $self->{TOLERANT} being true means we can decline
    # safely. Otherwise return an error. We might modify this in the
    # future to not even check TOLERANT -- if it's not defined we
    # don't want anything to do with it, and nobody else should either
    # (NYAH!). Note that $name should be defined even if we're doing a
    # scalar ref or glob template

    unless ( defined $name ) {
        if ( $self->{TOLERANT} ) {
            $R->DEBUG && $R->scrib( DEBUG_LEVEL, "No name passed in and TOLERANT set, so decline" );
            return ( undef, Template::Constants::STATUS_DECLINED );
        }
        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "No name passed in and TOLERANT not set, so return error" );
        return ( "No template", Template::Constants::STATUS_ERROR );
    }

    # is this an anonymous template? if so, return it

    # Note: it would be cool if we could figure out where 'name' is
    # passed to and have it deal with references properly, and then
    # propogate that reference through to processing, etc.

    if ( ref( $content ) eq 'SCALAR' ) {
        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Nothing to load since template is scalar ref." );
        return ({ 'name' => $name,
                  'text' => $$content,
                  'time' => time,
                  'load' => 0 }, undef );
    }

    if ( ref( $content ) eq 'GLOB' ) {
        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Template is glob (file) ref, so read in" );
        local $/ = undef;
        return ({ 'name' => 'file handle',
                  'text' => <$content>,
                  'time' => time,
                  'load' => 0 }, undef );
    }
    my ( $tmpl_package, $tmpl_name ) = $R->site_template->parse_name( $name );

    # If this isn't a 'package::name' name, see if it's a template in
    # the 'common' directory for this website; otherwise throw an
    # error

    unless ( $tmpl_package and $tmpl_name ) {
        my $website_dir = $R->CONFIG->get_dir( 'template' );
        my $tmpl_ext    = $self->_find_template_extension( $R->CONFIG );
        my $common_template_name     = "$website_dir/$name";
        my $common_template_name_ext = "$common_template_name.$tmpl_ext";
        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Test filenames: ($common_template_name)",
                                             "($common_template_name_ext)" );
        my ( $use_filename );
        $use_filename   = $common_template_name     if ( -f $common_template_name );
        $use_filename ||= $common_template_name_ext if ( -f $common_template_name_ext );
        if ( $use_filename ) {
            $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Template ($name) is a common template in the website." );
            my $data = eval { $self->_fetch_oi_file( $use_filename ) };
            if ( $@ ) { return ( $@, Template::Constants::STATUS_ERROR ) }
            $data->{oi_type} = OI_TYPE_COMMON_FILE;
            return ( $data, undef );
        }

        my $error_msg = "Template ($name) is not in the website common directory " .
                        "and is not in the format 'package::name'";
        $R->scrib( 0, $error_msg );
        return ( $error_msg, Template::Constants::STATUS_ERROR );
    }

    # Now retrieve the template from an OI package. Find out whether
    # we should check the database or filesystem first.

    # Choices are: 'database' or 'filesystem'.

    my $first_choice = $R->CONFIG->{template_info}{source} || DEFAULT_TEMPLATE_TYPE;

    $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Trying to find template ($tmpl_name)",
                                         "in package ($tmpl_package) using $first_choice" );

    my ( $data, $msg );
    if ( $first_choice eq 'filesystem' ) {
        ( $data, $msg ) = $self->_fetch_template_from_fs( $tmpl_package, $tmpl_name );
        unless ( $data or $msg ) {
            ( $data, $msg ) = $self->_fetch_template_from_spops( $tmpl_package, $tmpl_name );
        }
    }
    else {
        ( $data, $msg ) = $self->_fetch_template_from_spops( $tmpl_package, $tmpl_name );
        unless ( $data or $msg ) {
            ( $data, $msg ) = $self->_fetch_template_from_fs( $tmpl_package, $tmpl_name );
        }
    }

    return ( $data, $msg )  if ( $data or $msg );
    my $error_msg = "Cannot find template with requested name ($name)";
    $R->scrib( 0, "Cannot find template ($name) in either ",
                  "FS or SPOPS (First tried: $first_choice)" );
    return ( $error_msg, Template::Constants::STATUS_ERROR );
}


sub _fetch_template_from_fs {
    my ( $self, $pkg, $name ) = @_;
    my $R = OpenInteract::Request->instance;

    # is this template on disk in the package? if so load it up and
    # send it on

    my $filename = $self->_find_package_template_filename( $pkg, $name );
    return undef unless ( -f $filename );

    $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Template found in filesystem ($filename); trying to open" );
    my $data = eval { $self->_fetch_oi_file( $filename ) };
    if ( $@ ) {
        $R->scrib( 0, "Error when trying to open template from filesystem: $@" );
        return undef;
    }
    $data->{oi_type} = OI_TYPE_PACKAGE_FILE;
    return ( $data, undef );
}



sub _fetch_template_from_spops {
    my ( $self, $pkg, $name ) = @_;
    my $R = OpenInteract::Request->instance;

    # Otherwise this must be in the database -- get the SPOPS object
    # and extract relevant information. 

    my $spops_tmpl = eval { $self->_fetch_spops_template( $pkg, $name ) };
    if ( $@ ) {
        $R->scrib( 0, "Error found when retrieving template ($pkg $name)",
                      "$@\n", Dumper( SPOPS::Error->get ) );
    }
    return undef unless ( $spops_tmpl );
    $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Template found in SPOPS database" );
    my $text = $spops_tmpl->{template};
    if ( $spops_tmpl->{script} ) {
        $text .= "<script language='javascript'>\n$spops_tmpl->{script}\n</script>\n";
    }
    $text =~ s/\015\012/\n/g;
    return ( { 'name'    => "$pkg::$name",
               'text'    => $text,
               'time'    => $spops_tmpl->{last_update},
               'load'    => time,
               'oi_type' => OI_TYPE_SPOPS_OBJECT }, undef );
}


# Override so we can set/check the max cache time ourselves for
# database entries rather than relying on the filesystem's stat()

sub _refresh {
	my ( $self, $slot ) = @_;
	my ( $head, $file, $data, $error );

    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( DEBUG_LEVEL, "_refresh([ @$slot ])" );

    # If the cache time has expired, see if we need to reload the
    # entry -- each test just needs to set $do_reload to true and it
    # will be reloaded.

    my $do_reload = 0;
    my $max_cache_time = $R->CONFIG->{cache}{template}{expire}
                         || DEFAULT_MAX_CACHE_TIME;
	if ( ( $slot->[ DATA ]->{'time'} - time ) > $max_cache_time ) {
        my $template_type = $slot->[ DATA ]->{oi_type};
        if ( $template_type eq OI_TYPE_SPOPS_OBJECT ) {
            $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Refreshing cache file ", $slot->[ NAME ] );
            my $last_update_time = $self->_fetch_spops_update_time( $slot->[ NAME ] );
            $do_reload++ if ( $last_update_time != $slot->[ DATA ]->{time} );
        }

        # We COULD do checks for the different filetypes here, but why
        # bother? The overhead for getting them is minimal.

        else {
            $do_reload++;
        }

        if ( $do_reload ) {
            $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Refreshing cache for template: ", $slot->[ NAME ] );
            ( $data, $error ) = $self->_load( $slot->[ NAME ] );
            ( $data, $error ) = $self->_compile( $data )  unless ( $error );
        }

        unless ( $error ) {
            $slot->[ DATA ] = $data->{ data };
            $slot->[ LOAD ] = $data->{ time };
        }
	}

	# remove existing slot from usage chain...

	if ( $slot->[ PREV ] ) {
		$slot->[ PREV ][ NEXT ] = $slot->[ NEXT ];
	} 
    else {
		$self->{ HEAD } = $slot->[ NEXT ];
	}

	if ( $slot->[ NEXT ] ) {
		$slot->[ NEXT ][ PREV ] = $slot->[ PREV ];
	} 
    else {
		$self->{ TAIL } = $slot->[ PREV ];
	}

	# ... and add to start of list
	$head = $self->{ HEAD };
	$head->[ PREV ] = $slot if ( $head );
	$slot->[ PREV ] = undef;
	$slot->[ NEXT ] = $head;
	$self->{ HEAD } = $slot;

	return ( $data, $error );
}


# Ensure there aren't any funny characters

sub _validate_template_name {
    my ( $self, $name ) = @_;
    if ( $name =~ m|\.\.| ) {
        die "Template name must not have any directory tree symbols (e.g., '..')";
    }
    if ( $name =~ m|^/| ) {
        die "Template name must not begin with an absolute path symbol";
    }
    return 1;
}


# The name should be package::template

sub _fetch_spops_template {
  my ( $self, $tmpl_package, $tmpl_name ) = @_;

  my $R = OpenInteract::Request->instance;
  $R->DEBUG && $R->scrib( DEBUG_LEVEL, "TT trying to fetch SPOPS template from ($tmpl_package) ($tmpl_name)" );

  unless ( $tmpl_package and $tmpl_name ) {
      $R->error->set({ user_msg   => "Cannot retrieve template due to improper name",
                       system_msg => "Bad name: (Package: $tmpl_package) (Name: $tmpl_name)" });
      die $OpenInteract::Error::user_msg;
  }

  # Let exceptions bubble up for now -- and yes, the order is reversed
  # in the fetch_by_name() call

  my $tmpl_obj = $R->site_template->fetch_by_name( $tmpl_name, $tmpl_package );

  # Return if we don't find the object
  return undef  unless ( $tmpl_obj );

  $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Template retrieved: ", Dumper( $tmpl_obj ) );
  return $tmpl_obj;
}


sub _fetch_spops_update_time {
    my ( $self, $full_template_name ) = @_;
    my $R = OpenInteract::Request->instance;
    my ( $tmpl_package, $tmpl_name ) = $R->site_template->parse_name( $full_template_name );
    my %select_params = ( select => [ 'last_update' ],
                          from   => $R->site_template->table_name,
                          where  => 'package = ? AND name = ?',
                          value  => [ $tmpl_package, $tmpl_name ],
                          return => 'single-list' );
    my ( $update_time )  = eval { @{ $R->site_template->db_select( \%select_params ) || [] } };
    if ( $@ ) {
        my $ei = SPOPS::Error->get;
        $R->scrib( 0, "Error trying to fetch the last update time for ",
                      "($full_template_name)\n$ei->{system_msg}" );
    }
    return $update_time;
}


# Just open up a file and return a hashref with all the info TT wants

sub _fetch_oi_file {
    my ( $self, $filename ) = @_;
    open( FH, $filename ) || die "Cannot open template file ($filename): $!";
    local $/ = undef;
    my $fulltext = <FH>;
    close( FH );
    my $data = { 'name'    => $filename,
                 'text'    => $fulltext,
                 'time'    => (stat $filename)[9],
                 'load'    => time };
    return $data;
}


# Find a template in a package's filesystem. If file exists, return
# name. Otherwise return undef.

sub _find_package_template_filename {
    my ( $self, $package, $template_name ) = @_;

    my $R = OpenInteract::Request->instance;
    $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Trying to create filename for template ",
                               "($template_name) from package ($package)" );

    my $repository = $R->repository->fetch(
                                undef, { directory => $R->CONFIG->{dir}{base} } );
    my $info = $repository->fetch_package_by_name({ name => $package });
    if ( $info ) {
        my $template_ext = $self->_find_template_extension( $R->CONFIG );
        my @template_files = ( DEFAULT_PACKAGE_TEMPLATE_DIR . $template_name,
                               DEFAULT_PACKAGE_TEMPLATE_DIR . "$template_name.$template_ext" );
        my $full_filename = $R->package->find_file( $info, @template_files );
        if ( -f $full_filename ) {
            $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Found existing file! Filename: ($full_filename)" );
            return $full_filename;
        }
        $R->DEBUG && $R->scrib( DEBUG_LEVEL, "Template ($template_name) not found in ($package)" );
        return undef;
    }
    $R->scrib( 0, "Cannot find template from filesystem because package ",
                  "information for ($package) not found in repository!" );
    return undef;
}


sub _find_template_extension {
    my ( $self, $CONFIG ) = @_;
    return $CONFIG->{template_info}{template_ext} ||
           $CONFIG->{template_ext} ||
           DEFAULT_TEMPLATE_EXTENSION;
}


# store names for non-named templates by using a unique fingerprint of
# the template text as a hash key

my $ANON_NUM      = 0;
my %ANON_TEMPLATE = ();

sub _get_anon_name {
	my ( $self, $text ) = @_;
    my $key = Digest::MD5::md5_hex( ref( $text ) ? $$text : $text );
	return $ANON_TEMPLATE{ $key } if ( exists $ANON_TEMPLATE{ $key } );
	return $ANON_TEMPLATE{ $key } = 'anon_' . ++$ANON_NUM;
}


1;

__END__

=pod

=head1 NAME

OpenInteract::Template::Provider - Retrieve templates for the Template Toolkit

=head1 SYNOPSIS

 $Template::Config::CONTEXT = 'OpenInteract::Template::Context';
 my $template = Template->new(
                       COMPILE_DIR    => '/tmp/ttc',
                       COMPILE_EXT    => '.ttc',
                       LOAD_TEMPLATES => [ OpenInteract::Template::Provider->new ] );
 my ( $output );
 $template->process( 'package::template', \%params, \$output );

=head1 DESCRIPTION

B<NOTE>: As shown above, you need to use
L<OpenInteract::Template::Context> as a context for your templates
since our naming scheme ('package::name') collides with the TT naming
scheme for specifying a prefix before a template.

This package is a provider for the Template Toolkit while running
under OpenInteract. Being a provider means that TT hands off any
requests for templates to this class, which has OpenInteract-specific
naming conventions (e.g., 'package::template') and knows how to find
templates in the database, in the templates for a package or the
templates in a website.

=head1 METHODS

All of the following are object methods and have as the first argument
the object itself.

B<fetch( $text )>

Overrides C<Template::Provider>.

Uses C<$text> to somehow retrieve a template. The actual work to
retrieve a template is done in C<_load()>, although this method
ensures that the template name is 'safe' and creates a name we use to
save the compiled template.

Returns a two-element list: the first is a compiled template, the
second is an error message. (Of course, if there is no error the
second item will be undefined.)

B<_load( $name, $content )>

Loads the template content, returning a two-element list. The first
item in the list is the TT hashref, the second is an error message.

We try four ways to retrieve a template, in this order:

=over 4

=item 1.

B<scalar reference>: If the template is a scalar reference it does not
need to be retrieved, so we just put C<$content> in the TT hashref
structure as the data to process and return it.

=item 2.

B<glob reference>: If the template is a glob reference we treat it as
a filehandle and read all data from C<$content> in the TT hashref
structure as the data to process as return it.

=item 3.

B<generic website template>: A website can store 'generic' templates,
which means they are not part of any package. These are stored in the
'template' directory which can be set in the server configuration.

This option is checked only if C<$name> is not in the 'package::name'
format used to uniquely identify templates by OpenInteract.

=back

The next two checks split C<$name> into C<$package> and
C<$template_name> since C<$name> is in the format
'package::name'. (Otherwise it is assumed to be handled by B<2>.)

=over 4

=item 4.

B<filesystem package template>: Templates can be stored in the
filesystem under C<$package>. This checks to see if the template name
in the package using C<$template_name>. (See
C<_find_package_template_filename()> for how this is done.)

=item 5.

B<database package template>: Try to fetch the SPOPS object with
C<$package> and C<$template_name>

=back

Note that the order of B<4> and B<5> above are configurable from the
server configuration, using the C<{template_info}{source}> key.

B<_refresh( $cache_slot )>

Called when we use C<$cache_slot> for a template. This refreshes the
time of the slot and brings it to the head of the LRU cache.

You can tune the expiration time of the cache by setting the key:

 {cache}{template}{expire}

in your server configuration file to the amount of time (in seconds)
to keep an entry in the cache.

B<_validate_template_name( $full_template_name )>

Ensures that C<$full_template_name> does not have any tricky
filesystem characters (e.g., '..') in it.

B<_fetch_spops_template( $package, $template_name )>

Retrieve a template from the database using the SPOPS object
'site_template'. Returns C<undef> if an object with C<$package> and
C<$template_name> is not found, or the matching object if it is found.

B<_fetch_oi_file( $filename )>

Opens C<$filename>, reads in the contents and puts it into a hashref
used by TT -- with keys 'name', 'text', 'time' and 'load'. If
successful, that hashref is returned. If it fails (cannot open file,
whatever) the method throws a die.

B<_find_package_template_filename( $package, $template_name )>

Try to find C<$template_name> within the filesystem for C<$package>. For
example, c<$template_name> might be 'navigation_bar' so we look for:

  DEFAULT_PACKAGE_TEMPLATE_DIR/$template_name
  DEFAULT_PACKAGE_TEMPLATE_DIR/$template_name.TEMPLATE_EXTENSION

Where C<TEMPLATE_EXTENSION> can be defined in the server configuration
for your website (using the 'template_ext' key) or in the
DEFAULT_TEMPLATE_EXTENSION constant in this class.

B<_get_anon_name( $text )>

If we get an anonymous template to provide, we need to create a unique
name for it so we can compile and cache it properly. This method
returns a unique name based on C<$text>.

=head1 BUGS

None known.

=head1 TO DO

B<Testing>

Needs more testing in varied environments.

=head1 SEE ALSO

L<Template>

L<Template::Provider>

Slashcode (http://www.slashcode.com/)

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

Robert McArthur <mcarthur@dstc.edu.au>

Authors of Slashcode <http://www.slashcode.com/>

=cut
