package OpenInteract2::I18N::Initializer;

# $Id: Initializer.pm,v 1.7 2004/02/26 02:25:17 lachoy Exp $

use strict;
use File::Spec::Functions;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Template;

my ( $TEMPLATE, $BASE_CLASS );

$OpenInteract2::I18N::Initializer::VERSION   = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub new {
    my ( $class ) = @_;
    return bless( { _files => [] }, $class );
}

sub add_message_files {
    my ( $self, @files ) = @_;
    return unless ( scalar @files );
    $log ||= get_logger( LOG_INIT );
    $log->info( "Adding message files: ", join( ', ', @files ) );
    push @{ $self->{_files} }, @files;
    return $self->{_files};
}

sub locate_global_message_files {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );
    my $msg_dir = CTX->lookup_directory( 'msg' );
    opendir( MSGDIR, $msg_dir )
        || oi_error "Cannot read from global message directory '$msg_dir': $!";
    my @msg_files = grep /\.msg$/, readdir( MSGDIR );
    closedir( MSGDIR );
    my @full_msg_files = map { catfile( $msg_dir, $_ ) } @msg_files ;
    $log->info( "Found global message files: ", join( ', ', @full_msg_files ) );
    $self->add_message_files( @full_msg_files );
    return \@full_msg_files;
}

sub run {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_INIT );

    my %lang_msg = ();
    my %key_from = ();

    # Some initialization...

    $TEMPLATE ||= Template->new();
    $BASE_CLASS = join( '', <DATA> );

MSGFILE:
    foreach my $msg_file ( @{ $self->{_files} } ) {
        $log->is_info &&
            $log->info( "Reading messages from file '$msg_file'" );

        # This may throw an exception, let it bubble up...
        my $messages = $self->_read_messages( $msg_file );

        # This may be really naive...
        #                               en | en-US   | en_US
        my ( $lang ) = $msg_file =~ m/\b(\w\w|\w\w\-\w+|\w\w_\w+)\.\w+$/;
        $log->is_debug &&
            $log->debug( "Using language '$lang' for file '$msg_file'" );
        unless ( $lang ) {
            oi_error "Cannot identify language from message file ",
                     "'$msg_file'. It must end with a language code ",
                     "before the file extension. For example: ",
                     "'myapp-en.msg', 'MyReallyBigApp-es-MX.dat'";
        }
        $lang_msg{ $lang } ||= {};
        foreach my $msg_key ( keys %{ $messages } ) {
            if ( $lang_msg{ $lang }->{ $msg_key } ) {
                $log->error( "DUPLICATE MESSAGE KEY FOUND. Key '$msg_key' ",
                             "from '$msg_file' was already found in message ",
                             "file '$key_from{ $msg_key }' read in earlier. ",
                             "Existing key will not be overwritten which ",
                             "may cause odd application behavior." );
            }
            else {
                $lang_msg{ $lang }->{ $msg_key } = $messages->{ $msg_key };
                $key_from{ $msg_key } = $msg_file;
            }
        }
    }

    # Now all messages are read in, generate the classes

    my @generated_classes = ();
    foreach my $lang ( keys %lang_msg ) {
        my $generated_class =
            $self->_generate_language_class( $lang, $lang_msg{ $lang } );
        push @generated_classes, $generated_class;
    }
    return \@generated_classes;
}

########################################
# private methods below here

sub _read_messages {
    my ( $self, $msg_file ) = @_;
    $log ||= get_logger( LOG_INIT );

    $log->is_debug &&
        $log->debug( "Reading messages from file '$msg_file'" );
    open( MSG, '<', $msg_file )
        || oi_error "Cannot read messages from '$msg_file': $!";

    my %messages = ();
    my ( $current_key, $current_msg, $readmore );
    while ( <MSG> ) {
        chomp;

        # Skip comments and blanks unless we're in a readmore block

        next if ( ! $readmore and /^\s*\#/ );
        next if ( ! $readmore and /^\s*$/ );

        my $line = $_;
        my $this_readmore = $line =~ s|\\\s*$||;
        if ( $readmore ) {

            # lop off spaces at the beginning of continued lines so
            # they're more easily distinguished

            $line =~ s/^\s+//;
            $current_msg .= $line;
        }
        else {
            my ( $key, $msg ) = $line =~ /^\s*([\w\.]+)\s*=\s*(.*)$/;
            if ( $key ) {
                if ( $current_key ) {
                    $messages{ $current_key } = $current_msg;
                    $log->is_debug &&
                        $log->debug( "Set '$current_key' = '$current_msg'" );
                }
                $current_key = $key;
                $current_msg = $msg;
                $readmore    = undef;
            }
        }
        $readmore = $this_readmore;
    }
    close( MSG );
    $log->is_debug &&
        $log->debug( "Set '$current_key' = '$current_msg'" );
    $messages{ $current_key } = $current_msg;
    return \%messages;
}

sub _generate_language_class {
    my ( $self, $lang, $messages ) = @_;
    $log ||= get_logger( LOG_INIT );

    unless ( $lang ) {
        oi_error "Cannot generate maketext class without a language";
    }

    my @base_class_pieces = ( 'OpenInteract2', 'I18N' );
    my @lang_class_pieces = @base_class_pieces;

    if ( my @pieces = split( /[\-\_]/, $lang ) ) {
        push @lang_class_pieces, @pieces;
        pop @pieces;
        push @base_class_pieces, @pieces;
    }
    else {
        push @lang_class_pieces, $lang;
    }
    my $base_class = join( '::', @base_class_pieces );
    my $lang_class = join( '::', @lang_class_pieces );
    my %params = (
        lang       => $lang,
        lang_class => $lang_class,
        base_class => $base_class,
        messages   => $messages,
    );

    $log->is_debug &&
        $log->debug( "Trying to generate class '$lang_class' for language ",
                     "'$lang' with base class '$base_class'" );
    my ( $gen_class );
    $TEMPLATE->process( \$BASE_CLASS, \%params, \$gen_class )
        || oi_error "Failed to process maketext subclass template: ",
                    $TEMPLATE->error();
    $log->is_debug &&
        $log->debug( "Processed template okay. Now eval'ing class..." );
    eval $gen_class;
    if ( $@ ) {
        $log->error( "Failed to evaluate generated class\n$gen_class\n$@" );
        oi_error "Failed to evaluate generated class '$lang_class': $@";
    }
    $log->is_debug &&
        $log->debug( "Evaluated class okay" );
    return $lang_class;
}

1;


__DATA__
package [% lang_class %];

use strict;
use base qw( [% base_class %] );

use vars qw( %Lexicon );

sub get_oi2_lang { return '[% lang %]' }

%Lexicon = (
[% FOREACH msg_key = messages.keys %]
  '[% msg_key %]' => qq{[% messages.$msg_key %]},
[% END %]
);

1;

__END__

=head1 NAME

OpenInteract2::I18N::Initializer - Read in localization messages and generate maketext classes

=head1 SYNOPSIS

 my $init = OpenInteract2::I18N::Initializer->new;
 $init->add_message_files( @some_message_files );
 my $gen_classes = $init->run;
 print "I generated the following classes: ", join( @{ $gen_classes } ), "\n";

=head1 DESCRIPTION

This class is generally only used by the OI2 startup procedure, which
scans all packages for message files and adds them to this
initializer, then runs it. The purpose of this class is to generate
subclasses for use with L<Locale::Maketext|Locale::Maketext>. Those
classes are fairly simple and generally only contain a package
variable L<%Lexicon> which C<L::M> uses to work its magic.

=head1 CLASS METHODS

B<new()>

Return a new object. Any parameters are ignored.

=head1 OBJECT METHODS

B<add_message_files( @fully_qualified_files )>

Adds all files in C<@fully_qualified_files> to its internal list of
files to process. It does not process these files until C<run()>.

B<locate_global_message_files()>

Finds all message files (that is, files ending in '.msg') in the
global message directory as reported by the
L<OpenInteract2::Context|OpenInteract2::Context> and adds them to the
initializer. Normally only called by
L<OpenInteract2::Setup|OpenInteract2::Setup>.

Returns: arrayref of fully-qualified files added

B<run()>

Reads messages from all files added via C<add_message_files()> and
generates language-specific subclasses for all messages found. (Once
the subclasses are created the system does not know from where the
messages come since all messages are flattened into a per-language
data structure.) So the following:

 file: msg-en.msg
 keys:
   foo.title
   foo.intro
   foo.label.main

 file: other_msg-en.msg
 keys:
   baz.title
   baz.intro
   baz.conclusion

 file: another_msg-en.msg
   bar.title
   bar.intro
   bar.error.notfound

would be flattened into:

 lang: en
   foo.title
   foo.intro
   foo.label.main
   baz.title
   baz.intro
   baz.conclusion
   bar.title
   bar.intro
   bar.error.notfound

The method throws an exception on any of the following conditions:

=over 4

=item *

Cannot open or read from one of the message files.

=item *

Cannot discern a language from the given filename. The language must
be the last distinct set of characters before the file extension. The
following are ok:

  myapp-en.msg
  myotherapp-en-MX.dat
  messages_en-HK.msg

The following are not:

 english-messages.msg
 messages-en-part2.msg
 messagesen.msg

=item *

Cannot process the template used to generate the class.

=item *

Cannot evaluate the generated class.

=back

Note that a duplicate key (that is, a key defined in multiple message
files) will not generate an exception. Instead it will generate a
logging message with an 'error' level.

See more about the format used for the message files in
L<OpenInteract2::Manual::I18N|OpenInteract2::Manual::I18N>.

Returns: arrayref of the names of the classes generated.

=head1 SEE ALSO

L<OpenInteract2::I18N|OpenInteract2::I18N>

L<OpenInteract2::Manual::I18N|OpenInteract2::Manual::I18N>

L<Locale::Maketext|Locale::Maketext>

=head1 COPYRIGHT

Copyright (c) 2003-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
