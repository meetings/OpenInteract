package OpenInteract2::Util;

# $Id: Util.pm,v 1.16 2004/12/05 21:08:20 lachoy Exp $

use strict;
use Digest::MD5;
use Log::Log4perl            qw( get_logger );
use Mail::Sendmail ();
use MIME::Lite     ();
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Secure            qw( :level :verbose );

$OpenInteract2::Util::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant DEFAULT_SUBJECT        => 'Mail sent from OpenInteract';
use constant DEFAULT_ATTACH_MESSAGE => 'Emailing attachments';

# All other types except those listed here are 'base64' encoding

my %TEXT_ENCODINGS = map { $_ => '8bit' }
                     qw( text/csv text/html text/html text/plain text/xml
                         application/x-javascript application/x-perl );

########################################
# DATE ROUTINES

# Return a { time } (or the current time) formatted with { format }
#
# Signature: $time_string = $class->now( [ { format => $strftime_format,
#                                            time   => $time_in_seconds } ] );

sub now {
    my ( $class, $p ) = @_;
    $p->{format} ||= '%Y-%m-%d %T';
    $p->{time}   ||= time;
    return CTX->create_date({ epoch => $p->{time} })
              ->strftime( $p->{format} );
}


# Return the current time formatted 'yyyy-mm-dd'
#
# Signature: $date_string = $class->today();

sub today {
    return $_[0]->now({ format => '%Y-%m-%e' });
}



########################################
# FILE ROUTINES

sub read_file_lines {
    my ( $class, $filename ) = @_;
    unless ( -f $filename ) {
        oi_error "Cannot open '$filename': file does not exist";
    }
    eval { open( MOD, '<', $filename ) || die $! };
    if ( $@ ) {
        oi_error "Cannot read '$filename': $@";
    }
    my @lines = ();
    while ( <MOD> ) {
        next if ( /^\s*$/ );
        next if ( /^\s*\#/ );
        chomp;
        push @lines, $_;
    }
    return \@lines;
}


# Read in a file and evaluate it as Perl code

sub read_file_perl {
    my ( $class, $filename ) = @_;
    unless ( -f $filename ) {
        oi_error "Cannot open '$filename': file does not exist";
    }
    eval { open( PF, '<', $filename ) || die $! };
    if ( $@ ) {
        oi_error "Cannot read '$filename': $@";
    }
    local $/ = undef;
    my $raw = <PF>;
    my ( $data );
    {
        no strict 'vars';
        $data = eval $raw;
        if ( $@ ) {
            oi_error "Cannot evaluate [$filename] as perl code: $@";
        }
    }
    return $data;
}

sub digest_file {
    my ( $class, $file ) = @_;
    my $md5 = Digest::MD5->new();
    open( IN, '<', $file ) || die "Cannot read '$file' for digest: $!";
    binmode( IN );
    $md5->addfile( *IN );
    close( IN );
    return $md5->hexdigest;
}

########################################
# EMAIL ROUTINES

sub send_email {
    my ( $class, $p ) = @_;
    return $class->_send_email_attachment( $p ) if ( $p->{attach} );
    $log ||= get_logger( LOG_OI );
    my %header_info = $class->_build_header_info( $p );
    my $smtp_host   = $class->_get_smtp_host( $p );
    my %mail = (
        %header_info,
        smtp    => $smtp_host,
        message => $p->{message},
    );
    $log->is_info &&
        $log->info( "Trying to send to [$p->{email}]" );
    $log->is_debug &&
        $log->debug( "Message being sent: $p->{message}" );
    eval { Mail::Sendmail::sendmail( %mail ) || die $Mail::Sendmail::error };
    if ( $@ ) {
        oi_error "Cannot send email. Error: $@";
    }
    $log->is_info &&
        $log->info( "Mail seems to have been sent ok" );
    return 1;
}


sub _send_email_attachment {
    my ( $class, $p ) = @_;
    return $class->send_email( $p )  unless ( $p->{attach} );
    my $attachments = ( ref $p->{attach} eq 'ARRAY' )
                        ? $p->{attach} : [ $p->{attach} ];
    unless ( scalar @{ $attachments } > 0 ) {
        return $class->send_email( $p );
    }

    my %header_info = $class->_build_header_info( $p );
    my $initial_text = $p->{message} || DEFAULT_ATTACH_MESSAGE;
    my $msg = MIME::Lite->new( %header_info,
                               Data => $initial_text,
                               Type => 'text/plain' );
    foreach my $filename ( @{ $attachments } ) {
        my $cleaned_name = $class->_clean_attachment_filename( $filename );
        next unless ( $cleaned_name );
        my ( $ext ) = $cleaned_name =~ /\.(\w+)$/;
        my $mime_type = eval {
            CTX->lookup_object( 'content_type' )
               ->mime_type_by_extension( lc $ext );
        };
        my $encoding = $TEXT_ENCODINGS{ $mime_type } || 'base64';
        $msg->attach( Type     => $mime_type,
                      Encoding => $encoding,
                      Path     => $cleaned_name );
    }

    my $smtp_host = $class->_get_smtp_host( $p );
    MIME::Lite->send( 'smtp', $smtp_host, Timeout => 10 );
    eval { $msg->send || die "Cannot send message: $!" };
    if ( $@ ) {
        oi_error "Cannot send email. Error: $@";
    }

}


sub _build_header_info {
    my ( $class, $p ) = @_;
    my $mail_config = CTX->lookup_mail_config;
    return ( To      => $p->{to}      || $p->{email},
             From    => $p->{from}    || $mail_config->{admin_email},
             Subject => $p->{subject} || DEFAULT_SUBJECT );
}


sub _get_smtp_host {
    my ( $class, $p ) = @_;
    my $mail_config = CTX->lookup_mail_config;
    return $p->{smtp} ||
           $mail_config->{smtp_host};
}


# Ensure that no absolute filenames are used, no directory traversals
# (../), and that the filename exists

sub _clean_attachment_filename {
    my ( $class, $filename ) = @_;
    $log ||= get_logger( LOG_OI );
    $log->is_debug &&
        $log->debug( "Attachment filename begin [$filename]" );

    # First, see if they use an absolute. If so, strip off the leading
    # '/' and assume they meant the absolute website directory

    if ( $filename =~ s|\.\.||g ) {
        $log->is_debug &&
            $log->debug( "File had '..'; now [$filename]" );
    }

    if ( $filename =~ s|^/+|| ) {
        $log->is_debug &&
            $log->debug( "File started '/'; now [$filename]" );
    }

    my $website_dir = CTX->lookup_directory( 'website' );
    my $cleaned_filename = File::Spec->catfile( $website_dir, $filename );
    if ( -f $cleaned_filename ) {
        $log->is_debug &&
            $log->debug( "Existing file [$cleaned_filename]" );
        return $cleaned_filename;
    }
    $log->is_debug &&
        $log->debug( "Nonexisting file [$cleaned_filename]" );
    return undef;
}

########################################
# SECURITY ROUTINES

my %VERBOSE_SECURITY = (
  SEC_LEVEL_NONE_VERBOSE()    => SEC_LEVEL_NONE,
  SEC_LEVEL_SUMMARY_VERBOSE() => SEC_LEVEL_SUMMARY,
  SEC_LEVEL_READ_VERBOSE()    => SEC_LEVEL_READ,
  SEC_LEVEL_WRITE_VERBOSE()   => SEC_LEVEL_WRITE,
);

sub verbose_to_level {
    my ( $class, $verbose ) = @_;
    return $VERBOSE_SECURITY{ uc $verbose };
}

1;

__END__

=head1 NAME

OpenInteract2::Util - Package of routines that do not really fit anywhere else

=head1 SYNOPSIS

 # Send a mail message from anywhere in the system
 eval { OpenInteract2::Util->send_mail({ to      => 'dingdong@nutty.com',
                                        from    => 'whynot@metoo.com',
                                        subject => 'wassup?',
                                        message => 'we must get down' }) };
 if ( $@ ) {
     warn "Mail not sent! Reason: $@";

 }
 
 # Send a mail message with an attachment from anywhere in the system
 
 eval { OpenInteract2::Util->send_mail({ to      => 'dingdong@nutty.com',
                                        from    => 'whynot@metoo.com',
                                        subject => 'wassup?',
                                        message => 'we must get down',
                                        attach  => 'uploads/data/item4.pdf' }) };
 if ( $@ ) {
     warn "Mail not sent! Reason: $@";
 }

=head1 DESCRIPTION

This class currently implments utilities for sending email. Note: In
the future the mailing methods may move into a separate class (e.g.,
C<OpenInteract2::Mailer>)

=head1 DATE METHODS

B<now( \%params )>

Returns a formatted string representing right now.

Parameters:

=over 4

=item *

B<format>: Modifies how the date looks with a C<strftime> format
string. Defaults is '%Y-%m-%d %T'.

=item *

B<time>: An epoch time. to use for the date. Defaults to right now.

=back

B<today()>

Returns today's date in a string formatted '%Y-%m-%d', e.g.,
'2003-04-01' for April 1, 2003.

=head1 FILE METHODS

B<read_file_lines( $filename )>

Returns content of C<$filename> as an arrayref of lines, with blanks
and comments skipped.

B<read_perl_file( $filename )>

Returns content of C<$flename> evaluated as a Perl data structure.

B<digest_file( $filename )>

Returns the hex MD5 digest of C<$filename> contents. (See
L<Digest::MD5> for restrictions, notably regarding unicode.)

=head1 MAIL METHODS

B<send_email( \% )>

Sends an email with the parameters you specify.

On success: returns a true value;

On failure: throws OpenInteract2::Exception with message containing
the reason for the failure.

The parameters used are:

=over 4

=item *

B<to> ($) (required)

To whom will the email be sent. Values such as:

 to => 'Mario <mario@donkeykong.com>'

are fine.

=item *

B<from> ($) (optional)

From whom the email will be sent. If not specified we use the value of
the C<mail.admin_email> key in your server configuration.

=item *

B<message> ($) (optional)

What the email will say. Sending an email without any attachments and
without a message is pointless but allowed. If you do not specify a
message and you are sending attachments, we use a simple one for you.

=item *

B<subject> ($) (optional)

Subject of email. If not specified we use 'Mail sent from OpenInteract'

=item *

B<attach> ($ or \@) (optional)

One or more files to send as attachments to the message. (See below.)

=back

B<Attachments>

You can specify any type or size of file.

B<Example usages>

 # Send a christmas list
 
 eval { OpenInteract2::Util->send_mail({
                         to      => 'santa@xmas.com',
                         subject => 'gimme gimme!',
                         message => join "\n", @xmas_list }) };
 if ( $@ ) {
   my $ei = OpenInteract2::Error->get;
   carp "Failed to send an email! Error: $ei->{system_msg}\n",
        "Mail to: $ei->{extra}{to}\nMessage: $ei->{extra}{message}";
 }
 
 # Send a really fancy christmas list
 
 eval { OpenInteract2::Util->send_mail({
                         to      => 'santa@xmas.com',
                         subject => 'Regarding needs for this year',
                         message => 'Attached is my Christmas list. ' .
                                    'Please acknowlege with fax.',
                         attach  => [ 'lists/my_xmas_list-1.39.pdf' ] }) };
 if ( $@ ) {
   my $ei = OpenInteract2::Error->get;
   carp "Failed to send an email! Error: $ei->{system_msg}\n",
        "Mail to: $ei->{extra}{to}\nMessage: $ei->{extra}{message}";
 }
 
 # Send an invoice for a customer; if it fails, throw an error which
 # propogates an alert queue for customer service reps
 
 eval { OpenInteract2::Util->send_mail({
                         to      => $customer->{email},
                         subject => "Order Reciept: #$order->{order_number}",
                         message => $myclass->create_invoice( $order ) }) };

=head1 SECURITY LEVELS

B<verbose_to_level( $verbose_security_level )>

Translate a verbose security level (e.g., 'NONE', 'SUMMARY', 'READ',
'WRITE') into the relevant constant value from
L<SPOPS::Secure|SPOPS::Secure>. If C<$verbose_security_level> doesn't
match up to one, undef is returned.

=head1 TO DO

B<Spool email option>

Instead of sending the email immediately, provide the option for
saving the mail information to a spool directory
($CONFIG-E<gt>{dir}{mail}) for later processing.

Also, have the option for spooling the mail on a sending error as well
so someone can go back to the directory, edit it and resubmit it for
processing.

B<Additional options>

In the server configuration file, be able to do something like:

[mail]
smtp_host     = 127.0.0.1
admin_email   = admin@mycompany.com
content_email = content@mycompany.com
max_size      = 3000           # in KB
header        = email_header   # template name
footer        = email_footer   # template name

And have emails with a size E<gt> 'max_size' get rejected (or spooled),
while all outgoing emails (unless otherwise specified) get the header
and footer templates around the content.

=head1 SEE ALSO

L<Mail::Sendmail|Mail::Sendmail>

L<MIME::Lite|MIME::Lite>

=head1 COPYRIGHT

Copyright (c) 2001-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
