package OpenInteract::Utility;

# $Id: Utility.pm,v 1.1 2001/07/11 12:33:04 lachoy Exp $

use strict;
use Mail::Sendmail ();

@OpenInteract::Utility::ISA     = ();
$OpenInteract::Utility::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG  => 0;

sub send_email {
    my ( $class, $p ) = @_;
    my $R = OpenInteract::Request->instance;
    my %mail = (
        to      => $p->{to}      || $p->{email},
        from    => $p->{from}    || $R->CONFIG->{admin_email},
        subject => $p->{subject} || 'Mail sent from OpenInteract Framework',
        message => $p->{message},
        smtp    => $p->{smtp}    || $R->CONFIG->{smtp_host},
    );
    $R->DEBUG && $R->scrib( 1, "Trying to send  to <<$p->{email}>>" );
    $R->DEBUG && $R->scrib( 2, "Message being sent:\n$p->{message}" );
    eval { Mail::Sendmail::sendmail( %mail ) || die $Mail::Sendmail::error };
    if ( $@ ) {
        my $msg = "Cannot send email. Error: $@";
        OpenInteract::Error->set( { user_msg   => $msg,
                                    type       => 'email',
                                    system_msg => $@, 
                                    extra      => \%mail } );
        die $msg;
    }
    return 1;
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Utility - Package of routines that do not really fit anywhere else

=head1 SYNOPSIS

 # Send a mail message from anywhere in the system
 eval {  OpenInteract::Utility->send_mail( { to => 'dingdong@nutty.com',
                                             from => 'whynot@metoo.com',
                                             subject => 'wassup?',
                                             message => 'lets get down' } ) };
 if ( $@ ) {
   warn "Mail not sent! Reason: $@";
 }

=head1 DESCRIPTION

This class has a number of methods that are simple utilities.

=head1 METHODS

B<send_email( \% )>

Sends an email with the parameters you specify.

On success: returns a true value;

On failure: dies with general error message ('Cannot send email:
<error>') and sets typical messages in OpenInteract::Error, including
the following parameters in {extra}:

 - subject: subject of email
 - from: who is the email from (will use the admin email if not specified)
 - to/email: who is the email going to
 - message: what content is in the email

Example:

 eval { OpenInteract::Utility->send_mail({ 
                         to      => 'santa@xmas.com', 
                         subject => 'gimme!',
                         message => join "\n", @xmas_list }) };
 if ( $@ ) {
   my $ei = OpenInteract::Error->get;
   carp "Failed to send an email! Error: $ei->{system_msg}\n",
        "Mail to: $ei->{extra}->{to}\nMessage: $ei->{extra}->{message}";
 }

=head1 TO DO

B<Spool email on error>

Perhaps throw an error when we cannot send an email, but also spool it
to our website 'email' directory.

B<Allow attachments>

We should be able to refer to files B<only in a particular directory>
for attaching to the email. (We do not want people specifying
'/etc/passwd', right?)

We can have this work both ways:

 # this method can allow nothing outside of its own base file
 # structure (something like this, just a spur-of-the-moment thing...)
 my $attach_id =  $R->utility->register_attachment({ 
                       filename => "uploads/4/this_upload.gif" 
                  });
 ...

 my $rv = $R->utility->send_email( { ..., attachment => $attach_id } );

Something to think about...

=head1 BUGS

None known.

=head1 SEE ALSO

L<Mail::Sendmail>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
