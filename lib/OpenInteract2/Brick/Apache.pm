package OpenInteract2::Brick::Apache;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'httpd_cgi_solo.conf' => 'HTTPD_CGI_SOLOCONF',
    'httpd_modperl.conf' => 'HTTPD_MODPERLCONF',
    'httpd_modperl_solo.conf' => 'HTTPD_MODPERL_SOLOCONF',
    'httpd_static.conf' => 'HTTPD_STATICCONF',
    'startup.pl' => 'STARTUPPL',
);

sub get_name {
    return 'apache';
}

sub get_resources {
    return (
        'httpd_cgi_solo.conf' => [ 'conf httpd_cgi_solo.conf', 'yes' ],
        'httpd_modperl.conf' => [ 'conf httpd_modperl.conf', 'yes' ],
        'httpd_modperl_solo.conf' => [ 'conf httpd_modperl_solo.conf', 'yes' ],
        'httpd_static.conf' => [ 'conf httpd_static.conf', 'yes' ],
        'startup.pl' => [ 'conf startup.pl', 'yes' ],
    );
}

sub load {
    my ( $self, $resource_name ) = @_;
    my $inline_sub_name = $INLINED_SUBS{ $resource_name };
    unless ( $inline_sub_name ) {
        OpenInteract2::Exception->throw(
            "Resource name '$resource_name' not found ",
            "in ", ref( $self ), "; cannot load content." );
    }
    return $self->$inline_sub_name();
}

OpenInteract2::Brick->register_factory_type( get_name() => __PACKAGE__ );

=pod

=head1 NAME

OpenInteract2::Brick::Apache - All resources used for creating Apache 1.x configurations in a new website

=head1 SYNOPSIS

  oi2_manage create_website --website_dir=/path/to/site

=head1 DESCRIPTION

This class just holds all the static resources used for creating Apache configuration files when creating a website.

These resources are associated with OpenInteract2 version 1.99_06.

=head2 Resources

You can grab resources individually using the names below and
C<load_resource()> and C<copy_resources_to()>, or you can copy all the
resources at once using C<copy_all_resources_to()> -- see
L<OpenInteract2::Brick> for details.

=over 4


=item B<httpd_cgi_solo.conf>

=item B<httpd_modperl.conf>

=item B<httpd_modperl_solo.conf>

=item B<httpd_static.conf>

=item B<startup.pl>


=back

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS


Chris Winters E<lt>chris@cwinters.comE<gt>


=cut


sub HTTPD_CGI_SOLOCONF {
    return <<'SOMELONGSTRING';
# Change manually:
#   -- Change '127.0.0.1' to your IP address
#   -- Change 'webmaster@mycompany.com' to your contact e-mail address
#   -- Change 'www.mycompany.com' to your website hostname

# If you're using Named virtual hosts, just remove the 'Listen' line

Listen 127.0.0.1:80
<VirtualHost 127.0.0.1:80>
Port 80
ServerAdmin webmaster@mycompany.com
ServerName www.mycompany.com
#SuexecUserGroup user group
DocumentRoot [% website_dir %]/html

LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
CustomLog [% website_dir %]/logs/access_log combined
ErrorLog  [% website_dir %]/logs/error_log

# Uncomment for using FastCGI
#AddHandler fastcgi-script .fcgi
AddHandler cgi-script     .cgi

Alias /cgi-bin [% website_dir %]/cgi-bin
<Directory [% website_dir %]/cgi-bin>
    AllowOverride None
    Options ExecCGI
    Order allow,deny
    Allow from all
</Directory>

# Override any global /images alias
#Alias /images [% website_dir %]/html/images

# This sends all incoming requests (except for images, robot help and
# dumb Code Red requests) to the OpenInteract cgi script handler
# (/cgi-bin/oi2.cgi)

# Tell mod_rewrite to start working for this VirtualHost

RewriteEngine On

# Any URL beginning with /images will be answered by this server and
# no further mod_rewrite rules will be processed

RewriteRule ^/images - [L]

# Enable your front-end server to handle search engine requests

RewriteRule ^/robots\.txt - [L]

# Discard (with a '403 Forbidden') requests for the Code Red document
# (hole in IIS servers that can keep your server busy...)

RewriteRule ^/default\.ida - [F]

# Pass all other request to the oi2 cgi script
RewriteRule ^/(.*) [% website_dir %]/cgi-bin/oi2.cgi/$1 [NS,T=cgi-script]

</VirtualHost>


SOMELONGSTRING
}

sub HTTPD_MODPERLCONF {
    return <<'SOMELONGSTRING';
# Change manually:
#   -- Change '127.0.0.1' to your IP address
#   -- Change 'webmaster@mycompany.com' to your contact e-mail address
#   -- Change 'www.mycompany.com' to your website hostname
#   -- If you wish to run the mod_perl server on a port other than 8080, change it

# NOTE: This is meant to be used in a proxy environment. If you're not
# running a proxy server in front of this and instead want to run OI
# standalone, see the file 'httpd_modperl_solo.conf'

# If you're using Named virtual hosts, just remove the 'Listen' line

Listen 127.0.0.1:8080
<VirtualHost 127.0.0.1:8080>
Port 8080
ServerAdmin webmaster@mycompany.com
ServerName www.mycompany.com
DocumentRoot [% website_dir %]/html

LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
CustomLog [% website_dir %]/logs/access_log_modperl combined
ErrorLog  [% website_dir %]/logs/error_log_modperl

# This reads in all your SPOPS objects, sets up aliases, database
# handles, template processing objects, etc.

PerlRequire [% website_dir %]/conf/startup.pl

# This is used to read the 'X-Forwarded-For' header created by the
# mod_proxy_add_forward.c Apache module that should be compiled into
# your front-end proxy server. If you don't have this, then every
# request will appear to come from the proxy server, which can be
# annoying.

PerlPostReadRequestHandler OpenInteract::ProxyRemoteAddr

# This sends all incoming requests to the OpenInteract Apache content
# handler (Apache::OpenInteract2)

# NOTE: If you're not running under the root context, just
# change the path specified in 'Location' to the server
# configuration key 'context_info.deployed_under'

<Location /> 
    SetHandler perl-script 
    PerlHandler Apache::OpenInteract2
</Location>

</VirtualHost>
SOMELONGSTRING
}

sub HTTPD_MODPERL_SOLOCONF {
    return <<'SOMELONGSTRING';
# Change manually:
#   -- Change '127.0.0.1' to your IP address
#   -- Change 'webmaster@mycompany.com' to your contact e-mail address
#   -- Change 'www.mycompany.com' to your website hostname
#   -- If you wish to run the mod_perl server on a port other than 80,
#      change it in the 'Listen' and 'VirtualHost' directives

# If you're using Named virtual hosts, just remove the 'Listen' line

Listen 127.0.0.1:80
<VirtualHost 127.0.0.1:80>
Port 80
ServerAdmin webmaster@mycompany.com
ServerName www.mycompany.com
DocumentRoot [% website_dir %]/html

LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
CustomLog [% website_dir %]/logs/access_log_modperl combined
ErrorLog  [% website_dir %]/logs/error_log_modperl

# This reads in all your SPOPS objects, sets up aliases, database
# handles, template processing objects, etc.

PerlRequire [% website_dir %]/conf/startup.pl

# This sends all incoming requests to the OpenInteract Apache content
# handler (Apache::OpenInteract2)

# NOTE: If you're not running under the root context, just
# change the path specified in 'Location' to the server
# configuration key 'context_info.deployed_under'

<Location /> 
    SetHandler perl-script 
    PerlHandler Apache::OpenInteract2
</Location>

# If you want to serve them up directly (more efficient) add to the
# regex 'css|ico', but if you move OI under a different context you'll
# have to create a separate mapping

<LocationMatch "\.(jpg|gif|png|js|pdf|jar|zip|gz)$">
    SetHandler default-handler
</LocationMatch>

# Override any global /images/ alias
#Alias /images /[% website_dir %]/html/images

<LocationMatch "/images">
    SetHandler default-handler
</LocationMatch>

ScriptAlias /cgi-bin [% website_dir %]/cgi-bin
<Location /cgi-bin>
    SetHandler cgi-script
    AllowOverride None
    Options None
    Order allow,deny
    Allow from all
</Location>

</VirtualHost>

SOMELONGSTRING
}

sub HTTPD_STATICCONF {
    return <<'SOMELONGSTRING';
# Change manually:
#   -- Change '127.0.0.1' to your IP address
#   -- Change 'webmaster@mycompany.com' to your contact e-mail address
#   -- Change 'www.mycompany.com' to your website hostname

# If you're using Named virtual hosts, just remove the 'Listen' line

Listen 127.0.0.1:80
<VirtualHost 127.0.0.1:80>
Port 80

ServerAdmin webmaster@mycompany.com
ServerName www.mycompany.com
DocumentRoot [% website_dir %]/html

LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
CustomLog [% website_dir %]/logs/access_log_static combined
ErrorLog  [% website_dir %]/logs/error_log_static

#
# Proxy server setup
#

# Tell mod_rewrite to start working for this VirtualHost

RewriteEngine On

# Any URL beginning with /images will be answered by this server and
# no further mod_rewrite rules will be processed

RewriteRule ^/images - [L]
RewriteRule ^/favicon.ico - [L]

# Enable your front-end server to handle search engine requests

RewriteRule ^/robots\.txt - [L]

# Discard (with a '403 Forbidden') requests for the Code Red document
# (hole in IIS servers that can keep your backend mod_perl servers
# busy...)

RewriteRule ^/default\.ida - [F]

# Proxy ([P]) all other requests to a back-end server

RewriteRule ^/(.*) http://127.0.0.1:8080/$1 [P]

# Ensure that the locations coming back from the back-end server
# through this proxy to the client are correct; otherwise, users would
# see things like:
#
#  http://www.mysite.com:8080/User/listing/
#
# in their location, which messes up *everything*.

ProxyPassReverse / http://127.0.0.1/

# This last line ensures that bad people don't try to use your proxy
# server to get other content from around the web

RewriteRule ^proxy:.* - [F]

</VirtualHost>

SOMELONGSTRING
}

sub STARTUPPL {
    return <<'SOMELONGSTRING';
#!/usr/bin/perl

use strict;
use Apache::OpenInteract2;
use Apache::OpenInteract2::HttpAuth;
use Log::Log4perl;
use OpenInteract2::Config::Bootstrap;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context;

my $BOOTSTRAP_CONFIG_FILE = '[% website_dir %]/conf/bootstrap.ini';

{
    Log::Log4perl::init( '[% website_dir %]/conf/log4perl.conf' );
    my $bootstrap = OpenInteract2::Config::Bootstrap->new({
        filename => $BOOTSTRAP_CONFIG_FILE
    });
    my $ctx = OpenInteract2::Context->create(
                    $bootstrap, { temp_lib_create => 'create' } );
    $ctx->assign_request_type( 'apache' );
    $ctx->assign_response_type( 'apache' );
}

1;

SOMELONGSTRING
}

