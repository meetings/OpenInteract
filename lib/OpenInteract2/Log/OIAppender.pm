package OpenInteract2::Log::OIAppender;

use strict;
use OpenInteract2::Context qw( CTX );

sub new {
    my ( $class ) = @_;
    return bless( {}, $class );
}

sub log {
    my ( $self, %params ) = @_;
    my ( $m_category, $m_class, $m_line, $m_msg ) =
        split /\s*&&\s*/, $params{message};
    my $req = CTX->request;
    my %request_info = ();
    if ( $req ) {
        %request_info = ( user_id    => $req->auth_user->id,
                          session_id => $req->session->{_session_id},
                          browser    => $req->user_agent,
                          referer    => $req->referer,
                          url        => $req->url_absolute );
    }
    else {
        %request_info = ( user_id    => undef,
                          session_id => undef,
                          browser    => undef,
                          referer    => undef,
                          url        => 'n/a' );
    }
    eval {
        my $error_class = CTX->lookup_object( 'error_object' );
        my $err = $error_class->new({ category   => $m_category,
                                      loc_class  => $m_class,
                                      loc_line   => $m_line,
                                      message    => $m_msg,
                                      error_time => DateTime->now,
                                      %request_info });
        $err->save();
    };
    if ( $@ ) {
        warn "Failed to save error object: $@";
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Log::OIAppender - Appender to put error message in OI error log

=head1 SYNOPSIS

 # Define the appender -- any messages with ERROR or FATAL levels will
 # have an object created in the error log
  
 log4perl.appender.OIAppender          = OpenInteract2::Log::OIAppender
 log4perl.appender.OIAppender.layout   = Log::Log4perl::Layout::PatternLayout
 log4perl.appender.OIAppender.layout.ConversionPattern = %c && %C && %L && %m
 log4perl.appender.OIAppender.Threshold = ERROR
 
 # Add the appender to the root category
 
 log4perl.logger = FATAL, FileAppender, OIAppender

=head1 DESCRIPTION

Capture certain errors for use by the OI error log.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

