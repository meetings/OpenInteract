package OpenInteract2::Brick::BaseError;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'base_error-3.02.zip' => 'BASE_ERROR302ZIP',
);

sub get_name {
    return 'base_error';
}

sub get_resources {
    return (
        'base_error-3.02.zip' => [ 'pkg base_error-3.02.zip', 'no' ],
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

OpenInteract2::Brick::BaseError - Base-64 encoded OI2 package 'base_error-3.02.zip' shipped with distribution

=head1 SYNOPSIS

  oi2_manage create_website --website_dir=/path/to/site

=head1 DESCRIPTION

Are you sure you even need to be reading this? If you are just looking
to install a package just follow the instructions from the SYNOPSIS.

Still here? This class holds the Base64-encoded versions of package
file "base_error-3.02.zip" shipped with OpenInteract2. Once you decode them you
should store them as a ZIP file and then read them in with
Archive::Zip or some other utility.

A typical means to do this is:

 my $brick = OpenInteract2::Brick->new( 'base_error' );

 # there's only one resource in this brick...
 my ( $pkg_name ) = $brick->list_resources;
 my $pkg_info = $brick->load_resource( $pkg_name );
 my $pkg_file = OpenInteract2::Util->decode_base64_and_store(
     \$pkg_info->{content}
 );

 # $pkg_file now references a file on the filesystem that you can
 # manipulate as normal

These resources are associated with OpenInteract2 version 1.99_06.


=head2 Resources

You can grab resources individually using the names below and
C<load_resource()> and C<copy_resources_to()>, or you can copy all the
resources at once using C<copy_all_resources_to()> -- see
L<OpenInteract2::Brick> for details.

=over 4


=item B<base_error-3.02.zip>


=back

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS


Chris Winters E<lt>chris@cwinters.comE<gt>


=cut


sub BASE_ERROR302ZIP {
    return <<'SOMELONGSTRING';
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
0jYp1f5lKX2bjErxkv/1F0tTwbGUpMa/hd481TUY5putpJL18iNh7RHX7zLkAXGVRYOB/geSUYRd
HxbOx+eEo650mJcoKCTRv6of6xCrFMFa5XRAfssgdVVNW5fXlgW9nJ/W0VF5alj8PUjfCvbKBluu
eLtDuzDCIb4n76KwmnVRuOGcoU3h8UKW6Jr8lGmKvAUtEIwKrvryDDNUjSML/XZZRaRXFqUWNsQ3
CV5d33NcRbnqpKosfWVxKKMJu6P+ux77WhXbTJKrpZf7/HDaMlOrzfLLLcE9ewhfse7LKMn/upSP
Mnf3qJMCw9u+HYri1galUDHBt1809dm0eOs8HNgKd6KbG+6wzjRdE0+X4Or85f9JklX4VCz5Lq3y
8P40QnL6bN4szmCTuXJDO8isHV6818n2xqzQ++fudrXessLD4NXc0afgK+at0v73g+4f1/4BUEsD
BBQAAAAIAESiXDINBQw7pgAAADUBAAAYAAAAYmFzZV9lcnJvci0zLjAyL01BTklGRVNUdY5LCgIx
DED3vYsteAOVEQb8IOO+xBpnim1amszC21s/oAy6zHvJI6sBqEdW28WuXTfdUWVwV+hRe/LKJboY
cOITPeczCBhPLBCCZXRj8XLTlarIvTkBo8VSUrERmWuEZ0i6KrXPSC0Jlhqbm8WzaJrHqs5xanM2
y5r6o7vDpn198AkIxhxA0JzBh5sNnkVLRV8CpaoJHFLECfpxGhPJUKsujfR2d1BLAQIUAxQAAAAI
ADW5cTKmf2WT4wAAAEMBAAAxAAAAAAAAAAEAAAAkgQAAAABiYXNlX2Vycm9yLTMuMDIvT3Blbklu
dGVyYWN0Mi9TUUxJbnN0YWxsL0Vycm9yLnBtUEsBAhQDFAAAAAgAWKRcMgFY5RTcAAAAVQEAABsA
AAAAAAAAAQAAACSBMgEAAGJhc2VfZXJyb3ItMy4wMi9wYWNrYWdlLmluaVBLAQIUAxQAAAAIAJkI
WDJs0KnXdwEAAAoHAAAkAAAAAAAAAAEAAAAkgUcCAABiYXNlX2Vycm9yLTMuMDIvdGVtcGxhdGUv
ZGV0YWlsLnRtcGxQSwECFAMUAAAACACJAVkyrbdH/hcBAAD8AQAAKwAAAAAAAAABAAAAJIEABAAA
YmFzZV9lcnJvci0zLjAyL3RlbXBsYXRlL21vbnRobHlfY291bnQudG1wbFBLAQIUAxQAAAAIAByj
aTJGsF2GHgMAADsGAAAuAAAAAAAAAAEAAAAkgWAFAABiYXNlX2Vycm9yLTMuMDIvT3BlbkludGVy
YWN0Mi9BcHAvQmFzZUVycm9yLnBtUEsBAhQDFAAAAAgAiQFZMvniyRCqAAAAAAEAACgAAAAAAAAA
AQAAACSByggAAGJhc2VfZXJyb3ItMy4wMi90ZW1wbGF0ZS9kYWlseV9saXN0LnRtcGxQSwECFAMU
AAAACACJAVkyyP+w+FECAAAtBwAAIgAAAAAAAAABAAAAJIG6CQAAYmFzZV9lcnJvci0zLjAyL3Rl
bXBsYXRlL2hvbWUudG1wbFBLAQIUAxQAAAAIAFO7VzJvDzNhtgAAAEYBAAAfAAAAAAAAAAEAAAAk
gUsMAABiYXNlX2Vycm9yLTMuMDIvY29uZi9hY3Rpb24uaW5pUEsBAhQDFAAAAAgAMWx2LoZ1uDLS
AAAAcQEAACkAAAAAAAAAAQAAACSBPg0AAGJhc2VfZXJyb3ItMy4wMi9kYXRhL2luc3RhbGxfc2Vj
dXJpdHkuZGF0UEsBAhQDFAAAAAgAV6RcMjoAHUjnCQAA1xYAABcAAAAAAAAAAQAAACSBVw4AAGJh
c2VfZXJyb3ItMy4wMi9DaGFuZ2VzUEsBAhQDFAAAAAgAU7tXMmn8UloWAgAAugUAAC4AAAAAAAAA
AQAAACSBcxgAAGJhc2VfZXJyb3ItMy4wMi9tc2cvYmFzZV9lcnJvcl9tZXNzYWdlcy1lbi5tc2dQ
SwECFAMUAAAACACZCFgyC21/NnsBAADbAgAAIgAAAAAAAAABAAAAJIHVGgAAYmFzZV9lcnJvci0z
LjAyL3RlbXBsYXRlL2xpc3QudG1wbFBLAQIUAxQAAAAIACmpbjKXiqWmiAQAAM4RAAAtAAAAAAAA
AAEAAAAkgZAcAABiYXNlX2Vycm9yLTMuMDIvT3BlbkludGVyYWN0Mi9BY3Rpb24vRXJyb3IucG1Q
SwECFAMUAAAACABEolwyDQUMO6YAAAA1AQAAGAAAAAAAAAABAAAAJIFjIQAAYmFzZV9lcnJvci0z
LjAyL01BTklGRVNUUEsFBgAAAAAOAA4AiwQAAD8iAAAAAA==

SOMELONGSTRING
}
