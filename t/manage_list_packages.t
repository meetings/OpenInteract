# -*-perl-*-

# $Id: manage_list_packages.t,v 1.3 2003/06/11 00:38:17 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 33;

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
is( scalar @status, 14,
    'Correct number of packages listed' );

my @names    = qw( base base_box base_error base_group base_page
                   base_security base_template base_theme base_user
                   full_text news lookup object_activity system_doc );
my @versions = qw( 2.02 2.01 2.02 2.01 2.04
                   2.01 3.00 2.01 2.03
                   2.01 2.01 2.00 2.02 2.00 );
for ( my $i = 0; $i < scalar @names; $i++ ) {
    is( $status[$i]->{name}, $names[$i],
        "Package " . ($i + 1) . " name correct ($names[$i])" );
    is( $status[$i]->{version}, $versions[$i],
        "Package " . ($i + 1) . " version correct ($versions[$i])" );
}
