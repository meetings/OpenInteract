# -*-perl-*-

# $Id: context.t,v 1.21 2003/07/03 05:28:26 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use OpenInteract2::Manage;
use SPOPS::Secure qw( :level );
use Test::More;

my $website_dir = eval { install_website() };
if ( $@ ) {
    plan skip_all => "Cannot run tests because website creation failed: $@";
    exit;
}
plan tests => 78;

require_ok( 'OpenInteract2::Context' );

my $ctx = eval {
    OpenInteract2::Context->create({
                         website_dir => $website_dir })
};
ok( ! $@, "Created bare context" );

########################################
# ALIASES

is( $ctx->repository_class, 'OpenInteract2::Repository',
    'Repository class alias set' );
is( $ctx->package_class, 'OpenInteract2::Package',
    'Package class alias set' );
is( $ctx->security_object, 'OpenInteract2::Security',
    'Security object alias set' );
is( $ctx->object_security, 'OpenInteract2::Security',
    'Object security alias set' );
is( $ctx->security, 'OpenInteract2::Security',
    'Security alias set' );
is( $ctx->secure, 'SPOPS::Secure',
    'Secure alias set' );
is( $ctx->template_class, 'OpenInteract2::SiteTemplate',
    'Template object class alias set' );

########################################
# DATASOURCES

my $ds_conf = $ctx->datasource_config;
is( ref( $ds_conf ), 'HASH',
    'Datasource config format' );
is( scalar keys %{ $ds_conf }, 2,
    'Number of datasources' );
is( $ds_conf->{main}{spops}, 'SPOPS::DBI::SQLite',
    'Main datasource spops setting' );
is( $ds_conf->{main}{driver_name}, 'SQLite',
    'Main datasource driver name setting' );
is( $ds_conf->{main}{dsn}, join( '=', 'dbname', get_test_site_db_file() ),
    'Main datasource driver name setting' );


########################################
# GLOBAL ATTRIBUTE

ok( $ctx->global_attribute( foo => 'bar' ),
    'Set global attribute' );
is( $ctx->global_attribute( 'foo' ), 'bar',
    'Get global attribute' );
ok( $ctx->clear_global_attributes(),
    'Cleared global attributes' );
is( $ctx->global_attribute( 'foo' ), undef,
    'Get global attribute after clear' );

########################################
# REPOSITORY/PACKAGE

my $repository = $ctx->repository;
is( ref $repository, 'OpenInteract2::Repository',
    'Repository object set in context' );
is( $repository->website_dir, $website_dir,
    'Website directory set in repository' );
my $packages = $repository->fetch_all_packages;
is( scalar @{ $packages }, 14,
    'Number of packages fetched by repository' );
is( $repository->fetch_package( 'base' )->version, '2.03',
    'Package base version' );
is( $repository->fetch_package( 'base_box' )->version, '2.02',
    'Package base_box version' );
is( $repository->fetch_package( 'base_error' )->version, '2.04',
    'Package base_error version' );
is( $repository->fetch_package( 'base_group' )->version, '2.02',
    'Package base_group version' );
is( $repository->fetch_package( 'base_page' )->version, '2.05',
    'Package base_page version' );
is( $repository->fetch_package( 'base_template' )->version, '3.02',
    'Package base_template version' );
is( $repository->fetch_package( 'base_theme' )->version, '2.02',
    'Package base_theme version' );
is( $repository->fetch_package( 'base_user' )->version, '2.04',
    'Package base_user version' );
is( $repository->fetch_package( 'full_text' )->version, '2.03',
    'Package full_text version' );
is( $repository->fetch_package( 'lookup' )->version, '2.01',
    'Package lookup version' );
is( $repository->fetch_package( 'news' )->version, '2.03',
    'Package news version' );
is( $repository->fetch_package( 'object_activity' )->version, '2.03',
    'Package object_activity version' );
is( $repository->fetch_package( 'system_doc' )->version, '2.01',
    'Package system_doc version' );

########################################
# ACTIONS

my $action_table = $ctx->action_table;
is( ref $action_table, 'HASH',
    'Action table is correct data structure' );
is( scalar keys %{ $action_table }, 34,
    'Correct number of actions in table' );

my $news_info = $ctx->lookup_action_info( 'news' );
is( $news_info->{class}, 'OpenInteract2::Action::News',
    'News action has correct class...' );
is( $news_info->{is_secure}, 'yes',
    'and correct security setting...' );
is( $news_info->{task_default}, 'home',
    'and correct default task...' );
is( $news_info->{default_expire}, '84',
    'and correct default expiration...' );
is( $news_info->{default_list_size}, '5',
    'and correct default list size...' );
is( $news_info->{security}{DEFAULT}, SEC_LEVEL_READ,
    'and correct default action security...' );
is( $news_info->{security}{edit}, SEC_LEVEL_WRITE,
    'and correct "edit" security...' );
is( $news_info->{security}{remove}, SEC_LEVEL_WRITE,
    'and correct "remove" security...' );
is( $news_info->{security}{show_summary}, SEC_LEVEL_WRITE,
    'and correct "show_summary" security...' );
is( $news_info->{security}{edit_summary}, SEC_LEVEL_WRITE,
    'and correct "edit_summary" security...' );

# See if the default action info got set
is( $news_info->{content_generator}, 'TT',
    'and correct content generator from default action info...' );
is( $news_info->{controller}, 'tt-template',
    'and correct controller from default action info...' );
#is( $news_info->{method}, 'handler',
#    'and correct handler from default action info...' );

my $box_info = $ctx->lookup_action_info( 'news_tools_box' );
is( $box_info->{template}, 'news::news_tools_box',
    'News toolbox has correct template...' );
is( $box_info->{title}, 'News Tools',
    'and correct title...' );
is( $box_info->{weight}, '4',
    'and correct weight...' );
is( $box_info->{is_secure}, 'no',
    'and correct security setting...' );

my $lookup_info = $ctx->lookup_action_info( 'news_section' );
is( $lookup_info->{action_type}, 'lookup',
    'News section action is a lookup...' );
is( $lookup_info->{object_key}, 'news_section',
    'and has correct object key...' );
is( $lookup_info->{order}, 'section',
    'and has correct order...' );
is( $lookup_info->{field_list}, 'section',
    'and has correct fields...' );
is( $lookup_info->{label_list}, 'Section',
    'and has correct labels...' );
is( $lookup_info->{size_list}, '25',
    'and has correct sizes...' );
is( $lookup_info->{title}, 'News Sections',
    'and has correct title...' );

my $action_none = $ctx->lookup_action_none;
is( ref $action_none, 'OpenInteract2::Action::Page',
    '"none" action proper class' );
is( $action_none->name, 'page',
    '"none" action proper type' );

my $action_nf = $ctx->lookup_action_not_found;
is( ref $action_nf, 'OpenInteract2::Action::Page',
    '"not found" action proper class' );
is( $action_nf->name, 'page',
    '"not found" action proper type' );

# SPOPS tests here

my $spops_config = $ctx->spops_config;
is( ref $spops_config, 'HASH',
    'SPOPS config is correct data structure' );
is( scalar keys %{ $spops_config }, 13,
    'Correct number of SPOPS configs in structure' );

is( $ctx->lookup_object( 'error_object' ), 'OpenInteract2::ErrorObject',
    'SPOPS error lookup matched' );
is( $ctx->lookup_object( 'group' ), 'OpenInteract2::Group',
    'SPOPS group lookup matched' );
is( $ctx->lookup_object( 'content_type' ), 'OpenInteract2::ContentType',
    'SPOPS content_type lookup matched' );
is( $ctx->lookup_object( 'page' ), 'OpenInteract2::Page',
    'SPOPS page lookup matched' );
is( $ctx->lookup_object( 'page_content' ), 'OpenInteract2::PageContent',
    'SPOPS page_content lookup matched' );
is( $ctx->lookup_object( 'page_directory' ), 'OpenInteract2::PageDirectory',
    'SPOPS page_directory lookup matched' );
is( $ctx->lookup_object( 'security' ), 'OpenInteract2::Security',
    'SPOPS security lookup matched' );
is( $ctx->lookup_object( 'theme' ), 'OpenInteract2::Theme',
    'SPOPS theme lookup matched' );
is( $ctx->lookup_object( 'themeprop' ), 'OpenInteract2::ThemeProp',
    'SPOPS themeprop lookup matched' );
is( $ctx->lookup_object( 'user' ), 'OpenInteract2::User',
    'SPOPS user lookup matched' );
is( $ctx->lookup_object( 'object_action' ), 'OpenInteract2::ObjectAction',
    'SPOPS object action lookup matched' );
is( $ctx->lookup_object( 'news' ), 'OpenInteract2::News',
    'SPOPS news lookup matched' );
is( $ctx->lookup_object( 'news_section' ), 'OpenInteract2::NewsSection',
    'SPOPS news_section lookup matched' );

# TODO

# Ensure that the following propogate changes to both the exported
# variables and the server config, as appropriate
#
# assign_debug_level
# assign_db_log_level
# assign_deploy_url
# assign_deploy_image_url
# assign_deploy_static_url
# assign_request_type
# assign_response_type

