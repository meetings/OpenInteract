# -*-perl-*-

# $Id: config_base.t,v 1.8 2003/04/30 04:07:20 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use OpenInteract2::Constants qw( BASE_CONF_DIR BASE_CONF_FILE );
use Test::More  tests => 31;

require_ok( 'OpenInteract2::Config::Base' );

initialize_context();

{
    my $dir = '/path/to/mysite';
    my $filename = OpenInteract2::Config::Base
                                   ->create_filename( $dir );
    is( $filename, File::Spec->catfile( $dir, 'base.conf' ),
        'Create default filename' );
    my $web_filename = OpenInteract2::Config::Base
                                   ->create_website_filename( $dir );
    is( $web_filename, File::Spec->catfile( $dir, 'conf', 'base.conf' ),
        'Create default website filename' );

}


my $website_dir  = get_test_site_dir();
my $config_type  = 'ini';
my $config_class = 'OpenInteract2::Config::IniFile';
my $config_dir   = 'conf';
my $config_file  = 'server.ini';
my $package_dir  = 'pkg';
my $temp_lib_dir = 'tmplib';
my $existing_file = File::Spec->catfile( $website_dir,
                                         'conf', 'base.conf' );
rename( $existing_file, "$existing_file.bak" );

# Create a new config

{
    my $c = eval { OpenInteract2::Config::Base->new() };
    ok( ! $@,
        'Created empty object' );
    is( $c->website_dir( $website_dir ), $website_dir,
        'Website dir set' );
    is( $c->config_type( $config_type ), $config_type,
        'Config type set' );
    is( $c->config_class( $config_class ), $config_class,
        'Config class set' );
    is( $c->config_dir( $config_dir ), $config_dir,
        'Config subdir set' );
    is( $c->config_file( $config_file ), $config_file,
        'Config filename set' );
    is( $c->package_dir( $package_dir ), $package_dir,
        'Package dir set' );
    is( $c->temp_lib_dir( $temp_lib_dir ), $temp_lib_dir,
        'Temp library dir set' );

    my $wrote_file = eval { $c->save_config() };
    ok( ! $@,
        'Config file write to default execute' );
    is( $wrote_file, $existing_file,
        'Correct filename for saved config' );
    ok( -f $wrote_file,
        'File written exists' );

    # Remove a required field and try to save again...

    $c->config_dir( '' );
    eval { $c->save_config() };
    like( "$@", qr/^Cannot save base config: the following fields/,
          'Expected error when required field removed' );
    $c->config_dir( $config_dir );

    unlink( $wrote_file );
    rename( "$existing_file.bak", $existing_file );

    my $temp_wrote_file = get_use_file( 'base.conf', 'name' );
    $c->filename( $temp_wrote_file );
    my $wrote_file_spec = eval { $c->save_config() };
    ok( ! $@,
        'Config file write to specified execute' );
    is( $wrote_file_spec, $temp_wrote_file,
        'Correct filename for saved config' );
    ok( -f $wrote_file_spec,
        'File written exists' );
    unlink( $temp_wrote_file );
}


# Read an existing config using the 'website_dir' method

{
    my $c = eval {
        OpenInteract2::Config::Base->new({ website_dir => $website_dir })
    };
    ok( ! $@, 'Object created from website dir' );
    is( $c->website_dir(), $website_dir,
        'Website dir read' );
    is( $c->config_type(), $config_type,
        'Config type read' );
    is( $c->config_class(), $config_class,
        'Config class read' );
    is( $c->config_dir(),  $config_dir,
        'Config dir read' );
    is( $c->config_file(),  $config_file,
        'Config file read' );
    is( $c->package_dir(),  $package_dir,
        'Package  dir read' );
    is( $c->temp_lib_dir(),  $temp_lib_dir,
        'Temporary library dir read' );
    is( $c->filename(), $existing_file,
        'Filename set' );
}

# Read an existing config using the 'filename' method, then save it to
# a separate file

{
    my $c = eval {
        OpenInteract2::Config::Base->new({ filename => $existing_file });
    };
    ok( ! $@,
        'Object created from filename' );
    is( $c->website_dir(), $website_dir,
        'Website dir set at initialization' );
    my $new_file = $existing_file;
    $new_file =~ s/\.conf$/-alt.conf/;
    $c->filename( $new_file );
    my $wrote_file = eval { $c->save_config };
    ok ( ! $@,
         'Alternate config file written' );
    is( $wrote_file, $new_file,
        'Correct alternate filename saved' );
    unlink( $new_file );
}
