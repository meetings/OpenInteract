# -*-perl-*-

# $Id: manage_list_actions.t,v 1.1 2003/05/07 11:30:57 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 39;

require_ok( 'OpenInteract2::Manage' );

install_website();
my $website_dir = get_test_site_dir();

my $task = eval {
    OpenInteract2::Manage->new( 'list_actions',
                                { website_dir => $website_dir } )
};
ok( ! $@, 'Created task' );
is( ref $task, 'OpenInteract2::Manage::Website::ListActions',
    'Task of correct class' );

my @status = eval { $task->execute };
ok( ! $@, 'Task executed ok' );
is( scalar @status, 34,
    'Correct number of actions listed' );

my @names = qw(
    admin_tools_box boxes content_type edit_document_box error
    error_filter file_index group latest_news login_box logout
    lookups news news_section news_tools_box newuser
    object_modify_box objectactivity package page pagedirectory
    pagescan powered_by_box search_box security simple_index
    sitesearch systemdoc template template_tools_box
    templates_used_box theme user user_info_box
);

for ( my $i = 0; $i < scalar @names; $i++ ) {
    is( $status[$i]->{name}, $names[$i],
        "Action " . ($i + 1) . " name correct ($names[$i])" );
}
