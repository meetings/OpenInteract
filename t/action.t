# -*-perl-*-

# $Id: action.t,v 1.13 2003/07/01 17:15:36 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use SPOPS::Secure qw( :level );
use Test::More  tests => 66;

require_ok( 'OpenInteract2::Action' );

# Create an empty object, check properties and parameters

my $empty = eval { OpenInteract2::Action->new() };
ok( ! $@, "Empty action object created" );
is( ref $empty, 'OpenInteract2::Action',
    '...of the right class' );
is( $empty->name, undef,
    "...has empty name" );
is( $empty->url, undef,
    "...has empty url" );

ok( $empty->property_assign({ task => 'foo', class => 'Foo::Bar' }),
    '...assigned multiple properties' );
is( $empty->task, 'foo',
    '...got value for "task"' );
is( $empty->class, 'Foo::Bar',
    '...got value for "class"' );
ok( $empty->property( method => 'baz' ),
    '...set single property()' );
is( $empty->method, 'baz',
    '...got proper value from accessor' );
is( $empty->property( 'method' ), 'baz',
    '...got same value from property()' );
is( $empty->property_clear( 'method' ), 'baz',
    '...clear property returns old property' );
is( $empty->method, undef,
    '...property method call is cleared' );
is( $empty->property( 'method' ), undef,
    '...value from property() call is cleared' );

ok( $empty->param_assign({ username => 'mario', position => 'center' }),
    '...assigned multiple params' );
is( $empty->param( 'username' ), 'mario',
    '...got value for "username"' );
is( $empty->param( 'position' ), 'center',
    '...got value for "position"' );
ok( $empty->param( city => 'Pittsburgh' ),
    '...set single param' );
is( $empty->param( 'city' ), 'Pittsburgh',
    '...got param from single set' );
ok( $empty->param( city => 'Ottumwa' ),
    '...overwrite single param' );
is( $empty->param( 'city' ), 'Ottumwa',
    '...got overwriting single param' );

ok( $empty->param_add( city => 'Des Moines' ),
    '...add single value to exiting key' );
ok( $empty->param_add( city => 'Buffalo', 'Boulder' ),
    '...add multiple values to existing key' );
my @cities_a = $empty->param( 'city' );
is( scalar @cities_a, 4,
    '...got correct number of entries from multiple param (list context)' );
is( $cities_a[0], 'Ottumwa',
    '...got first of multiple param (list context)' );
is( $cities_a[3], 'Boulder',
    '...got last of multiple param (list context)' );
my $cities_s = $empty->param( 'city' );
is( scalar @{ $cities_s }, 4,
    '...got correct number of entries from multiple param (scalar context)' );
is( $cities_s->[1],  'Des Moines',
    '...got second of multiple param (scalar context)' );
is( $cities_s->[2], 'Buffalo',
    '...got third of multiple param (scalar context)' );

ok( $empty->param_add( rock => 'granite', 'gneiss' ),
    '...add multiple values to new key' );
my @rocks = $empty->param( 'rock' );
is( scalar @rocks, 2,
    '...got correct number of values from new key (list context)' );
is( scalar @{ $empty->param( 'rock' ) }, 2,
    '...got correct number of values from new key (scalar context)' );

is( $empty->param_clear( 'position' ), 'center',
    '...clear single param returns old value' );
is( $empty->param( 'position' ), undef,
    '...single param is cleared' );
ok( $empty->param_clear( 'city' ),
    '...clear multiple param values' );
is( $empty->param( 'city' ), undef,
    '...multiple param values are cleared' );

# is_secure is special

ok( $empty->is_secure( 'yes' ),
    '...set is_secure (true) via mutator' );
is( $empty->is_secure, 1,
    '...got is_secure (true) via accessor' );
ok( ! $empty->is_secure( 'no' ),
    '...set is_secure (false) via mutator' );
is( $empty->is_secure, 0,
    '...got is_secure (false) via accessor' );

# Create a non-named object with parameters and properties, check

my $empty_p = eval {
    OpenInteract2::Action->new( undef,
                                { task     => 'foo',
                                  method   => 'bar',
                                  username => 'mario',
                                  city     => 'Pittsburgh' } );
};
ok( ! $@, 'Create action with no info but props/params' );
is( ref $empty_p, 'OpenInteract2::Action',
    '...of the right class' );
is( $empty_p->task, 'foo',
    '...got property "task"' );
is( $empty_p->method, 'bar',
    '...got property "method"' );
is( $empty_p->param( 'username' ), 'mario',
    '...got param "username"' );
is( $empty_p->param( 'city' ), 'Pittsburgh',
    '...got param "city"' );

my $CTX = initialize_context();

# Create a named action and check properties/parameters

my $named = eval { OpenInteract2::Action->new( 'page' ) };
ok( ! $@, "Created named action" );
is( ref $named, 'OpenInteract2::Action::Page',
    '...of the right class' );
is( $named->is_secure, 1,
    '...is_secure property set' );
is( $named->task_default, 'display',
    '...task_default proeprty set' );
my %named_security = ( DEFAULT => SEC_LEVEL_WRITE,
                       display => SEC_LEVEL_NONE,
                       help    => SEC_LEVEL_NONE,
                       notify  => SEC_LEVEL_READ );
is_deeply( $named->security, \%named_security,
           '...all task security levels set' );
is( $named->content_generator, 'TT',
    '...default property content_generator set' );
is( $named->controller, 'tt-template',
    '...default property controller set' );

# Create a named action with properties/parameters; check URLs

my $named_p = eval {
    OpenInteract2::Action->new( 'file_index',
                                { is_secure   => 'yes',
                                  index_files => [ 'foo.html', 'bar.html' ] } )
};
ok( ! $@, "Created named action with properties/parameters" );
is( $named_p->is_secure, 1,
    '...got property overwriting' );
is( scalar @{ $named_p->param( 'index_files' ) }, 2,
    '...got param overwriting' );

is( $named->create_url, '/page/',
    '...got named action URL (default)' );
is( $named->create_url({ TASK => 'run' }), '/page/run/',
    '...got named action URL with TASK' );
is( $named->create_url({ foo => 'bar' }), '/page/?foo=bar',
    '...got named action URL with param' );
is( $named->create_url({ TASK => 'run', foo => 'bar' }), '/page/run/?foo=bar',
    '...got named action URL with TASK and param' );
my %m_param = ( foo  => 'bar', soda => 'coke' );
my $m_url = $named->create_url({ TASK => 'run', %m_param });
compare_urls( '/page/run/', \%m_param, $m_url,
              'URL with TASK and multiple params' );
$named->task( 'run' );
is( $named->create_url, '/page/run/',
    '...got named action URL with task set' );
is( $named->create_url({ TASK => undef }), '/page/',
    '...got named action URL with empty TASK overriding' );
$named->property_clear( 'task' );

initialize_request({ url => '/Fake/action/' });

$CTX->request->param( batman => 'Bruce Wayne' );
$named->param_from_request( 'batman' );
is( $named->param( 'batman' ), 'Bruce Wayne',
    '...got parameter from request' );

$CTX->request->param( enemies => [ 'Joker', 'Two-face', 'Clayface' ] );
$named->param_from_request( 'enemies' );
my @enemies = $named->param( 'enemies' );
is( scalar @enemies, 3,
    '...got multivalued parameter request' );

# TODO (::Common related stuff)
# - Create an object with one of the ::Common* parents
# - See that the defaults from init() are set

# - Methods/services:

#   execute()

#    (wraps up find_task(), find_security_level(), check_security(),
#     check task validity(), find_task_method())
#    - Set security level manually to something that won't work
#    and ensure we get an execption
#    - Set 'task' to something invalid and ensure we get an exception
#    - Set 'task' to something valid but nonexistent and ensure we
#    get an exception.
#    - Run and ensure we get the right content back.
#    - Run again and this time pass in properties/parameters and
#    ensure they're set
#    - Call 'generate_content' with known parameters and ensure we get
#    the right content back

#  caching
#    - Set cache to be active, run 'generate_content' and see that a
#    cache document was created
#    - Run 'generate_content' again with different parameters and
#    ensure we get the same document back (put a parameter dependency
#    in there)
#    - Clear the cache
#    - Modify cache settings to depend on a parameter
#    - Run 'generate_content' and see that a cache document was
#    created
#    - Run 'generate_content' with a different parameter and see that
#    we get a different document back; also see that a new cache
#    document was created


# TODO:
#  Once we get action types up:
# - Create object of a particular type
# - Check that it's the right class

