package OpenInteract2::Config::Ini;

# $Id: Ini.pm,v 1.9 2003/06/24 03:35:38 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Config::Ini::VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

########################################
# CLASS METHODS

# Stuff in metadata (_m):
#   sections (\@): all full sections, in the order they were read
#   comments (\%): key is full section name, value is comment scalar
#   filename ($):  file read from

sub new {
    my ( $pkg, $params ) = @_;
    my $class = ref $pkg || $pkg;
    my $self = bless( {}, $class );
    if ( $self->{_m}{filename} = $params->{filename} ) {
        $self->translate_ini( OpenInteract2::Config->read_file( $params->{filename} ) );
    }
    elsif ( $params->{content} ) {
        $self->translate_ini( $params->{content} );
    }
    return $self;
}


sub get {
    my ( $self, $section, @p ) = @_;
    my ( $sub_section, $param ) = ( $p[1] ) ? ( $p[0], $p[1] ) : ( undef, $p[0] );
    my $item = ( $sub_section )
                 ? $self->{ $section }{ $sub_section }{ $param }
                 : $self->{ $section }{ $param };
    return $item unless ( ref $item eq 'ARRAY' );
    return wantarray ? @{ $item } : $item->[0];
}


sub set {
    my ( $self, $section, @p ) = @_;
    my ( $sub_section, $param, $value ) = ( $p[2] )
                                            ? ( $p[0], $p[1], $p[2] )
                                            : ( undef, $p[0], $p[1] );
    unless ( $self->is_section( $section, $sub_section ) ) {
        $self->add_section( $section, $sub_section );
    }
    return $self->read_item( $section, $sub_section, $param, $value );
}


sub delete {
    my ( $self, $section, @p ) = @_;
    my ( $sub_section, $param ) = ( $p[1] )
                                    ? ( $p[0], $p[1] ) : ( undef, $p[0] );
    delete $self->{ $section }{ $sub_section }{ $param } if ( $sub_section );
    delete $self->{ $section }{ $param };
}


sub is_section {
    my ( $self, $section, $sub_section ) = @_;
    my $full_section = ( $sub_section )
                         ? "$section $sub_section" : $section;
    return $self->{_m}{order_map}{ $full_section };
}

sub add_section {
    my ( $self, $section, $sub_section ) = @_;
    my $full_section = ( $sub_section )
                         ? "$section $sub_section" : $section;
    push @{ $self->{_m}{order} }, $full_section;
    $self->{_m}{order_map}{ $full_section }++;
}

sub sections {
    my ( $self ) = @_;
    return @{ $self->{_m}{order} };
}

sub main_sections {
    my ( $self ) = @_;
    my @main = ();
    foreach my $full_section ( @{ $self->{_m}{order} } ) {
        push @main, $full_section unless ( $full_section =~ /\s/ );
    }
    return @main;
}

sub add_comments {
    my ( $self, @items ) = @_;
    my ( $section, $sub_section, $comments );
    if ( scalar @items == 3 ) {
        ( $section, $sub_section, $comments ) = @items;
    }
    else {
        ( $section, $comments ) = @items;
    }
    my $full_section = ( $sub_section )
                         ? "$section $sub_section" : $section;
    $self->{_m}{comments}{ $full_section } = $comments;
}

sub get_comments {
    my ( $self, $section, $sub_section ) = @_;
    my $full_section = ( $sub_section )
                         ? "$section $sub_section" : $section;
    return $self->{_m}{comments}{ $full_section };
}

########################################
# INPUT
########################################

sub translate_ini {
    my ( $self, $content ) = @_;
    my $log = get_logger( LOG_CONFIG );

    # Content can be either an arrayref of lines from a file or a
    # scalar with the content.

    my $lines = ( ref $content eq 'ARRAY' )
                  ? $content : [ split( "\n", $content ) ];

    # Temporary holding for comments

    my @comments = ();
    my ( $section, $sub_section );

    # Cycle through the lines: skip blanks; accumulate comments for
    # each section; register section/subsection; add parameter/value

    for ( @{ $lines } ) {
        chomp;
        next if ( /^\s*$/ );
        if ( /^# Written by OpenInteract2::Config::Ini at/ ) {
            next;                 # ... get rid of current line
        }
        s/\s+$//;
        if ( /^\s*\#/ ) {
            push @comments, $_;
            next;
        }
        if ( /^\s*\[\s*(\S|\S.*\S)\s*\]\s*$/) {
            $log->is_debug &&
                $log->debug( "Found section [$1]" );
            ( $section, $sub_section ) =
                              $self->read_section_head( $1, \@comments );
            @comments = ();
            next;
        }
        my ( $param, $value ) = /^\s*([^=]+?)\s*=\s*(.*)\s*$/;
        $log->is_debug &&
            $log->debug( "Set [$section $sub_section $param] ",
                         "to [$value]" );
        $self->read_item( $section, $sub_section, $param, $value );
    }
    return $self;

}


sub read_section_head {
    my ( $self, $full_section, $comments ) = @_;
    my $comment_text = join "\n", @{ $comments };
    if ( $full_section =~ /^([\w\-]+)\s+([\w\-]+)$/ ) {
        my ( $section, $sub_section ) = ( $1, $2 );
        $self->{ $section }{ $sub_section } ||= {};
        $self->add_section( $section, $sub_section );
        $self->add_comments( $section, $sub_section, $comment_text );
        return ( $section, $sub_section );
    }
    $self->add_section( $full_section );
    $self->add_comments( $full_section, $comment_text );
    $self->{ $full_section } ||= {};
    return ( $full_section, undef );
}


sub read_item {
    my ( $self, $section, $sub_section, $param, $value ) = @_;

    # Special case -- 'Global' stuff goes in the config object root

    if ( $section eq 'Global' ) {
        push @{ $self->{_m}{global} }, $param;
        $self->set_value( $self, $param, $value );
        return;
    }

    $self->{ $section } ||= {};
    if ( $sub_section ) {
        $self->{ $section }{ $sub_section } ||= {};
    }

    return ( $sub_section )
             ? $self->set_value( $self->{ $section }{ $sub_section }, $param, $value )
             : $self->set_value( $self->{ $section }, $param, $value );
}


sub set_value {
    my ( $self, $set_in, $param, $value ) = @_;
    my $existing = $set_in->{ $param };
    if ( $existing and ref $set_in->{ $param } eq 'ARRAY' ) {
        push @{ $set_in->{ $param } }, $value;
    }
    elsif ( $existing ) {
        $set_in->{ $param } = [ $existing, $value ];
    }
    else {
        $set_in->{ $param } = $value;
    }
}

########################################
# OUTPUT
########################################

sub write_file {
    my ( $self, $filename ) = @_;
    my $log = get_logger( LOG_CONFIG );

    $filename ||= $self->{_m}{filename} || 'config.ini';
    my ( $original_filename );
    if ( -f $filename ) {
        $original_filename = $filename;
        $filename = "$filename.new";
    }

    # Set 'Global' items from the config object root

    foreach my $key ( @{ $self->{_m}{global} } ) {
        $self->{Global}{ $key } = $self->{ $key };
    }

    $log->is_debug &&
        $log->debug( "Writing INI to [$filename] (original: ",
                     "$original_filename)" );
    open( OUT, '>', $filename )
          || die "Cannot write configuration to [$filename]: $!";
    print OUT "# Written by ", ref $self, " at ", scalar localtime, "\n";
    foreach my $full_section ( $self->sections ) {
        my ( $section, $sub_section ) = split /\s+/, $full_section;
        my $comments = $self->get_comments( $section, $sub_section );
        if ( $comments ) {
            print OUT "$comments\n";
        }
        print OUT "[$full_section]\n",
                  $self->output_section( $section, $sub_section ),
                  "\n\n";
    }
    close( OUT );
    if ( $original_filename ) {
        unlink( $original_filename );
        rename( $filename, $original_filename );
        $filename = $original_filename;
    }
    return $filename;
}


sub output_section {
    my ( $self, $section, $sub_section ) = @_;
    my $show_from = ( $sub_section )
                      ? $self->{ $section }{ $sub_section }
                      : $self->{ $section };
    my @items = ();
    foreach my $key ( keys %{ $show_from } ) {
        if ( ref $show_from->{ $key } eq 'ARRAY' ) {
            foreach my $value ( @{ $show_from->{ $key } } ) {
                push @items, $self->show_item( $key, $value );
            }
        }
        elsif ( ref $show_from->{ $key } eq 'HASH' ) {
            # no-op -- this should get picked up later
        }
        else {
            push @items, $self->show_item( $key, $show_from->{ $key } );
        }
    }
    return join "\n", @items;
}


sub show_item { return join( ' = ', $_[1], $_[2] ) }

1;

__END__

=head1 NAME

OpenInteract2::Config::Ini - Read/write INI-style (++) configuration files

=head1 SYNOPSIS

 my $config = OpenInteract2::Config::Ini->new({ filename => 'myconf.ini' });
 print "Main database driver is:", $config->{db_info}{main}{driver}, "\n";
 $config->{db_info}{main}{username} = 'mariolemieux';
 $config->write_file;

=head1 DESCRIPTION

This is a very simple implementation of a configuration file
reader/writer that preserves comments and section order, enables
multivalue fields and one or two-level sections.

Yes, there are other configuration file modules out there to
manipulate INI-style files. But this one takes several features from
them while providing a very simple and uncluttered interface.

=over 4

=item *

From L<Config::IniFiles|Config::IniFiles> we take comment preservation
and the idea that we can have multi-level sections like:

 [Section subsection]

=item *

From L<Config::Ini|Config::Ini> and L<AppConfig|AppConfig> we borrow
the usage of multivalue keys:

 item = first
 item = second

=back

=head2 Example

Given the following configuration in INI-style:

 [datasource]
 default_connection_db = main
 db                    = main
 db                    = other

 [db_info main]
 db_owner      =
 username      = captain
 password      = whitman
 dsn           = dbname=usa
 db_name       =
 driver_name   = Pg
 sql_install   =
 long_read_len = 65536
 long_trunc_ok = 0

 [db_info other]
 db_owner      =
 username      = tyger
 password      = blake
 dsn           = dbname=britain
 db_name       =
 driver_name   = Pg
 sql_install   =
 long_read_len = 65536
 long_trunc_ok = 0

You would get the following Perl data structure:

 $config = {
   datasource => {
      default_connection_db => 'main',
      db                    => [ 'main', 'other' ],
   },
   db_info => {
      main => {
           db_owner      => undef,
           username      => 'captain',
           password      => 'whitman',
           dsn           => 'dbname=usa',
           db_name       => undef,
           driver_name   => 'Pg',
           sql_install   => undef,
           long_read_len => '65536',
           long_trunc_ok => '0',
      },
      other => {
           db_owner      => undef,
           username      => 'tyger',
           password      => 'blake',
           dsn           => 'dbname=britain',
           db_name       => undef,
           driver_name   => 'Pg',
           sql_install   => undef,
           long_read_len => '65536',
           long_trunc_ok => '0',
      },
   },
 };

=head2 'Global' Key

Anything under the 'Global' key in the configuration will be available
under the configuration object root. For instance:

 [Global]
 DEBUG = 1

will be available as:

 $CONFIG->{DEBUG}

=head1 METHODS

=head2 Class Methods

B<new( \%params )>

Create a new configuration object. If you pass in 'filename' as a
parameter we will try to read it in using C<read_file()>. If you pass
in 'content' as a parameter we try to translate it using
C<translate_ini()>

Returns: a new C<OpenInteract2::Config::Ini> object

=head2 Object Methods

B<sections()>

Returns a list of available sections.

B<get( $section, [ $sub_section ], $parameter )>

Returns the value from C<$section> (and C<$sub_section>, if given) for
C<$parameter>.

Returns: value set in config. If called in array context and there are
multiple values for C<$parameter>, returns an array. Otherwise returns
a simple scalar if there is one value, or an arrayref if multiple
values.

B<set( $section, [ $sub_section ], $parameter, $value )>

Set the key/value C<$parameter>/C<$value> pair in the configuration.

Returns: the value set

B<delete( $section, [ $sub_section ])>

Remove the C<$section> (and C<$sub_section>, if given) entirely.

Returns: the value deleted

=head2 Input Methods

B<read_file( $filename )>

Reads content from C<$filename>, translates it and puts it into the object.

Returns: the object filled with the content.

B<translate_ini( \@lines|$content )>

Translate the arrayref C<\@lines> or the scalar C<content> from INI
format into a Perl data structure.

Returns: the object filled with the content.

B<read_section_head( $full_section, \@comments )>

Splits the section into a section and sub-section, returning a
two-item list. Also puts the full section in the object internal order
and puts the comments so they can be linked to the section.

Returns: a two-item list with the section and sub-section as
elements. If the section is only one-level deep, it is the first and
only member.

B<read_item( $section, $subsection, $parameter, $value )>

Reads the value from [C<$section> C<$subsection>] into the object. If
the C<$section> is 'Global' we set the C<$parameter> and C<$value>
at the root level.

Returns: the value set

B<set_value( \%values, $parameter, $value )>

Sets C<$parameter> to C<$value> in C<\%values>. We do not care where
C<\%values> is in the tree.

If a value already exists for C<$parameter>, we make the value of
C<$parameter> an arrayref and push C<$value> onto it.

=head2 Output Methods

B<write_file( $filename )>

Serializes the INI file (with comments, as applicable) to
C<$filename>.

Items from the config object root go into 'Global'.

Returns: the filename to which the INI structure was serialized.

B<output_section( $section, $sub_section )>

Serializes the section C<$section> and C<$sub_section>.

Returns: a scalar suitable for output.

B<show_item( $parameter, $value )>

Serialize the key/value pair.

Returns: "$parameter = $value"

=head2 Debugging Note

Because this and other debugging classs can produce so much
information, it uses a separate debug switch than the rest of OI. If
you want to see debugging from this class, call:

 OpenInteract2::Config->SET_DEBUG(1);

=head1 SEE ALSO

L<AppConfig|AppConfig>

L<Config::Ini|Config::Ini>

L<Config::IniFiles|Config::IniFiles>

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
