# -*-perl-*-

# $Id: config_ini.t,v 1.14 2003/12/15 04:11:04 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 31;

require_ok( 'OpenInteract2::Config::Ini' );

my $test_config = <<'TEST';
[Global]
sub1 = val1

[head1]
sub1 = val1
sub1 = val2

[head2]
sub1 = val1
sub2 = this is a longer value with a \
line continuation

[head3 child]
sub1 = val1
sub1 = val2
sub2 = val3
TEST

{
    my $conf = eval {
        OpenInteract2::Config::Ini->new({ content => $test_config } )
    };
    ok( ! $@, "Object created (content)" );
    is( ref( $conf ), 'OpenInteract2::Config::Ini',
        'Correct object type created (content)' );
    is( $conf->{sub1}, 'val1',
        'Global value read in correctly (content)' );
    is( $conf->{head2}{sub1}, 'val1',
        'Sub value scalar read in correctly (content)' );
    is( $conf->{head2}{sub2}, 'this is a longer value with a line continuation',
        'Sub value scalar with line continuations read in correctly (content)' );
    is( $conf->{head1}{sub1}[0], 'val1',
        'Sub value array read in correctly (content)' );
    is( $conf->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar read in correctly (content)' );
    is( $conf->{head3}{child}{sub1}[0], 'val1',
        'Nested sub value array read in correctly (content)' );

    my $conf_data = $conf->as_data;
    is( ref( $conf_data ), 'HASH',
        'Correct data type returned from as_data()' );
    is( $conf_data->{sub1}, 'val1',
        'Global value in as_data() correctly (content)' );
    is( $conf_data->{head2}{sub1}, 'val1',
        'Sub value scalar in as_data() correctly (content)' );
    is( $conf_data->{head2}{sub2}, 'this is a longer value with a line continuation',
        'Sub value scalar with line continuations in as_data() correctly (content)' );
    is( $conf_data->{head1}{sub1}[0], 'val1',
        'Sub value array in as_data() correctly (content)' );
    is( $conf_data->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar in as_data() correctly (content)' );
    is( $conf_data->{head3}{child}{sub1}[0], 'val1',
        'Nested sub value array in as_data() correctly (content)' );
}

{
    my $config_file = get_use_file( 'test_config.ini', 'name' );
    my $conf = eval {
        OpenInteract2::Config::Ini->new({ filename => $config_file } )
    };
    ok( ! $@, "Object created (file)" );
    is( ref( $conf ), 'OpenInteract2::Config::Ini',
        'Correct object type created (file)' );
    is( $conf->{sub1}, 'val1',
        'Global value read in correctly (file)' );
    is( $conf->{head2}{sub1}, 'val1',
        'Sub value scalar read in correctly (file)' );
    is( $conf->{head2}{sub2}, 'this is a longer value with a line continuation',
        'Sub value scalar with line continuations read in correctly (file)' );
    is( $conf->{head1}{sub1}[0], 'val1',
        'Sub value array read in correctly (file)' );
    is( $conf->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar read in correctly (file)' );
    is( $conf->{head3}{child}{sub1}[0], 'val1',
        'Nested sub value array read in correctly (file)' );

    my $conf_data = $conf->as_data;
    is( ref( $conf_data ), 'HASH',
        'Correct data type returned from as_data() (file)' );
    is( $conf_data->{sub1}, 'val1',
        'Global value in as_data() correctly (file)' );
    is( $conf_data->{head2}{sub1}, 'val1',
        'Sub value scalar in as_data() correctly (file)' );
    is( $conf->{head2}{sub2}, 'this is a longer value with a line continuation',
        'Sub value scalar with line continuations in as_data() correctly (file)' );
    is( $conf_data->{head1}{sub1}[0], 'val1',
        'Sub value array in as_data() correctly (file)' );
    is( $conf_data->{head3}{child}{sub2}, 'val3',
        'Nested sub value scalar in as_data() correctly (file)' );
    is( $conf_data->{head3}{child}{sub1}[0], 'val1',
        'Nested sub value array in as_data() correctly (file)' );
}

