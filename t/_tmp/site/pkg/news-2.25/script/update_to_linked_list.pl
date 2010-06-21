#!/usr/bin/perl

# $Id: update_to_linked_list.pl,v 1.1 2003/03/28 12:57:53 lachoy Exp $

# Fetch all 'news' objects to link to one another. Only run this after
# you've updated the table structure with the 'previous_id' and
# 'next_id' fields

use strict;
use OpenInteract2::Context qw( CTX );
use OpenInteract2::Startup;

{
    $| = 1;
    OpenInteract2::Setup->setup_static_environment_options(
                         undef, {}, { temp_lib => 'lazy' } );
    my $news_items = eval {
        CTX->lookup_object( 'news' )
           ->fetch_group({ order => 'posted_on ASC' })
    };
    if ( $@ ) {
        warn "Caught error trying to fetch news items\n$@\nExiting...\n";
        exit(1);
    }

    my $num_items = scalar @{ $news_items };
    print "Updating [$num_items] news items...\n";

    unless ( $num_items > 0 ) {
        print "Uh-oh, no news objects to update. Exiting...\n";
        exit(0);
    }

    # Do the first item...

    $news_items->[0]->{next_id} = $news_items->[1]->id;
    eval { $news_items->[0]->save({ skip_security => 1 }) };
    if ( $@ ) {
        die "Failed to modify the first item [ID: ", $news_items->[0]->id, "]",
            "Error: $@\n";
    }

    # The middle items...

    for ( my $i = 1; $i < ( $num_items - 1 ); $i++ ) {
        $news_items->[ $i ]->{previous_id} = $news_items->[ $i - 1 ]->id;
        $news_items->[ $i ]->{next_id}     = $news_items->[ $i + 1 ]->id;
        eval { $news_items->[ $i ]->save({ skip_security => 1 }) };
        if ( $@ ) {
            die "Failed to modify news item [ID: ", $news_items->[ $i ]->id, "] ",
                "Error: $@\n";
        }
    }

    # And the last item

    $news_items->[ $num_items - 1 ]->{previous_id} = $news_items->[ $num_items - 2 ]->id;
    eval { $news_items->[ $num_items - 1 ]->save({ skip_security => 1 }) };
    if ( $@ ) {
        die "Failed to modify the last item [ID: ", $news_items->[ $num_items - 1 ]->id, "] ",
            "Error: $@\n";
    }

    print "All $num_items news entries updated successfully\n";
}
