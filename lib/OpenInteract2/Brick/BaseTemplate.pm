package OpenInteract2::Brick::BaseTemplate;

use strict;
use base qw( OpenInteract2::Brick );
use OpenInteract2::Exception;

my %INLINED_SUBS = (
    'base_template-3.17.zip' => 'BASE_TEMPLATE317ZIP',
);

sub get_name {
    return 'base_template';
}

sub get_resources {
    return (
        'base_template-3.17.zip' => [ 'pkg base_template-3.17.zip', 'no' ],
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

OpenInteract2::Brick::BaseTemplate - Base-64 encoded OI2 package 'base_template-3.17.zip' shipped with distribution

=head1 SYNOPSIS

  oi2_manage create_website --website_dir=/path/to/site

=head1 DESCRIPTION

Are you sure you even need to be reading this? If you are just looking
to install a package just follow the instructions from the SYNOPSIS.

Still here? This class holds the Base64-encoded versions of package
file "base_template-3.17.zip" shipped with OpenInteract2. Once you decode them you
should store them as a ZIP file and then read them in with
Archive::Zip or some other utility.

A typical means to do this is:

 my $brick = OpenInteract2::Brick->new( 'base_template' );

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


=item B<base_template-3.17.zip>


=back

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS


Chris Winters E<lt>chris@cwinters.comE<gt>


=cut


sub BASE_TEMPLATE317ZIP {
    return <<'SOMELONGSTRING';
UEsDBBQAAAAIAAy1SjCUMoTiQgAAAEgAAAAgAAAAYmFzZV90ZW1wbGF0ZS0zLjE3L01BTklGRVNU
LlNLSVCLSXIOC45J4qpT4YrLzzSKz03MS0xP1cvJT1fhitHLz0kBUUmJ2RAqObu0AKjQ19HP0801
OCRGjyuuJLeAKy6eCwBQSwMEFAAAAAgANrlxMtxvyvDoAAAAVwEAADsAAABiYXNlX3RlbXBsYXRl
LTMuMTcvT3BlbkludGVyYWN0Mi9TUUxJbnN0YWxsL1NpdGVUZW1wbGF0ZS5wbY2OwUoDMRCG73mK
oaZ0iyWbXVvQLD32sCAWW/FUKOnutAbTNE1mq0X02V1XEC+Cc5j5+Rn4Pq+rZ71DmHt0pSMMuqJc
qeX9bekiaWvbbAgfcO+tJiwYuwBe1gp+t8LvRyfIRA65lJNUXqXZNcixkjdqPAGrq6fDGWavHjhj
TUSIFExFRZc3ul3Hl+RvAxi2VP5PQaUeZ4tlOb+DKUQfjKNt0uvXoi/zujeCI1/gyURzcKrz5TD9
gDRZ1ZfDlehO+kWLzQZ2SOuIVRMMnddbYxHeGLQTkJrgYGC+8T8/otY0KNg7Y1nBPgFQSwMEFAAA
AAgAGgVNMA+dkPoTAQAAnAMAADMAAABiYXNlX3RlbXBsYXRlLTMuMTcvdGVtcGxhdGUvdGVtcGxh
dGVfdG9vbHNfYm94LnRtcGzFUsFuwjAMvfMVvlSl0sgPsE2qBkzVNjjQnSoUpdSwioRUaWDb3y9x
CRqHITYOyyWx5Rf7+b0iGsBoPElfn3Owb6gQ7mCWMXryxugGja2xHfbAHasaybf4zndGdnVKbNBH
fUgf8mw2ddnYoisTFuMbAp07eTp/cpcDVXXrQJ9cVFUMCQyiRa+IuolYuZMSLUQLcKmX+WMf4lK0
yEMjZrWWpf5gUpQo2dIgdT8dN4Huy2xCeergRyjcAqjQqD0V/kDsl8y+0/NQg0rvLwY2YrkRa6+F
H40dwgvBW+FUpK4EpjAZHrFEFqvanlHxSrJBzJU26v8oHyS+Lc39X63k1xSMdFwZOem6f4MbTp0X
LDqejmj2L1BLAwQUAAAACAA2uXEyYKYOt7ESAAD3PQAAMAAAAGJhc2VfdGVtcGxhdGUtMy4xNy9P
cGVuSW50ZXJhY3QyL1NpdGVUZW1wbGF0ZS5wba1bbXfaSLL+rl/R69gH2GBsZ2fPuYttbhxMMuw6
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
isuWohir8Aq241nqqavBeZp6CuRCsI4CzegAn9HbGJyUCkyMPNHqafVLDqxKKXNg0tMVPNgsW23u
WQADk4abFOe8erT6Ynxop9CWtoJZIZOGs24TJT2hPo3BX+xW240CzcExSs5rT/yvdn700TaKmBVC
ES9JXvHyKfKZqkw68t04RD88I2CGVAKmndxN3OVO0oYxlIMXVTMKR475fKRQ17XY8Ugv/dFNm9+U
ercgdDD9NzDtH1BLAwQUAAAACADOolwybXdeHdcAAADQAQAAGwAAAGJhc2VfdGVtcGxhdGUtMy4x
Ny9NQU5JRkVTVI2PzU4CQRCE7/MuzCS+waJoNoqiC+fJMPQuHeYv000ib28HWE10Sbx1qr5Udd3v
XRqA1LJ5bR8X3fr70N1zu1LF+YMbQGNCtVk9fTQPC+Vz6o3zjDmd9Z1jZzARuxAsgT9W5JMWVUUa
zNYRWIZYgmOYRSCSPJpB0uKqtwKpTQxV8u5MhwzrK6pL/OU258r/QSNAG4LdPH9OgKWYufx2O6p7
f2kvq/50kq9Y2EQcqiiWs+0xAJ1IhuoS1LjXjIftc42a46QXkPiWxzkHsltZMA2QPcrCH+ALUEsB
AhQDFAAAAAgADLVKMJQyhOJCAAAASAAAACAAAAAAAAAAAQAAACSBAAAAAGJhc2VfdGVtcGxhdGUt
My4xNy9NQU5JRkVTVC5TS0lQUEsBAhQDFAAAAAgANrlxMtxvyvDoAAAAVwEAADsAAAAAAAAAAQAA
ACSBgAAAAGJhc2VfdGVtcGxhdGUtMy4xNy9PcGVuSW50ZXJhY3QyL1NRTEluc3RhbGwvU2l0ZVRl
bXBsYXRlLnBtUEsBAhQDFAAAAAgAGgVNMA+dkPoTAQAAnAMAADMAAAAAAAAAAQAAACSBwQEAAGJh
c2VfdGVtcGxhdGUtMy4xNy90ZW1wbGF0ZS90ZW1wbGF0ZV90b29sc19ib3gudG1wbFBLAQIUAxQA
AAAIADa5cTJgpg63sRIAAPc9AAAwAAAAAAAAAAEAAAAkgSUDAABiYXNlX3RlbXBsYXRlLTMuMTcv
T3BlbkludGVyYWN0Mi9TaXRlVGVtcGxhdGUucG1QSwECFAMUAAAACAD3SnkulTLQsNMAAAB4AQAA
LAAAAAAAAAABAAAAJIEkFgAAYmFzZV90ZW1wbGF0ZS0zLjE3L2RhdGEvaW5zdGFsbF9zZWN1cml0
eS5kYXRQSwECFAMUAAAACABzpFwylGLInLYKAACoGAAAGgAAAAAAAAABAAAAJIFBFwAAYmFzZV90
ZW1wbGF0ZS0zLjE3L0NoYW5nZXNQSwECFAMUAAAACABqHoUx6Xia8v8FAACwHQAANwAAAAAAAAAB
AAAAJIEvIgAAYmFzZV90ZW1wbGF0ZS0zLjE3L09wZW5JbnRlcmFjdDIvQWN0aW9uL1NpdGVUZW1w
bGF0ZS5wbVBLAQIUAxQAAAAIAByjaTK7s0+qiAgAAJYTAAA0AAAAAAAAAAEAAAAkgYMoAABiYXNl
X3RlbXBsYXRlLTMuMTcvT3BlbkludGVyYWN0Mi9BcHAvQmFzZVRlbXBsYXRlLnBtUEsBAhQDFAAA
AAgA+Ep5Lu4DW7CGAwAAWQgAADIAAAAAAAAAAQAAACSBXTEAAGJhc2VfdGVtcGxhdGUtMy4xNy9z
Y3JpcHQvbWlncmF0ZV90b19maWxlc3lzdGVtLnBsUEsBAhQDFAAAAAgAdaRcMlpMgH7ZAAAASgEA
AB4AAAAAAAAAAQAAACSBMzUAAGJhc2VfdGVtcGxhdGUtMy4xNy9wYWNrYWdlLmluaVBLAQIUAxQA
AAAIAPVKeS6LwljWkAAAAO4AAAAaAAAAAAAAAAEAAAAkgUg2AABiYXNlX3RlbXBsYXRlLTMuMTcv
VVBHUkFERVBLAQIUAxQAAAAIACoAUjCOsiVNqAIAAGIGAAAuAAAAAAAAAAEAAAAkgRA3AABiYXNl
X3RlbXBsYXRlLTMuMTcvdGVtcGxhdGUvdGVtcGxhdGVfbGlzdC50bXBsUEsBAhQDFAAAAAgANrlx
Mkme60OFBQAAYw4AADsAAAAAAAAAAQAAACSBBDoAAGJhc2VfdGVtcGxhdGUtMy4xNy9PcGVuSW50
ZXJhY3QyL0FjdGlvbi9UZW1wbGF0ZXNVc2VkQm94LnBtUEsBAhQDFAAAAAgAeQWEMdpIQzzuAQAA
cQYAADQAAAAAAAAAAQAAACSB4j8AAGJhc2VfdGVtcGxhdGUtMy4xNy9tc2cvYmFzZV90ZW1wbGF0
ZS1tZXNzYWdlcy1lbi5tc2dQSwECFAMUAAAACAAQrskuvQES5e0AAAAVAgAAIgAAAAAAAAABAAAA
JIEiQgAAYmFzZV90ZW1wbGF0ZS0zLjE3L2NvbmYvYWN0aW9uLmluaVBLAQIUAxQAAAAIADEAUjBA
DqL85gIAAFAJAAAuAAAAAAAAAAEAAAAkgU9DAABiYXNlX3RlbXBsYXRlLTMuMTcvdGVtcGxhdGUv
dGVtcGxhdGVfZm9ybS50bXBsUEsBAhQDFAAAAAgAQwVNMM89rp4jAQAAcQIAADMAAAAAAAAAAQAA
ACSBgUYAAGJhc2VfdGVtcGxhdGUtMy4xNy90ZW1wbGF0ZS90ZW1wbGF0ZXNfdXNlZF9ib3gudG1w
bFBLAQIUAxQAAAAIAM6iXDJtd14d1wAAANABAAAbAAAAAAAAAAEAAAAkgfVHAABiYXNlX3RlbXBs
YXRlLTMuMTcvTUFOSUZFU1RQSwUGAAAAABIAEgBQBgAABUkAAAAA

SOMELONGSTRING
}

