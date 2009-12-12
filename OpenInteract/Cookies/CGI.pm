package OpenInteract::Cookies::CGI;

# $Id: CGI.pm,v 1.2 2001/10/01 22:08:52 lachoy Exp $

use strict;
use CGI::Cookie  qw();

@OpenInteract::Cookies::CGI::ISA     = ();
$OpenInteract::Cookies::CGI::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);


# Parse the cookies using CGI::Cookie

sub parse {
    my ( $class ) = @_;
    my $R = OpenInteract::Request->instance;
    my %cookies = CGI::Cookie->fetch;
    foreach my $name ( keys %cookies ) {
        my $value = $cookies{ $name }->value;
        $R->DEBUG && $R->scrib( 2, "Getting cookie $name to $value" );
        $R->{cookie}{in}{ $name } = $value;
    }
    return $R->{cookie}{in};
}


sub bake {
    my ( $class ) = @_;
    my $R = OpenInteract::Request->instance;
    my $apache = $R->apache;
    foreach my $name ( keys %{ $R->{cookie}{out} } ) {
        $R->DEBUG && $R->scrib( 2, "Setting $name to value ", $R->{cookie}{out}{ $name }->value );
        $apache->header_out( 'Set-Cookie', $R->{cookie}{out}{ $name } )
    }
    return 1;
}


sub create_cookie {
    my ( $class, $p ) = @_;
    my $R = OpenInteract::Request->instance;
    return $R->{cookie}{out}{ $p->{name} } =
                    CGI::Cookie->new( -name    => $p->{name}, 
                                      -value   => $p->{value},
                                      -path    => $p->{path}, 
                                      -expires => $p->{expires} );
}


1;

__END__

=pod

=head1 NAME

OpenInteract::Cookies::CGI - handler to parse/output cookies from/to the client using CGI::Cookie

=head1 SYNOPSIS

 # In your website's 'conf/server.perl' file:

 # Use CGI::Cookie

 'system_alias' => {
       'OpenInteract::Cookies::CGI'    => [ qw/ cookies / ],
       ...,
 }
 # Retrieve the cookies from the client request

 $R->cookies->parse;

 # Place cookies in the outbound content header

 $R->cookies->bake;

 # Retrieve a cookie value in an OpenInteract content handler

 $params->{search} = $R->{cookie}{in}{search_value};
 
 # Create a new cookie

 $R->cookies->create_cookie({ name => 'search_value',
                              expires => '+3M',
                              value => 'this AND that' });

 # Expire an old cookie

 $R->cookies->create_cookie({ name => 'search_value',
                              expires => '-3d',
                              value => undef });

=head1 DESCRIPTION

This module defines methods for retrieving, setting and creating
cookies. If you do not know what a cookie is, check out:

 http://www.ics.uci.edu/pub/ietf/http/rfc2109.txt

OpenInteract currently uses one of two modules to perform these
actions. They adhere to the same interface but perform the actions
using different helper modules. This module uses L<CGI::Cookie> to do
the actual cookie actions. Since this is a pure-Perl module, it should
work everywhere Perl works.

To use this implementation, set the following key in the
C<conf/server.perl> file for your website:

 system_aliases => {
   ...,
   'OpenInteract::Cookies::CGI' => [ qw/ cookies / ],
 },

=head1 METHODS

Methods for this class.

B<create_cookie( \%params  )>

This function is probably the only one you will ever use from this
module. Pass in normal parameters (see below) and the function will
create a cookie and put it into $R for you.

Parameters:

=over 4

=item *

name ($) (required)

Name of cookie

=item *

value ($ (required)

Value of cookie

=item *

expires ($ (optional)

When it expires ( '+3d', etc.). Note that negative values (e.g., '-3d'
will expire the cookie on most browsers. Leaving this value empty or
undefined will create a 'short-lived' cookie, meaning it will expire
when the user closes her browser.

=item *

path ($) (optional)

Path it responds to

=back

B<parse()>

Read in the cookies passed to this request and file them into the
hashref:

 $R->{cookie}{in}

with the key as the cookie name.

B<bake()>

Puts the cookies from $R-E<gt>{cookie}-E<gt>{out} into the outgoing
headers.

=head1 TO DO

B<Fully CGI-ify>

Instead of calling $r->headers_out(...), put the cookies into an
arrayref which can be picked up by the header printer.

=head1 BUGS 

None known.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut

