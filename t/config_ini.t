# -*-perl-*-

# $Id: config_ini.t,v 1.13 2003/08/22 02:19:39 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 24;

require_ok( 'OpenInteract2::Config' );

my $test_config = <<'TEST';
[Global]
sub1 = val1

[head1]
sub1 = val1
sub1 = val2

[head2]
sub1 = val1
sub2 = this is a longer value

[head3 child]
sub1 = val1
sub1 = val2
sub2 = val3
TEST

{
    my $conf = eval { OpenInteract2::Config->new( 'ini',
                                                  { content => $test_config } ) };
    ok( ! $@, "Object created (content)" );
    is( ref( $conf ), 'OpenInteract2::Config::IniFile',
        'Correct object type created (content)' );
    is( $conf->{sub1}, 'val1',
        'Global value read in correctly (content)' );
    is( $conf->{head2}{sub1}, 'val1',
        'Sub value scalar read in correctly (content)' );
    is( $conf->{head1}{sub1}[0], 'val1',
        'Sub value array read in correctly (content)' );
    is( $conf->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar read in correctly (content)' );
    is( $conf->{head3}{child}{sub1}[0], 'val1',
        'Nested sub value array read in correctly (content)' );
}

{
    my $config_file = get_use_file( 'test_config.ini', 'name' );
    my $conf = eval { OpenInteract2::Config->new( 'ini',
                                                  { filename => $config_file } ) };
    ok( ! $@, "Object created (file)" );
    is( ref( $conf ), 'OpenInteract2::Config::IniFile',
        'Correct object type created (file)' );
    is( $conf->{sub1}, 'val1',
        'Global value read in correctly (file)' );
    is( $conf->{head2}{sub1}, 'val1',
        'Sub value scalar read in correctly (file)' );
    is( $conf->{head1}{sub1}[0], 'val1',
        'Sub value array read in correctly (file)' );
    is( $conf->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar read in correctly (file)' );
    is( $conf->{head3}{child}{sub1}[0], 'val1',
        'Nested sub value array read in correctly (file)' );
}

initialize_context();

{
    my $server_conf_file = File::Spec->catfile( get_test_site_dir(), 'conf',
                                                'server.ini' );
    my $file_conf = eval {
        OpenInteract2::Config->new( 'ini', { filename => $server_conf_file } )
    };
    ok( ! $@,
        'Read from file (server)' );
    is( ref $file_conf, 'OpenInteract2::Config::IniFile',
        'Correct object type  (server)' );
    is( $file_conf->{promote_oi}, 'yes',
        'Global value read in correctly (server)' );
    is( scalar keys %{ $file_conf->{datasource} }, 2,
        'Test hash read  (server)' );
    is( $file_conf->{mail}{smtp_host}, '127.0.0.1',
        'Test scalar read  (server)' );

    ok( $file_conf->{dir}{website} = get_test_site_dir(),
        'Set dir (server)' );
    is( $file_conf->{dir}{error}, '$WEBSITE/error',
        'Pretranslated dir (server)' );
    ok( $file_conf->translate_dirs,
        'Dir translate run (server)' );
    is( $file_conf->{dir}{error}, File::Spec->catdir( get_test_site_dir(), 'error' ),
        'Translated dir (server)' );
}

# TODO: Add 'write_file' test and be sure we have arrays and
# subsections
