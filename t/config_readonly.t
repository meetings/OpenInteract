# -*-perl-*-

# $Id: config_readonly.t,v 1.2 2003/04/13 00:19:03 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use File::Copy qw( cp );
use Test::More  tests => 12;

require_ok( 'OpenInteract2::Config::Readonly' );

my $use_dir  = get_use_dir();

# Copy our test data to the right name
cp( get_use_file( 'test_no_overwrite', 'name' ),
    get_use_file( '.no_overwrite', 'name' ) );

# Check reading the file

my $readonly = OpenInteract2::Config::Readonly->read_config( $use_dir );
is( scalar @{ $readonly }, 2, 'Number of readonly entries' );
is( $readonly->[0], 'test_file.pdf', 'Readonly entry 1' );
is( $readonly->[1], 'test_file.gif', 'Readonly entry 2' );

# Check is_writeable_file against the list and directory

my $write_enum_nok = OpenInteract2::Config::Readonly
                         ->is_writeable_file( $readonly, 'test_file.pdf' );
my $write_dir_nok = OpenInteract2::Config::Readonly
                         ->is_writeable_file( $use_dir, 'test_file.pdf' );
my $write_enum_ok = OpenInteract2::Config::Readonly
                         ->is_writeable_file( $readonly, 'test_nonexist.pdf' );
my $write_dir_ok = OpenInteract2::Config::Readonly
                         ->is_writeable_file( $use_dir, 'test_nonexist.pdf' );
ok( ! $write_enum_nok, "Marked readonly file from list" );
ok( ! $write_dir_nok, "Marked readonly file from dir" );
ok( $write_enum_ok, "Not marked readonly file from list" );
ok( $write_dir_ok, "Not marked readonly file from dir" );

# Check get_writeable_files against files in t/ using listing and $dir

opendir( USEDIR, $use_dir );
my @test_files = grep { -f File::Spec->catfile( $use_dir, $_ ) }
                        readdir( USEDIR );
my $writeable_enum = OpenInteract2::Config::Readonly
                         ->get_writeable_files( $readonly, \@test_files );
my $writeable_dir = OpenInteract2::Config::Readonly
                         ->get_writeable_files( $use_dir, \@test_files );
is( scalar @{ $writeable_enum }, scalar( @test_files ) - 2, "Number of writeable files from list" );
is( scalar @{ $writeable_dir }, scalar( @test_files ) - 2, "Number of writeable files from dir" );
unlink( get_use_file( '.no_overwrite' ) );

# Check writing a config

my $file_written = eval {
    OpenInteract2::Config::Readonly
                         ->write_config( $use_dir, [ 'file_a.txt', 'file_b.txt' ] )
};
ok( ! $@, 'Readonly listing written to file' );
my $read_written = get_use_file( '.no_overwrite', 'content' );
is( $read_written, "file_a.txt\nfile_b.txt", 'Written readonly listing matches' );
unlink( get_use_file( '.no_overwrite' ) );
