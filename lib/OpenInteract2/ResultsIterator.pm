package OpenInteract2::ResultsIterator;

# $Id: ResultsIterator.pm,v 1.2 2003/06/11 02:43:31 lachoy Exp $

use strict;
use base qw( SPOPS::Iterator );
use SPOPS::Iterator  qw( ITER_IS_DONE );

use constant DEBUG => 0;

$OpenInteract2::ResultsIterator::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub initialize {
    my ( $self, $p ) = @_;
    $self->{_SEARCH_RESULTS}    = $p->{results}{result_list};
    $self->{_SEARCH_EXTRA_NAME} = $p->{results}{extra_name};
    $self->{_SEARCH_COUNT}      = 1;
    $self->{_SEARCH_RAW_COUNT}  = 0;
    $self->{_SEARCH_OFFSET}     = $p->{min} || $p->{results}{min};
    $self->{_SEARCH_MAX}        = $p->{max} || $p->{results}{max};
}


sub fetch_object {
    my ( $self ) = @_;

    # Get the info for retrieving the object

    my $current_count = $self->{_SEARCH_RAW_COUNT};
    my $object_class = $self->{_SEARCH_RESULTS}->[ $current_count ]->{class};
    my $object_id    = $self->{_SEARCH_RESULTS}->[ $current_count ]->{id};

    return ITER_IS_DONE unless ( $object_class and $object_id );

    DEBUG && warn( "Item [$self->{_SEARCH_COUNT}] trying [$object_class] [$object_id]" );
    my $object = eval { $object_class->fetch( $object_id,
                                              { skip_security => $self->{_SKIP_SECURITY} } ) };

    if ( $@ ) {
        if ( ref $@ and $@->isa( 'SPOPS::Exception::Security' ) ) {
            DEBUG && warn( "Skip to next item, caught security exception: $@" );
            $self->{_SEARCH_RAW_COUNT}++;
            return $self->fetch_object;
        }
        DEBUG && warn( "Caught non-security exception: $@" );
    }

    unless ( $object ) {
        DEBUG && warn( "Iterator is depleted (no object fetched), notify parent" );
        return ITER_IS_DONE;
    }

    # Using min/max and haven't reached it yet

    if ( $self->{_SEARCH_OFFSET} and 
         ( $self->{_SEARCH_COUNT} < $self->{_SEARCH_OFFSET} ) ) {
        $self->{_SEARCH_COUNT}++;
        $self->{_SEARCH_RAW_COUNT}++;
        return $self->fetch_object;
    }

    if ( $self->{_SEARCH_MAX} and
         ( $self->{_SEARCH_COUNT} > $self->{_SEARCH_MAX} ) ) {
        return ITER_IS_DONE;
    }

    # Ok, we've gone through all the necessary contortions -- we can
    # actually return the object. Finish up.

    if ( $self->{_SEARCH_EXTRA_NAME} ) {
        my $extra_info = $self->{_SEARCH_RESULTS}->[ $current_count ]->{extra};
        my $extra_count = 0;
        foreach my $name ( @{ $self->{_SEARCH_EXTRA_NAME} } ) {
            $object->{"tmp_$name"} = $extra_info->[ $extra_count ];
            $extra_count++;
        }
    }

    $self->{_SEARCH_RAW_COUNT}++;
    $self->{_SEARCH_COUNT}++;

    return ( $object, $self->{_SEARCH_COUNT} );
}

1;

__END__

=head1 NAME

OpenInteract2::ResultsIterator - Iterator to scroll through search results that are objects of different classes.

=head1 SYNOPSIS

 my $results = OpenInteract2::ResultsManage->new(
                              { search_id => $search_id });
 my $iter = $results->retrieve({ return => 'iterator' });
 while ( my $obj = $iter->get_next ) {
     print "Object is a ", ref $obj, " with ID ", $obj->id, "\n";
 }

=head1 DESCRIPTION

This class implements L<SPOPS::Iterator> so we can scroll through
search results one at a time.

=head1 METHODS

B<initialize>

B<fetch_object>

=head1 BUGS

None yet!

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Iterator|SPOPS::Iterator>

L<OpenInteract2::SearchManage|OpenInteract2::SearchManage>

=head1 COPYRIGHT

Copyright (c) 2001-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
