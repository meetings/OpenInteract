# -*-perl-*-

# $Id: manage_list_packages.t,v 1.12 2003/10/21 11:34:19 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 37;

require_ok( 'OpenInteract2::Manage' );

install_website();
my $website_dir = get_test_site_dir();

my $task = eval {
    OpenInteract2::Manage->new( 'list_packages',
                                { website_dir => $website_dir } )
};
ok( ! $@, 'Created task' );
is( ref $task, 'OpenInteract2::Manage::Website::ListPackages',
    'Task of correct class' );

my @status = eval { $task->execute };
ok( ! $@, 'Task executed ok' );
is( scalar @status, 16,
    'Correct number of packages listed' );

my %package_versions = get_package_versions();

my $count = 0;
foreach my $package_name ( sort keys %package_versions ) {
    is( $status[$count]->{name}, $package_name,
        "Package " . ($count + 1) . " name correct ($package_name)" );
    my $version = $package_versions{ $package_name };
    is( $status[$count]->{version}, $version,
        "Package " . ($count + 1) . " version correct ($version)" );
    $count++;
}
