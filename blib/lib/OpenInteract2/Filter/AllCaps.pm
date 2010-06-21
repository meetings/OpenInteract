package OpenInteract2::Filter::AllCaps;

# $Id: AllCaps.pm,v 1.2 2005/03/18 04:09:50 lachoy Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

$OpenInteract2::Filter::AllCaps::VERSION  = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub update {
    my ( $class, $action, $type, $content ) = @_;
    return unless ( $type eq 'filter' );
    my $log = get_logger( LOG_APP );
    $log->is_info && $log->info( "Running ALLCAPS filter on content" );
    $$content =~ tr/a-z/A-Z/;
}

__END__

=head1 NAME

OpenInteract2::Filter::AllCaps - Sample filter to translate content into all caps.

=head1 SYNOPSIS

 # In $WEBSITE_DIR/conf/observer.ini
 
 # register the observer
 [observer]
 allcaps = OpenInteract2::Filter::AllCaps
 
 # map the observer to an action
 [observer action]
 allcaps = myaction

=head1 DESCRIPTION

Observer that transforms all content to upper case.

=head1 COPYRIGHT

Copyright (c) 2004-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
