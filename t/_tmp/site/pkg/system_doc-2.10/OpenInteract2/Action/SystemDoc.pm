package OpenInteract2::Action::SystemDoc;

# $Id: SystemDoc.pm,v 1.15 2005/03/18 04:09:47 lachoy Exp $

use strict;
use base qw( OpenInteract2::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Package;
use Pod::POM;

$OpenInteract2::Action::SystemDoc::VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my ( %POD_CACHE );

sub list {
    my ( $self ) = @_;
    return $self->generate_content(
                    {}, { name => 'system_doc::system_doc_menu' } );
}


# TODO: Get SPOPS|OI2::Manual stuff in here

sub module_list {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    # Now sort INC and chop up the files into packages

    my %this_inc = %INC;
    my @top = ();

    my $count = -1;
    my $curr_parent = undef;
    foreach my $full_pkg ( sort keys %this_inc ) {
        next unless ( $full_pkg =~ /\.pm$/ );
        my ( $first ) = split /\//, $full_pkg;
        if ( $first ne $curr_parent ) {
            $count++;
            $log->is_debug &&
                $log->debug( "First item != parent: ",
                             "($first) / ($curr_parent)" );
            $curr_parent   = $first;
            $curr_parent   =~ s/\.pm$//;
            $top[ $count ] = [ $curr_parent, [] ];
        }
        $log->is_debug &&
            $log->debug( "Found package $full_pkg" );
        push @{ $top[ $count ]->[1] }, _colonify( $full_pkg );
    }
    $log->is_debug &&
        $log->debug( "# module parents found: ", scalar @top );
    return $self->generate_content(
                    { module_list => \@top },
                    { name => 'system_doc::module_listing' } );
}


sub _colonify {
    my ( $text ) = @_;
    $text =~ s|\.pm$||;
    $text =~ s|/|::|g;
    return $text;
}


sub _uncolonify {
    my ( $text, $is_pod ) = @_;
    $text =~ s|::|/|g;
    my $ext = ( $is_pod ) ? '.pod' : '.pm';
    return "$text$ext";
}


sub display {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    my $request = CTX->request;
    my %params = map { $_ => '' }
                     qw( pod_file  html_file text_file title error );

    # If this is a package, display the doc

    my $package_spec = $request->param( 'package' );
    if ( $package_spec ) {
        $self->_display_package_params( $package_spec, \%params );
    }
    else {
        my $module = $self->param( 'module' )
                     || $request->param( 'module' );
        $self->_display_module_params( $module, \%params );
    }

    my ( $content );

    if ( -f $params{pod_file} ) {
        $content = $self->_show_pod( \%params );
    }

    elsif ( -f $params{html_file} ) {
        $content = $self->_show_html( \%params );
    }

    elsif ( -f $params{text_file} ) {
        $content = $self->_show_text( \%params );
    }

    else {
        return "<p>$params{error}.</p>";
    }

    unless ( $content ) {
        return '<p>Filename found but no content in file.</p>';
    }
    return $self->generate_content(
                    { content => $content },
                    { name => 'system_doc::doc_display' } );
}

sub _display_package_params {
    my ( $self, $package_spec, $params ) = @_;
    my ( $package_name, $ver ) =
            OpenInteract2::Package->parse_full_name( $package_spec );
    my $request = CTX->request;
    my $doc = $request->param( 'doc' );
    my $repos = CTX->repository;
    if ( $doc =~ /\.(html|txt|pod)$/ ) {
        my $full_filename = $repos->find_file( $package_name, $doc );
        $log->is_debug &&
            $log->debug( "Found [$full_filename] in [$package_name]" );
        $params->{pod_file}  = $full_filename  if ( $doc =~ /\.pod$/ );
        $params->{html_file} = $full_filename  if ( $doc =~ /\.html$/ );
        $params->{text_file} = $full_filename  if ( $doc =~ /\.txt$/ );
        $params->{title} = $self->_msg( 'sys_doc.package.doc_title', $package_name );
        $params->{error} = $self->_msg( 'sys_doc.error.cannot_find_package_doc', $doc );
    }
}

sub _display_module_params {
    my ( $self, $module, $params ) = @_;

    # ewww! ick!
    # TODO: Can we programmatically use Pod::Perldoc to do this?
    $params->{pod_file} = $POD_CACHE{ $module } || `perldoc -l $module`;

    chomp $params->{pod_file};
    if ( $params->{pod_file} ) {
        $log->is_info &&
            $log->info( "Found [$params->{pod_file}] from [$module]" );
    }
    else {
        $params->{pod_file} = $INC{ _uncolonify( $module ) };
        $log->is_info &&
            $log->info( "Found [$params->{pod_file}] from %INC" );
    }
    if ( -f $params->{pod_file} ) {
        $POD_CACHE{ $module } = $params->{pod_file};
    }
    $params->{title} = $self->_msg( 'sys_doc.module.doc_title', $module );
    $params->{error} = $self->_msg( 'sys_doc.error.cannot_find_module_doc', $module );
}

sub _show_pod {
    my ( $self, $params ) = @_;
    $log->is_debug &&
        $log->debug( "Trying to view pod in [$params->{pod_file}]" );
    my $parser = Pod::POM->new();
    my $pom = $parser->parse( $params->{pod_file} );
    unless ( $pom ) {
        $log->error( "Pod::POM did not return an object: ",
                     $parser->error() );
        my $msg = $self->_msg( 'sys_doc.error.pod_parse', $parser->error() );
        return qq(<p>$msg</p>);
    }

    eval { require OpenInteract2::PodView };
    if ( $@ ) {
        $log->error( "No POD viewer: $@" );
        $self->add_error_key( 'sys_doc.error.pod_viewer', $@ );
        return $self->_msg( 'sys_doc.pod.no_content' );
    }
    my $content = eval { OpenInteract2::PodView->print( $pom ) };
    if ( $@ ) {
        $log->error( "Failed to output html from pod: $@" );
        return $self->_msg( 'sys_doc.pod.cannot_display_module', $@ );
    }
    $content =~ s/^.*<BODY>//sm;
    $content =~ s|</BODY>.*$||sm;
    return $content;
}

sub _show_html {
    my ( $self, $params ) = @_;
    eval { open( HTML, $params->{html_file} ) || die $! };
    if ( $@ ) {
        my $msg = $self->_msg( 'sys_doc.error.cannot_open_file',
                               $params->{html_file}, $@ );
        $log->error( $msg );
        return "<p>$msg</p>";
    }
    my $content = join( '', <HTML> );
    close( HTML );
    $content =~ s/^.*<BODY>//sm;
    $content =~ s|</BODY>.*$||sm;
    return $content;
}

sub _show_text {
    my ( $self, $params ) = @_;
    eval { open( TEXT, $params->{text_file} ) || die $! };
    if ( $@ ) {
        my $msg = $self->_msg( 'sys_doc.error.cannot_open_file',
                               $params->{text_file}, $@ );
        $log->error( $msg );
        return "<p>$msg</p>";
    }
    my $content = join( '', <TEXT> );
    close( TEXT );
    return qq(<pre class="systemDocText">$content</pre>);
}

1;

__END__

=head1 NAME

OpenInteract2::Action::SystemDoc - Display system documentation in HTML format

=head1 SYNOPSIS

=head1 DESCRIPTION

Display documentation for the OpenInteract system, SPOPS modules, and any
other perl modules used.

=head1 METHODS

C<list()>

List the OpenInteract system documentation and all the modules used by
the system -- we display both the C<OpenInteract> modules and the
C<SPOPS> modules first.

B<package_list()>

B<module_list()>

B<display()>

Display a particular document or module, filtering through
L<Pod::POM|Pod::POM> using
L<OpenInteract2::PodView|OpenInteract2::PodView>.

Parameters:

=over 4

=item *

B<filename>: Full filename of document to extract POD from.

=item *

B<module>: Perl module to extract POD from; we match up the module to
a file using %INC

=back

=head1 TO DO

B<Get more meta information>

System documentation needs more meta information so we can better
display title and other information on the listing page.

=head1 COPYRIGHT

Copyright (c) 2001-2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
