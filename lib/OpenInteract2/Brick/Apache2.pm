package OpenInteract2::Brick::Apache2;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'startup_mp2.pl' => 'STARTUP_MP2PL',
    'httpd_mp2_solo.conf' => 'HTTPD_MP2_SOLOCONF',
);

sub get_name {
    return 'apache2';
}

sub get_resources {
    return (
        'startup_mp2.pl' => [ 'conf startup_mp2.pl', 'yes' ],
        'httpd_mp2_solo.conf' => [ 'conf httpd_mp2_solo.conf', 'yes' ],
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

OpenInteract2::Brick::Apache2 - All resources used for creating Apache 2.x configurations in a new website

=head1 SYNOPSIS

  oi2_manage create_website --website_dir=/path/to/site

=head1 DESCRIPTION

This class just holds all the static resources used for creating Apache 2.x configuration files when creating a website.

These resources are associated with OpenInteract2 version 1.99_06.

=head2 Resources

You can grab resources individually using the names below and
C<load_resource()> and C<copy_resources_to()>, or you can copy all the
resources at once using C<copy_all_resources_to()> -- see
L<OpenInteract2::Brick> for details.

=over 4


=item B<startup_mp2.pl>

=item B<httpd_mp2_solo.conf>


=back

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS


Chris Winters E<lt>chris@cwinters.comE<gt>


=cut


sub STARTUP_MP2PL {
    return <<'SOMELONGSTRING';
#!/usr/bin/perl

use strict;
use Apache2 ();
use Apache2::OpenInteract2;
use CGI;
use Log::Log4perl;
use OpenInteract2::Config::Bootstrap;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context;

CGI->compile( ':all' );

my $BOOTSTRAP_CONFIG_FILE = '[% website_dir %]/conf/bootstrap.ini';

{
    Log::Log4perl::init( '[% website_dir %]/conf/log4perl.conf' );
    my $bootstrap = OpenInteract2::Config::Bootstrap->new({
        filename => $BOOTSTRAP_CONFIG_FILE
    });
    my $ctx = OpenInteract2::Context->create(
                    $bootstrap, { temp_lib_create => 'create' } );
    $ctx->assign_request_type( 'apache2' );
    $ctx->assign_response_type( 'apache2' );
}

1;

SOMELONGSTRING
}

sub HTTPD_MP2_SOLOCONF {
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
ServerAdmin webmaster@mycompany.com
ServerName www.mycompany.com
DocumentRoot [% website_dir %]/html

LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
CustomLog [% website_dir %]/logs/access_log_mp2 combined
ErrorLog  [% website_dir %]/logs/error_log_mp2

# This reads in all your SPOPS objects, sets up aliases, database
# handles, template processing objects, etc.

PerlRequire [% website_dir %]/conf/startup_mp2.pl

# This sends all incoming requests to the OpenInteract Apache 2.x
# content handler (Apache2::OpenInteract2)

# NOTE: If you're not running under the root context, just
# change the path specified in 'Location' to the server
# configuration key 'context_info.deployed_under'

<Location /> 
    SetHandler perl-script
    PerlResponseHandler Apache2::OpenInteract2
</Location>

<Location /images>
    SetHandler default-handler
</Location>

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

