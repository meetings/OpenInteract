# -*-perl-*-

# $Id: package.t,v 1.7 2003/04/26 17:00:19 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use File::Copy qw( cp );
use Test::More  tests => 70;

require_ok( 'OpenInteract2::Package' );

my $original_pwd = get_current_dir();

END {
    chdir( $original_pwd );
}

my $package_empty = eval { OpenInteract2::Package->new() };
ok( ! $@, 'Create object with empty constructor' );

my $package_file = get_use_file( 'fruit-1.00.zip', 'name' );
my $package_dir  = get_test_package_dir();

my $f_package = eval {
    OpenInteract2::Package->new({ package_file => $package_file })
};
ok( ! $@,
    'Create object with package file in constructor' );
is( $f_package->package_file, $package_file,
    'Package file name set' );
is( $f_package->name, 'fruit',
    'Package name read from file' );
is( $f_package->version, '1.00',
    'Package version read from file' );
is( ref( $f_package->config ), 'OpenInteract2::Config::Package',
    'Package config object set' );

my $d_package = eval {
    OpenInteract2::Package->new({ directory => $package_dir })
};
ok( ! $@,
    'Create object with package directory in constructor' );
is( $d_package->directory, $package_dir,
    'Package directory name set' );
is( $d_package->name, 'fruit',
    'Package name read from file' );
is( $d_package->version, '1.00',
    'Package version read from file' );
is( ref( $d_package->config ), 'OpenInteract2::Config::Package',
    'Package config object set' );

########################################
# EXPORT

eval { $package_empty->export };
like( "$@", qr/^Package must have valid directory/,
      'Expected export error with empty package' );

my $tmp_dir = get_tmp_dir();
chdir( $tmp_dir );
my $expected_zipfile = File::Spec->catfile( $tmp_dir, 'fruit-1.00.zip' );

# if left over from old run...
if ( -f $expected_zipfile ) {
    unlink( $expected_zipfile );
}

my $export_filename = eval { $d_package->export };
ok( ! $@,
    'Export execution' );
is( $export_filename, $expected_zipfile,
    'Export to correct filename' );

# Open up a bad configuration, assign it to the package and ensure
# that the export fails

my $bad_config_file = get_use_file( 'test_package_bad.conf', 'name' );
my $bad_config = OpenInteract2::Config::Package->new(
                         { filename => $bad_config_file });
my $good_config = $d_package->config;
$d_package->config( $bad_config );
eval { $d_package->export };
like( "$@", qr/^Required fields check failed/,
      "Expected export error with bad package configuration" );
$d_package->config( $good_config );

# Rename package file and ensure that the export fails

my $move_file = File::Spec->catfile( $package_dir, 'Changes' );
rename( $move_file, "$move_file.bak" );
eval { $d_package->export };
like( "$@", qr/^Files in MANIFEST not found in package\:/,
      'Expected export error with package file removal' );
rename( "$move_file.bak", $move_file );

# Make the directory that export uses to expand the file and
# see if we get the right error

my $expand_dir = File::Spec->catdir( get_current_dir(), 'fruit-1.00' );
mkdir( $expand_dir, 0777 );
eval { $d_package->export };
like( "$@", qr/^Directory \[$expand_dir\] already exists/,
      'Expected export error where export dir exists' );
rmdir( $expand_dir );

# Do another export and get the expected error that the file
# is already there

eval { $d_package->export };
like( "$@", qr/^Cannot create ZIP archive/,
      'Expected export error where export file exists' );

# Cleanup

unlink( $export_filename );


########################################
# CHECK

my $check_pwd = get_current_dir();

eval { $package_empty->check };
like( "$@", qr/^Package must have valid directory set/,
      "Expected error checking empty package" );
is( get_current_dir(), $check_pwd,
    'Still in correct directory after empty check' );

my @check_status = eval { $d_package->check };
ok( ! $@,
    'Package check execution' );
is( get_current_dir(), $check_pwd,
    'Still in correct directory after check' );

# cycle through status entries, checking each...
is( scalar @check_status, 12,
    'Correct number of status entries' );

my $i = -1;
is( $check_status[++$i]->{action}, 'Changelog check',
    'Action: Changelog check' );
is( $check_status[$i]->{is_ok}, 'yes',
    'Changelog exists' );

is( $check_status[++$i]->{action}, 'Files missing from MANIFEST',
    'Action: MANIFEST consistency check' );
is( $check_status[$i]->{is_ok}, 'yes',
    'All files in MANIFEST in package' );

is( $check_status[++$i]->{action}, 'Extra files not in MANIFEST',
    'Action: MANIFEST extra file check' );
is( $check_status[$i]->{is_ok}, 'yes',
    'No extra files in package' );

is( $check_status[++$i]->{action}, 'Config required fields',
    'Action: Package config requirements check' );
is( $check_status[$i]->{is_ok}, 'yes',
    'Package config has all required fields' );

is( $check_status[++$i]->{action}, 'Config defined modules',
    'Action: Package config modules check' );
is( $check_status[$i]->{is_ok}, 'yes',
    'System has all modules required by package config' );

is( $check_status[++$i]->{action}, 'Check ini file',
    'Action: Action INI file check' );
is( $check_status[$i]->{filename}, 'conf/action.ini',
    'Filename set to action config' );
is( $check_status[$i]->{is_ok}, 'yes',
    'Action INI file exists and parseable' );

is( $check_status[++$i]->{action}, 'Check ini file',
    'Action: SPOPS INI file check' );
is( $check_status[$i]->{filename}, 'conf/spops.ini',
    'Filename set to SPOPS config' );
is( $check_status[$i]->{is_ok}, 'yes',
    'SPOPS INI file exists and parseable' );

is( $check_status[++$i]->{action}, 'Check module',
    'Action: Action module check' );
is( $check_status[$i]->{filename}, 'OpenInteract2/Action/Fruit.pm',
    'Filename set to action module' );
is( $check_status[$i]->{is_ok}, 'yes',
    'Action module exists and has no Perl syntax errors' );

is( $check_status[++$i]->{action}, 'Check module',
    'Action: SQL installer module check' );
is( $check_status[$i]->{filename}, 'OpenInteract2/SQLInstall/Fruit.pm',
    'Filename set to SQL installer module' );
is( $check_status[$i]->{is_ok}, 'yes',
    'SQL installer module exists and has no Perl syntax errors' );

is( $check_status[++$i]->{action}, 'Check data file',
    'Action: initial data syntax check' );
is( $check_status[$i]->{filename}, 'data/fruit-initial-data.dat',
    'Filename set to initial data file' );
is( $check_status[$i]->{is_ok}, 'yes',
    'Initial data file exists and has no Perl syntax errors' );

is( $check_status[++$i]->{action}, 'Check data file',
    'Action: security data syntax check' );
is( $check_status[$i]->{filename}, 'data/install_security.dat',
    'Filename set to security data file' );
is( $check_status[$i]->{is_ok}, 'yes',
    'Security data file exists and has no Perl syntax errors' );

is( $check_status[++$i]->{action}, 'Template check',
    'Action: template syntax check' );
is( $check_status[$i]->{filename}, 'template/fruit-display.tmpl',
    'Filename set to template file' );
is( $check_status[$i]->{is_ok}, 'yes',
    'Template file exists and has no TT syntax errors' );

# Copy a file into the distribution and check manifest status
# for extra files

my $copy_src  = $package_file;
my $copy_dest = File::Spec->catfile( $package_dir,
                                     'fruit-1.00.zip' );
cp( $copy_src, $copy_dest );
my @ex_check_status = eval { $d_package->check };
ok( ! $@,
    'Package check execution with extra file' );
is( scalar @ex_check_status, 12,
    'Correct number of status entries with extra file' );
is( $ex_check_status[2]->{is_ok}, 'no',
    'Extra file check properly failed' );
is( $ex_check_status[2]->{message}, 'Files not in MAIFEST found: fruit-1.00.zip',
    'Extra file properly identified' );
unlink( $copy_dest );

# Remove a file from the distribution and check manifest
# status for missing file

my $rename_src  = File::Spec->catfile( $package_dir, 'doc', 'fruit.pod' );
my $rename_dest = "$rename_src.bak";
rename( $rename_src, $rename_dest );
my @miss_check_status = eval { $d_package->check };
ok( ! $@,
    'Package check execution with missing file' );
is( scalar @miss_check_status, 12,
    'Correct number of status entries with missing file' );
is( $miss_check_status[1]->{is_ok}, 'no',
    'All files check properly failed' );
is( $miss_check_status[1]->{message}, 'Files not found from MANIFEST: doc/fruit.pod',
    'Missing file properly identified' );
rename( $rename_dest, $rename_src );

# Replace a perl module with a known bad one and check its status,
# first deleting the entry from @INC so we don't get a cached result

my $module_src = File::Spec->catfile( $package_dir, 'OpenInteract2',
                                      'SQLInstall', 'Fruit.pm' );
my $module_bak = "$module_src.bak";
my $bad_module_src = get_use_file( 'test_package_bad.pm', 'name' );
rename( $module_src, $module_bak );
cp( $bad_module_src, $module_src );
my @pm_check_status = eval { $d_package->check };
ok( ! $@,
    'Package check execution with bad module' );
is( scalar @pm_check_status, 12,
    'Correct number of status entries with bad module' );
is( $pm_check_status[8]->{is_ok}, 'no',
    'Module check properly failed' );
unlink( $module_src );
rename( $module_bak, $module_src );

# Replace a data file with a known bad one and check its
# status

my $data_src = File::Spec->catfile( $package_dir, 'data',
                                    'fruit-initial-data.dat' );
my $data_bak = "$data_src.bak";
my $bad_data_src = get_use_file( 'test_package_bad.dat', 'name' );
rename( $data_src, $data_bak );
cp( $bad_data_src, $data_src );
my @data_check_status = eval { $d_package->check };
ok( ! $@,
    'Package check execution with bad data file' );
is( scalar @data_check_status, 12,
    'Correct number of status entries with bad data file' );
is( $data_check_status[9]->{is_ok}, 'no',
    'Data file check properly failed' );
like( $data_check_status[9]->{message}, qr/Missing right curly or square bracket at/,
      "Correct syntax error identified" );
unlink( $data_src );
rename( $data_bak, $data_src );


# TODO: Replace a template file with a known bad one and check its
# status. We need to get the TT syntax checker working properly for
# this...

