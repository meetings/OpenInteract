# -*-perl-*-

# $Id: config_package.t,v 1.6 2003/06/10 04:48:59 lachoy Exp $

# TODO: Add check for 'filter'

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 22;

my $package       = 'OITest';
my $version       = '1.12';
my @author        = ( 'Me <me@me.com>', 'You <you@you.com>' );
my %plugin        = ( 'TestPlugin' => 'OpenInteract2::Plugin::Test' );
my @spops_file    = qw( conf/object_one.ini conf/object_two.ini );
my @action_file   = qw( conf/action.ini );
my $sql_installer = 'OpenInteract2::SQLInstall::OITest';
my $url           = 'http://www.openinteract.org/';
my $description   = 'Test description.';

my $use_dir = get_use_dir();

require_ok( 'OpenInteract2::Config::Package' );

# First just create an empty object and set values

{
    my $c = OpenInteract2::Config::Package->new();
    is( ref( $c ), 'OpenInteract2::Config::Package', 'Create empty object' );
    is( $c->name( $package ), $package,
        'Package name set' );
    is( $c->version( $version ), $version,
        'Package version set' );
    is_deeply( $c->author( \@author ), \@author,
               'Authors set' );
    is_deeply( $c->template_plugin( \%plugin ), \%plugin,
               'Plugin set' );
    is_deeply( $c->spops_file( \@spops_file ), \@spops_file,
               'SPOPS files set' );
    is_deeply( $c->action_file( \@action_file ), \@action_file,
               'Action files set' );
    is( $c->description( $description ), $description,
        'Description set' );
    my $write_file = get_use_file( 'test-write_package.conf', 'name' );
    is( $c->filename( $write_file ), $write_file,
        'Filename set' );
    eval { $c->save_config() };
    ok( ! $@,
        'Write configuration to file' );
    ok( -f $write_file,
        'Written configuration exists' );
    unlink( $write_file );
}


# Now open an existing file
{
    my $read_file = get_use_file( 'test_package.conf', 'name' );
    my $c = eval {
        OpenInteract2::Config::Package->new({ filename => $read_file })
    };
    ok( ! $@,
        'Package file read' );
    is( $c->name(), $package,
        'Package name read' );
    is( $c->version(), $version,
        'Package version read' );
    is_deeply( $c->author(), \@author,
               'Authors read' );
    is_deeply( $c->template_plugin(), \%plugin,
               'Plugin read' );
    is_deeply( $c->spops_file(), \@spops_file,
               'SPOPS file property read' );
    is_deeply( $c->action_file(), \@action_file,
               'Action file property read' );
    is_deeply( $c->get_spops_files(), \@spops_file,
               'SPOPS file paths read' );
    is_deeply( $c->get_action_files(), \@action_file,
               'Action file paths read' );
    is( $c->description(), $description,
        'Description set' );
}
