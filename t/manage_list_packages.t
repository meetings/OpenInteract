# -*-perl-*-

# $Id: manage_list_packages.t,v 1.15 2005/03/04 03:46:21 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 21;

require_ok( 'OpenInteract2::Manage' );

install_website();
my $website_dir = get_test_site_dir();

my $task = eval {
    OpenInteract2::Manage->new( 'list_packages',
                                { website_dir => $website_dir } )
};
ok( ! $@, 'Created task' ) || diag "Error: $@";
is( ref $task, 'OpenInteract2::Manage::Website::ListPackages',
    'Task of correct class' );

my @status = eval { $task->execute };
ok( ! $@, 'Task executed ok' ) || diag "Error: $@";
is( scalar @status, 16,
    'Correct number of packages listed' );

my $count = 0;
foreach my $package_name ( get_packages() ) {
    is( $status[$count]->{name}, $package_name,
        "Package " . ($count + 1) . " name correct ($package_name)" );
    $count++;
}
