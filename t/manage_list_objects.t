# -*-perl-*-

# $Id: manage_list_objects.t,v 1.3 2003/05/07 11:33:35 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 31;

require_ok( 'OpenInteract2::Manage' );

install_website();
my $website_dir = get_test_site_dir();

my $task = eval {
    OpenInteract2::Manage->new( 'list_objects',
                                { website_dir => $website_dir } )
};
ok( ! $@, 'Created task' );
is( ref $task, 'OpenInteract2::Manage::Website::ListObjects',
    'Task of correct class' );

my @status = eval { $task->execute };
ok( ! $@, 'Task executed ok' );
is( scalar @status, 13,
    'Correct number of SPOPS objects listed' );

my @names = qw(
    content_type error_object group news news_section
    object_action page page_content page_directory
    security theme themeprop user
);
my @classes = map { "OpenInteract2::$_" }
              qw( ContentType ErrorObject Group News NewsSection
                  ObjectAction Page PageContent PageDirectory
                  Security Theme ThemeProp User );
for ( my $i = 0; $i < scalar @names; $i++ ) {
    is( $status[$i]->{name}, $names[$i],
        "Object " . ($i + 1) . " name correct ($names[$i])" );
    is( $status[$i]->{class}, $classes[$i],
        "Object " . ($i + 1) . " class correct ($classes[$i])" );
}
