# -*-perl-*-

# $Id: manage_create_website.t,v 1.6 2003/07/01 17:14:51 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 41;

require_ok( 'OpenInteract2::Manage' );

my ( $site_dir );

END {
    rmtree( $site_dir ) if ( $site_dir and -d $site_dir );
}

$site_dir   = File::Spec->catdir( get_test_dir(),
                                '_manage_create_website' );
my $source_dir = get_source_dir();

my $task = eval {
    OpenInteract2::Manage->new( 'create_website',
                                { website_dir => $site_dir,
                                  source_dir  => $source_dir } )
};
ok( ! $@, 'Task created' );
is( ref $task, 'OpenInteract2::Manage::Website::Create',
    'Correct type of task created' );

# TODO: Add observer here to ensure we get all the fired
# observations...

my @status = eval { $task->execute };
ok( ! $@, 'Task executed' );
is( scalar @status, 97,
    'Number of status messages' );

# Look at the directories we should have created and see they're there

my @check_dir_pieces = qw( cache cache/tt cache/content conf error
                           html html/images html/images/icons
                           logs mail overflow pkg template uploads );
foreach my $piece ( @check_dir_pieces ) {
    my $check_dir = File::Spec->catdir( $site_dir, split( '/', $piece ) );
    ok( -d $check_dir, "Created directory $piece" );
}

# Now just count up the directories and files where it matters

is( count_dirs( $site_dir ), 11,
    "Number of top-level directories" );
is( first_dir( $site_dir ), 'cache',
    'First dir in top-level' );
is( last_dir( $site_dir ), 'uploads',
    'Last dir in top-level' );
is( count_files( $site_dir ), 0,
    "Number of top-level files" );
is( count_dirs( File::Spec->catdir( $site_dir, 'cache' ) ), 2,
    'Number of directories in cache/' );

my $site_conf_dir = File::Spec->catdir( $site_dir, 'conf' );
is( count_files( $site_conf_dir ), 12,
    "Number of files in conf/" );
is( first_file( $site_conf_dir ), 'base.conf',
    "First file in conf/" );
is( last_file( $site_conf_dir ), 'startup.pl',
    "Last file in conf/" );

my $site_html_dir = File::Spec->catdir( $site_dir, 'html' );
is( count_dirs( $site_html_dir ), 1,
    "Number of directories in html/" );
is( count_files( $site_html_dir ), 3,
    "Number of files in html/" );
is( first_file( $site_html_dir ), '.no_overwrite',
    "First file in html/" );
is( last_file( $site_html_dir ), 'login.html',
    "Last file in html/" );

my $site_images_dir = File::Spec->catdir( $site_dir, 'html', 'images' );
is( count_dirs( $site_images_dir ), 1,
    "Number of directories in html/images/" );
is( count_files( $site_images_dir ), 14,
    "Number of files in html/images/" );

my $site_icons_dir = File::Spec->catdir( $site_dir, 'html', 'images', 'icons' );
is( count_files( $site_icons_dir ), 27,
    "Number of files in html/images/icons/" );

my $site_pkg_dir = File::Spec->catdir( $site_dir, 'pkg' );
is( count_dirs( $site_pkg_dir ), 14,
    'Number of directories in pkg/' );

my $site_template_dir = File::Spec->catdir( $site_dir, 'template' );
is( count_files( $site_template_dir ), 56,
    "Number of files in template/" );
is( first_file( $site_template_dir ), '.no_overwrite',
    'First file in template/' );
is( last_file( $site_template_dir ), 'to_group',
    'Last file in template/' );

# Open up the repository and see that all the files are there

my $repository = OpenInteract2::Repository->new(
                         { website_dir => $site_dir });
is( $repository->full_config_dir, $site_conf_dir,
    'Repository reports proper config dir' );
is( $repository->full_package_dir, $site_pkg_dir,
    'Repository reports proper config dir' );
my $packages = $repository->fetch_all_packages;
is( scalar @{ $packages }, 14,
    'Repository contains correct number of packages' );
