# -*-perl-*-

# $Id: exception.t,v 1.5 2003/04/27 04:42:02 lachoy Exp $

use strict;
use lib 't/';
require 'utils.pl';
use Test::More  tests => 69;

BEGIN { use_ok( 'OpenInteract2::Exception', qw( oi_error ) ) }

# Test normal base exception

{
    my $e_message = 'Error fetching object';
    my $e_package = 'base_user';
    eval { OpenInteract2::Exception->throw( $e_message ) };
    my $e = $@;
    is( ref $e, 'OpenInteract2::Exception',
        'Base object creation' );
    is( $e->message(), $e_message,
        'Base message creation' );
    ok( $e->package(),
        'Base package set' );
    ok( $e->filename(),
        'Base filename set' );
    ok( $e->line(),
        'Base line number set' );
    ok( $e->method(),
        'Base method set' );

    ok( $e->oi_package( $e_package ),
        'Base OI package set' );
    is( $e->oi_package(), $e_package,
        'Base OI package returned' );

    is( ref( $e->trace() ), 'Devel::StackTrace',
        'Base trace set' );
    is( "$e", $e_message,
        'Base $@ stringified' );
    my @stack = $e->get_stack();
    is( scalar @stack, 1,
        'Base tack set' );
}

# Test the imported method
{
    my $e_message = "Error fetching object";
    my $e_package = 'base_user';
    eval { oi_error $e_message  };
    my $e = $@;
    is( ref $e, 'OpenInteract2::Exception',
        'Shortcut object creation' );
    is( $e->message(), $e_message,
        'Shortcut message creation' );
    ok( $e->package(),
        'Shortcut package set' );
    ok( $e->filename(),
        'Shortcut filename set' );
    ok( $e->line(),
        'Shortcut line number set' );
    ok( $e->method(),
        'Shortcut method set' );

    ok( $e->oi_package( $e_package ),
        'Shortcut OI package set' );
    is( $e->oi_package(), $e_package,
        'Shortcut OI package returned' );

    is( ref( $e->trace() ),
        'Devel::StackTrace',
        'Shortcut trace set' );
    is( "$e", $e_message,
        'Shortcut $@ stringified' );
    my @stack = $e->get_stack();
    is( scalar @stack, 2,
        'Shortcut stack set' );
}

# Test the security exception

{
    require_ok( 'OpenInteract2::Exception::Security' );
    my $s_message = 'Security restrictions violated';
    my $s_package = 'news';
    eval { OpenInteract2::Exception::Security->throw( $s_message ) };
    my $s = $@;

    is( ref $s, 'OpenInteract2::Exception::Security',
        'Security object creation' );
    is( $s->message(), $s_message,
        'Security message creation' );
    ok( $s->package(),
        'Security package set' );
    ok( $s->filename(),
        'Security filename set' );
    ok( $s->line(),
        'Security line number set' );
    ok( $s->method(),
        'Security method set' );

    ok( $s->oi_package( $s_package ),
        'Security OI package set' );
    is( $s->oi_package(), $s_package,
        'Security OI package returned' );

    ok( $s->security_required( 4 ),
        'Security required set' );
    ok( $s->security_found( 1 ),
        'Security found set' );
    is( $s->security_required(), 4,
        'Security required returned'  );
    is( $s->security_found(), 1,
        'Security found returned'  );

    is( ref( $s->trace() ), 'Devel::StackTrace',
        'Trace set' );
    my $stringified = "Security violation. Object requires [READ] but got [NONE]";
    is( "$s", $stringified,
        'Security $@ stringified' );
    my @stack = $s->get_stack();
    is( scalar @stack, 3,
        'Stack set' );
}

# Test the datasource exception

{
    require_ok( 'OpenInteract2::Exception::Datasource' );
    my $d_message = 'Connect failed: invalid password for oiuser';
    my $d_package = 'base';
    my $d_name    = 'main';
    my $d_type    = 'DBI';
    my $d_connect = 'DBI:Pg:dbname=test;oiuser;oipass';

    eval { OpenInteract2::Exception::Datasource->throw( $d_message ) };
    my $d = $@;
    is( ref $d, 'OpenInteract2::Exception::Datasource',
        'Datasource object creation' );
    is( $d->message(), $d_message,
        'Datasource message creation' );
    ok( $d->package(),
        'Datasource package set' );
    ok( $d->filename(),
        'Datasource filename set' );
    ok( $d->line(),
        'Datasource line number set' );
    ok( $d->method(),
        'Datasource method set' );

    ok( $d->oi_package( $d_package ),
        'Datasource OI package set' );
    is( $d->oi_package(), $d_package,
        'Datasource OI package returned' );

    ok( $d->datasource_name( $d_name ),
        'Datasource name set' );
    ok( $d->datasource_type( $d_type ),
        'Datasource type set' );
    ok( $d->connect_params( $d_connect ),
        'Datasource connection params set' );;
    is( $d->datasource_name(), $d_name,
        'Datasource name returned'  );
    is( $d->datasource_type(), $d_type,
        'Datasource type returned'  );
    is( $d->connect_params(), $d_connect,
        'Datasource connection params returned' );

    is( ref( $d->trace() ), 'Devel::StackTrace',
        'Trace set' );
    is( "$d", $d_message,
        'Datasource $@ stringified' );
    my @stack = $d->get_stack();
    is( scalar @stack, 4,
        'Stack set' );
}

# Test the application exception

{
    require_ok( 'OpenInteract2::Exception::Application' );
    my $a_message = 'Please ensure you fill in the "title" field';
    my $a_package = 'custom';
    eval { OpenInteract2::Exception::Application->throw( $a_message ) };
    my $a = $@;

    is( ref $a, 'OpenInteract2::Exception::Application',
        'Application object creation' );
    is( $a->message(), $a_message,
        'Application message creation' );
    ok( $a->package(),
        'Application package set' );
    ok( $a->filename(),
        'Application filename set' );
    ok( $a->line(),
        'Application line number set' );
    ok( $a->method(),
        'Application method set' );

    ok( $a->oi_package( $a_package ),
        'Application OI package set' );
    is( $a->oi_package(), $a_package,
        'Application OI package returned' );

    is( ref( $a->trace() ), 'Devel::StackTrace',
        'Trace set' );
    is( "$a", $a_message,
        '$@ stringified' );
    my @stack = $a->get_stack();
    is( scalar @stack, 5,
        'Stack set' );
}
