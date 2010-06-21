package OpenInteract2::Brick::PackageCPAN;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'Makefile.PL' => 'MAKEFILEPL',
    'Brick.pm' => 'BRICKPM',
    'module_include.t' => 'MODULE_INCLUDET',
);

sub get_name {
    return 'package_cpan';
}

sub get_resources {
    return (
        'Makefile.PL' => [ 'Makefile.PL', 'yes' ],
        'Brick.pm' => [ 'lib OpenInteract2 Brick [% subclass %].pm', 'yes' ],
        'module_include.t' => [ 't 00_basic_include.t ', 'yes' ],
    );
}

sub load {
    my ( $self, $resource_name ) = @_;
    my $inline_sub_name = $INLINED_SUBS{ $resource_name };
    unless ( $inline_sub_name ) {
        OpenInteract2::Exception->throw(
            "Resource name '$resource_name' not found ",
            "in ", ref( $self ), "; cannot load content." );
    }
    return $self->$inline_sub_name();
}

OpenInteract2::Brick->register_factory_type( get_name() => __PACKAGE__ );

=pod

=head1 NAME

OpenInteract2::Brick::PackageCPAN - All resources used for creating a CPAN distribution from a package

=head1 SYNOPSIS

  oi2_manage create_cpan --package_dir=/path/to/mypackage

=head1 DESCRIPTION

This class just holds all the static resources used when creating a CPAN distribution from a package.

These resources are associated with OpenInteract2 version 1.99_06.

=head2 Resources

You can grab resources individually using the names below and
C<load_resource()> and C<copy_resources_to()>, or you can copy all the
resources at once using C<copy_all_resources_to()> -- see
L<OpenInteract2::Brick> for details.

=over 4


=item B<Makefile.PL>

=item B<Brick.pm>

=item B<module_include.t>


=back

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS


Chris Winters E<lt>chris@cwinters.comE<gt>


=cut


sub MAKEFILEPL {
    return <<'SOMELONGSTRING';
use ExtUtils::MakeMaker;

my %opts = (
    'NAME'	       => '[% full_app_class %]',
    'VERSION'      => '[% package_version %]',
    'PL_FILES'     => {},
    'NO_META'      => 1,
    'PREREQ_PM'    => {
        'OpenInteract2::Action' => 1.66,   # proxy for OI2
[% FOREACH module = required_modules -%]
        [% module %] => 0,
[% END -%]
    },
);

if ( $ExtUtils::MakeMaker::VERSION >= 5.43 ) {
    $opts{AUTHOR}   = '[% author_names.join( ', ' ) %]',
    $opts{ABSTRACT} = q{[% abstract %]},
}

WriteMakefile( %opts );

SOMELONGSTRING
}

sub BRICKPM {
    return <<'SOMELONGSTRING';
package [% full_brick_class %];

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
[% FOREACH file_info = package_files -%]
    '[% file_info.name %]' => '[% file_info.inline_name %]',
[% END -%]
);

sub get_name {
    return '[% package_name %]';
}

sub get_resources {
    return (
[% FOREACH file_info = package_files -%]
        '[% file_info.name %]' => [ '[% file_info.destination %]', '[% file_info.evaluate %]' ],
[% END -%]
    );
}

sub load {
    my ( $self, $resource_name ) = @_;
    my $inline_sub_name = $INLINED_SUBS{ $resource_name };
    unless ( $inline_sub_name ) {
        OpenInteract2::Exception->throw(
            "Resource name '$resource_name' not found ",
            "in ", ref( $self ), "; cannot load content." );
    }
    return $self->$inline_sub_name();
}

OpenInteract2::Brick->register_factory_type( get_name() => __PACKAGE__ );

=pod

=head1 NAME

[% full_brick_class %] - Installation data for OpenInteract2 package '[% package_name %]'

=head1 SYNOPSIS

 oi2_manage install_package --package=[% package_name %]

=head1 DESCRIPTION

You generally don't use this class directly. See the docs for
L<[% full_app_class %]> and L<OpenInteract2::Brick> for more.

=head1 SEE ALSO

L<[% full_app_class %]>

=head1 COPYRIGHT

Copyright (c) 2005 [% author_names.join( ', ' ) %]. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

[% FOREACH author_info = authors %]
[% author_info.name %] E<lt>[% author_info.email %]E<gt>
[% END %]

=cut

[% FOREACH file_info = package_files %]
sub [% file_info.inline_name %] {
    return <<'SUPERLONGSTRING';
[% file_info.contents %]
SUPERLONGSTRING
}

[% END %]


SOMELONGSTRING
}

sub MODULE_INCLUDET {
    return <<'SOMELONGSTRING';
# -*-perl-*-

use strict;
use Test::More tests => [% package_modules.size + 2 %];

require_ok( '[% full_app_class %]' );
require_ok( '[% full_brick_class %]' );
[% FOREACH module = package_modules.sort -%]
require_ok( '[% module %]' );
[% END -%]


SOMELONGSTRING
}

