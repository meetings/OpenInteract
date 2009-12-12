package OpenInteract::Utility;

# $Id: Utility.pm,v 1.2 2001/10/08 18:19:52 lachoy Exp $

use strict;
use Mail::Sendmail ();
use MIME::Lite     ();

@OpenInteract::Utility::ISA     = ();
$OpenInteract::Utility::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_SUBJECT        => 'Mail sent from OpenInteract';
use constant DEFAULT_ATTACH_MESSAGE => 'Emailing attachments';


my %ATTACH_TYPES = (
  csv  => [ 'text/csv', '8bit' ],
  gif  => [ 'image/gif', 'base64' ],
  tiff => [ 'image/tiff', 'base64' ],
  tif  => [ 'image/tiff', 'base64' ],
  jpeg => [ 'image/jpeg', 'base64' ],
  jpg  => [ 'image/jpeg', 'base64' ],
  png  => [ 'image/png', 'base64' ],
  css  => [ 'text/css', 'base64' ],
  html => [ 'text/html', '8bit' ],
  htm  => [ 'text/html', '8bit' ],
  txt  => [ 'text/plain', '8bit' ],
  xml  => [ 'text/xml', '8bit' ],
  pdf  => [ 'application/pdf', 'base64' ],
  doc  => [ 'application/msword', 'base64' ],
  ps   => [ 'application/postscript', 'base64' ],
  xls  => [ 'application/vnd.ms-excel', 'base64' ],
  ppt  => [ 'application/vnd.ms-powerpoint', 'base64' ],
  wpd  => [ 'application/wordperfect', 'base64' ],
  js   => [ 'application/x-javascript', '8bit' ],
  tar  => [ 'application/x-tar', 'base64' ],
  zip  => [ 'application/zip', 'base64' ],
  gz   => [ 'application/gzip', 'base64' ],
  mp3  => [ 'audio/mpeg', 'base64' ],
  wav  => [ 'audio/x-wav', 'base64' ],
  avi  => [ 'video/x-msvideo', 'base64' ],			
  mov  => [ 'video/quicktime', 'base64' ],
  mpg  => [ 'video/mpeg', 'base64' ],
  mpeg => [ 'video/mpeg', 'base64' ],
);


sub send_email {
    my ( $class, $p ) = @_;
    return $class->_send_email_attachment( $p ) if ( $p->{attach} );

    my $R = OpenInteract::Request->instance;

    my %header_info = $class->_build_header_info( $p );
    my $smtp_host   = $class->_get_smtp_host( $p );
    my %mail = (
        %header_info,
        smtp    => $smtp_host,
        message => $p->{message},
    );
    $R->DEBUG && $R->scrib( 1, "Trying to send  to <<$p->{email}>>" );
    $R->DEBUG && $R->scrib( 2, "Message being sent:\n$p->{message}" );
    eval { Mail::Sendmail::sendmail( %mail ) || die $Mail::Sendmail::error };
    if ( $@ ) {
        my $msg = "Cannot send email. Error: $@";
        OpenInteract::Error->set({ user_msg   => $msg,
                                   type       => 'email',
                                   system_msg => $@,
                                   extra      => \%mail });
        die $msg;
    }
    return 1;
}


sub _send_email_attachment {
    my ( $class, $p ) = @_;
    return $class->send_email( $p )  unless ( $p->{attach} );
    my $attachments = ( ref $p->{attach} eq 'ARRAY' ) ? $p->{attach} : [ $p->{attach} ];
    return $class->send_email( $p )  unless ( scalar @{ $attachments } > 0 );

    my %header_info = $class->_build_header_info( $p );
    my $initial_text = $p->{message} || DEFAULT_ATTACH_MESSAGE;
    my $msg = new MIME::Lite( %header_info,
                              Data => $initial_text,
                              Type => 'text/plain' );
    foreach my $filename ( @{ $attachments } ) {
        my $cleaned_name = $class->_clean_attachment_filename( $filename );
        next unless ( $cleaned_name );
        my ( $ext ) = $cleaned_name =~ /\.(\w+)$/;
        my $type = $ATTACH_TYPES{ lc $ext } || [ 'text/plain', '8bit' ];
        $msg->attach( Type     => $type->[0],
                      Encoding => $type->[1],
                      Path     => $cleaned_name );
    }

    my $smtp_host = $class->_get_smtp_host( $p );
    MIME::Lite->send( 'smtp', $smtp_host, Timeout => 10 );
    eval { $msg->send || die "Cannot send message: $!" };
    if ( $@ ) {
        my $msg = "Cannot send email. Error: $@";
        OpenInteract::Error->set({ user_msg   => $msg,
                                   type       => 'email',
                                   system_msg => $@,
                                   extra      => { %header_info, attachments -> $attachments } });
        die $msg;
    }

}


sub _build_header_info {
    my ( $class, $p ) = @_;
    my $R = OpenInteract::Request->instance;
    return ( To      => $p->{to}      || $p->{email},
             From    => $p->{from}    || $R->CONFIG->{admin_email},
             Subject => $p->{subject} || DEFAULT_SUBJECT );
}


sub _get_smtp_host {
    my ( $class, $p ) = @_;
    my $R = OpenInteract::Request->instance;
    return $p->{smtp} || $R->CONFIG->{smtp_host};
}


# Ensure that no absolute filenames are used, no directory traversals
# (../), and that the filename exists

sub _clean_attachment_filename {
    my ( $class, $filename ) = @_;
    my $R = OpenInteract::Request->instance;

    $R->DEBUG && $R->scrib( 1, "Attachment filename begin: ($filename)" );

    # First, see if they use an absolute. If so, strip off the leading
    # '/' and assume they meant the absolute website directory

    if ( $filename =~ s|\.\.||g ) {
        $R->DEBUG && $R->scrib( 1, "Attachment had '..' sequence. New: ($filename)" );
    }

    if ( $filename =~ s|^/+|| ) {
        $R->DEBUG && $R->scrib( 1, "Attachment started with '/'. New: ($filename)" );
    }

    my $website_dir = $R->CONFIG->get_dir( 'base' );
    my $cleaned_filename = join( '/', $website_dir, $filename );
    if ( -f $cleaned_filename ) {
        $R->DEBUG && $R->scrib( 1, "Final filename exists: ($cleaned_filename)" );
        return $cleaned_filename;
    }
    $R->DEBUG && $R->scrib( 1, "Final filename does NOT EXIST: ($cleaned_filename)" );
    return undef;
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Utility - Package of routines that do not really fit anywhere else

=head1 SYNOPSIS

 # Send a mail message from anywhere in the system
 eval { OpenInteract::Utility->send_mail({ to      => 'dingdong@nutty.com',
                                           from    => 'whynot@metoo.com',
                                           subject => 'wassup?',
                                           message => 'we must get down' }) };
 if ( $@ ) {
     warn "Mail not sent! Reason: $@";

 }

 # Send a mail message with an attachment from anywhere in the system

 eval { OpenInteract::Utility->send_mail({ to      => 'dingdong@nutty.com',
                                           from    => 'whynot@metoo.com',
                                           subject => 'wassup?',
                                           message => 'we must get down',
                                           attach  => 'uploads/data/item4.pdf' }) };
 if ( $@ ) {
     warn "Mail not sent! Reason: $@";
 }


=head1 DESCRIPTION

This class currently implments utilities for sending email. Note: In
the future the mailing methods t may move into a separate class (e.g.,
C<OpenInteract::Mailer>)

=head1 METHODS

B<send_email( \% )>

Sends an email with the parameters you specify.

On success: returns a true value;

On failure: dies with general error message ('Cannot send email:
<error>') and sets typical messages in
L<OpenInteract::Error|OpenInteract::Error>, including the parameters
in extra that match those passed in.

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
the 'admin_email' key in your server configuration
(C<conf/server.perl> file).

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

=head1 ATTACHMENTS

You can specify any type or size of file

=head1 EXAMPLES

 # Send a christmas list

 eval { OpenInteract::Utility->send_mail({
                         to      => 'santa@xmas.com',
                         subject => 'gimme gimme!',
                         message => join "\n", @xmas_list }) };
 if ( $@ ) {
   my $ei = OpenInteract::Error->get;
   carp "Failed to send an email! Error: $ei->{system_msg}\n",
        "Mail to: $ei->{extra}{to}\nMessage: $ei->{extra}{message}";
 }

 # Send a really fancy christmas list

 eval { OpenInteract::Utility->send_mail({
                         to      => 'santa@xmas.com',
                         subject => 'Regarding needs for this year',
                         message => 'Attached is my Christmas list. Please acknowlege with fax.',
                         attach  => [ 'lists/my_xmas_list-1.39.pdf' ] }) };
 if ( $@ ) {
   my $ei = OpenInteract::Error->get;
   carp "Failed to send an email! Error: $ei->{system_msg}\n",
        "Mail to: $ei->{extra}{to}\nMessage: $ei->{extra}{message}";
 }

 # Send an invoice for a customer; if it fails, throw an error which
 # propogates an alert queue for customer service reps

 eval { OpenInteract::Utility->send_mail({
                         to      => $customer->{email},
                         subject => "Order Reciept: #$order->{order_number}",
                         message => $myclass->create_invoice( $order ) }) };
 if ( $@ ) {
     $R->throw({ code => 745 });
 }


=head1 TO DO

B<Spool email option>

Instead of sending the email immediately, provide the option for
saving the mail information to a spool directory
($CONFIG-E<gt>get_dir( 'mail' )) for later processing.

Also, have the option for spooling the mail on a sending error as well
so someone can go back to the directory, edit it and resubmit it for
processing.

B<Additional options>

In the server configuration file, be able to do something like:

 'email' => {
     'smtp_host'     => '127.0.0.1',
     'admin_email'   => 'admin@mycompany.com',
     'content_email' => 'content@mycompany.com',
     'max_size'      => 3000,           # in KB
     'header'        => 'email_header'  # template name
     'footer'        => 'email_footer'  # template name
 }

And have emails with a size > 'max_size' get rejected (or spooled),
while all outgoing emails (unless otherwise specified) get the header
and footer templates around the content.

=head1 BUGS

None known.

=head1 SEE ALSO

L<Mail::Sendmail|Mail::Sendmail>

L<MIME::Lite|MIME::Lite>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
