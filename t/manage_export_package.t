# -*-perl-*-

# $Id: manage_export_package.t,v 1.6 2003/04/24 04:00:25 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 10;

require_ok( 'OpenInteract2::Manage' );

my $package_dir = get_test_package_dir();
my $pwd = get_current_dir();

my $task = eval {
    OpenInteract2::Manage->new( 'export_package',
                                { package_dir => $package_dir } )
};
ok( ! $@, 'Task created' );
is( ref $task, 'OpenInteract2::Manage::Package::Export',
    'Correct type of task created' );
my ( $status ) = eval { $task->execute };
warn $@ if ( $@ );
ok( ! $@, 'Task executed' );
is( $status->{action},   'Export package fruit',
    'Correct action' );
is( $status->{is_ok},    'yes',
    'Status ok' );
is( $status->{package},  'fruit',
    'Package identified properly' );
is( $status->{version},  '1.00',
    'Package version identified properly' );
my $full_filename = File::Spec->catfile( $pwd, 'fruit-1.00.zip' );
is( $status->{filename}, $full_filename,
    'Correct filename exported' );
ok( -f $full_filename,
    'Export file created properly' );
unlink( $full_filename );
