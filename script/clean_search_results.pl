#!/usr/bin/perl

# $Id: clean_results.pl,v 1.1 2003/03/26 21:49:25 lachoy Exp $

use strict;
use Getopt::Long;
use OpenInteract2::Context qw( CTX );
use OpenInteract2::ResultsManage;
use OpenInteract2::Setup;

use constant DEFAULT_REMOVAL_TIME => 60 * 30; # 30 minutes

{
    my ( $OPT_minutes, $OPT_website_dir, $OPT_debug );
    GetOptions( 'minutes=s'     => \$OPT_minutes,
                'website_dir=s' => \$OPT_website_dir,
                'debug'         => \$OPT_debug );
    $OPT_website_dir ||= $ENV{OPENINTERACT2};
    unless ( -d $OPT_website_dir ) {
        die "Usage $0: --website_dir=/path/to/website [--minutes=nn ] [--debug ]\n",
            "    Or use 'OPENINTERACT2' env for 'website_dir'\n",
            "    Default minutes: 30\n";
    }
    my $ctx = OpenInteract2::Context->create(
                              { website_dir => $OPT_website_dir } );
    my $removal_time = ( $OPT_minutes )
                         ? $OPT_minutes * 60 : DEFAULT_REMOVAL_TIME;

    my $results = OpenInteract2::ResultsManage->new();
    my $results_files = $results->get_all_result_filenames();

    my $now = time;
    foreach my $search_id ( @{ $results_files } ) {
        DEBUG() && warn "Try search ID [$search_id]\n";
        my $meta_info = $results->get_meta( $search_id );
        next unless ( ref $meta_info eq 'HASH' );
        if ( $now - $meta_info->{time} > $removal_time ) {
            $results->results_clear( $search_id );
            $OPT_debug && warn "-- Removed result [$search_id] which ",
                               " was originally searched ",
                               scalar localtime( $meta_info->{time} ), "\n";
        }
    }
    $OPT_debug && warn "Cleanup of results complete\n";
}

__END__

=head1 NAME

clean_search_results.pl - Script to cleanup the results directory of stale results

=head1 SYNOPSIS

 # From the command line
 
 # Use default 30 minute threshold
 $ perl clean_search_results.pl --website_dir=/path/to/mysite
 
 # Use 45 minute threshold
 $ perl clean_search_results.pl --website_dir=/path/to/mysite --minutes=45
 
 # Use the environment variable and the default 30 minute threshold
 $ export OPENINTERACT2=/path/to/mysite
 $ perl clean_search_results.pl
 
 # From a cron job - run every hour at 45 minutes past.
 45 * * * * perl /path/to/mysite/script/clean_search_results.pl --website_dir=/path/to/mysite
 
=head1 DESCRIPTION

Simple script -- just scan the entries in the results directory and
get rid of the ones older than x (default: 30) minutes.

=head1 SEE ALSO

L<OpenInteract2::ResultsManage|OpenInteract2::ResultsManage>

L<OpenInteract2::Manual::SearchResults|OpenInteract2::Manual::SearchResults>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
