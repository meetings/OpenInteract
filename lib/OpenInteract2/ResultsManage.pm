package OpenInteract2::ResultsManage;

# $Id: ResultsManage.pm,v 1.7 2004/02/18 05:25:26 lachoy Exp $

use strict;
use base qw( Class::Accessor::Fast );
use Data::Dumper  qw( Dumper );
use IO::File;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::ResultsIterator;
use SPOPS::Utility;

$OpenInteract2::ResultsManage::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my ( $log );

use constant FILENAME_WIDTH => 20;

my $LOCK_EXT         = 'lock';
my $RECORD_SEP       = '-->';
my $EXTRA_NAME_SEP   = ',';
my $MIXED_IDENTIFIER = 'MIXED';

my @FIELDS  = qw(
    search_id min max results_dir keywords
    num_records time date extra_name num_extra record_class result_list
);
__PACKAGE__->mk_accessors( @FIELDS );

########################################
# CLASS METHODS

sub new {
    my ( $pkg, $p ) = @_;
    my $class = ref $pkg || $pkg;
    my %data = map { $_ => $p->{ $_ } } @FIELDS;
    $data{results_dir} ||= $class->get_results_dir;
    return bless( \%data, $class );
}

sub get_results_dir {
    my ( $class ) = @_;
    return CTX->lookup_directory( 'overflow' );
}

sub find_page_boundaries {
    my ( $class, $page_num, $per_page ) = @_;
    return ( 0, 0 ) unless ( $page_num and $per_page );
    my $max = $page_num * $per_page;
    my $min = $max - $per_page;
    return ( $min, $max );
}

# Note that $item can be a class or an object -- if object, we'll take
# the number of records from it.

sub find_total_page_count {
    my ( $item, $per_page, $p_num_records ) = @_;
    my $num_records = ( ref $item and $item->{num_records} )
                        ? $item->{num_records} : $p_num_records;
    return 0 unless ( $per_page and $num_records );
    my $num_pages = $num_records / $per_page;
    return ( int $num_pages != $num_pages ) ? int( $num_pages ) + 1 : int $num_pages;
}




########################################
# OBJECT METHODS

# Clear out all information in an object

sub clear {
    my ( $self ) = @_;
    $self->{ $_ } = undef  for ( keys %{ $self } );
    return $self;
}


########################################
# SAVE RESULTS
########################################

# Save given results to a results file and a meta file

sub save {
    my ( $self, $to_save, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    my ( $is_empty );

    $is_empty++ unless( $to_save );
    $is_empty++ if ( ref $to_save eq 'ARRAY' and ! scalar @{ $to_save } );
    $is_empty++ if ( UNIVERSAL::isa( $to_save, 'SPOPS::Iterator' ) and ! $to_save->has_next );

    if ( $is_empty ) {
        $log->error( "Bailing out of saving search results -- nothing to save!" );
        return undef;
    }

    $log->is_debug &&
        $log->debug( "Trying to save search results." );

    my %params = ( force_mixed => $p->{force_mixed},
                   extra       => $p->{extra},
                   extra_name  => $p->{extra_name} );

    # First ensure we have a results directory in the object

    $self->{results_dir} ||= $self->get_results_dir;

    # Generate a search ID and get the filename, then lock the
    # filename from further use while we're working

    $params{search_id} = $self->generate_search_id;
    $log->debug( "Generated search ID '$params{search_id}'" );
    $self->results_lock( $params{search_id} );
    my ( $num_records );
    my $out      = IO::File->new();
    my $meta_out = IO::File->new();

    # First write out the actual data, then write out the metadata

    eval {
        my $results_file = $self->build_results_filename( $params{search_id} );
        $out->open( "> $results_file" )
                    || die "Cannot open '$results_file' for writing: $!\n";
        my $results_info = $self->persist( $out, $to_save, \%params );
        $out->close();

        my $meta_file = $self->build_meta_filename( $params{search_id} );
        $meta_out->open( "> $meta_file" )
                         || die "Cannot open '$meta_file' for writing: $!\n";
        $self->persist_meta( $meta_out, $results_info, \%params );
        $meta_out->close();
        $num_records = $results_info->{num_records};
    };

    # If we find an error anywhere along the way, be sure the files
    # are closed (paranoid, since falling out of scope should do it),
    # clear the lockfile and die.

    if ( $@ ) {
        $log->error( "Search result save failure. $@" );
        $out->close();
        $meta_out->close();
        $self->results_clear( $params{search_id} );
        die "Search result save failure: $@\n";
    }

    # Clear out the lockfile

    $self->results_unlock( $params{search_id} );

    # Set various information into the object

    $log->is_debug &&
        $log->debug( "Results saved ok: $num_records" );
    $self->num_records( $num_records );
    return $self->search_id( $params{search_id} );
}


sub persist {
    my ( $self, $out, $to_save, $params ) = @_;
    die "Item to be saved must be a reference!\n" unless ( ref $to_save );
    if ( ref $to_save eq 'ARRAY' ) {
        return $self->persist_list( $out, $to_save, $params );
    }
    elsif ( UNIVERSAL::isa( $to_save, 'SPOPS::Iterator' ) ) {
        return $self->persist_iterator( $out, $to_save, $params );
    }
    die "Item to be saved must either be arrayref or Iterator!\n";
}


sub persist_list {
    my ( $self, $out, $to_save, $params ) = @_;

    # See if the resultset is homogenous -- if the user wants it mixed
    # then keep it that way, otherwise look at the data passed in to
    # save

    my %info = ( record_class => undef );
    $info{record_class}   = $MIXED_IDENTIFIER if ( $params->{force_mixed} );
    $info{record_class} ||= $self->review_results_class( $to_save );

    # 'extra' items are additional pieces of information included with
    # each record; they can only be saved with non-iterators

    if ( ref $params->{extra} eq 'ARRAY' ) {
        $info{has_extra}  = ( ref $params->{extra}->[0] eq 'ARRAY' )
                              ? scalar @{ $params->{extra}->[0] } : 1;
        $info{extra_name} = $params->{extra_name} || [];
    }


    # Go through the items to save and derive a value and class for
    # each -- it's ok if the class is blank since that means we're
    # just saving raw data

    my $count = 0;
    foreach my $item ( @{ $to_save } ) {
        my @result_info = ( ref $item )
                            ? ( ref $item, scalar( $item->id ) )
                            : ( $info{record_class}, $item );
        $result_info[0] = '' if ( $info{record_class} eq $MIXED_IDENTIFIER );
        if ( $info{has_extra} ) {
            if ( ref $params->{extra}->[ $count ] eq 'ARRAY' ) {
                push @result_info, @{ $params->{extra}->[ $count ] };
            }
            else {
                push @result_info, $params->{extra}->[ $count ];
            }
        }
        $out->print( join( $RECORD_SEP, @result_info ), "\n" );
        $count++;
    }
    $info{num_records} = $count;
    return \%info;
}


sub persist_iterator {
    my ( $self, $out, $to_save, $params ) = @_;
    my %info = ( record_class => undef, num_records => 0 );
    while ( my $item = $to_save->get_next ) {
        $info{record_class} ||= ref $item;
        $out->print( join( $RECORD_SEP, $info{record_class},
                                        scalar( $item->id ) ), "\n" );
        $info{num_records}++;
    }
    return \%info;
}


# See whether we have a homogenous resultset or not -- return the
# class of all objects if they're all the same, otherwise return the
# global $MIXED_IDENTIFIER which tells us it's heterogeneous

sub review_results_class {
    my ( $self, $result_list ) = @_;
    my ( $main_class );
    foreach my $result ( @{ $result_list } ) {
        my $result_class = ref $result;
        next unless ( $result_class );
        return $MIXED_IDENTIFIER if ( $main_class and $main_class ne $result_class );
        $main_class ||= $result_class;
    }
    return $main_class;
}


########################################
# METADATA
########################################

sub persist_meta {
    my ( $self, $out, $info, $params ) = @_;
    $self->{results_dir} ||= $self->find_results_dir;
    my %meta_info = (
         time         => time,
         num_records  => $info->{num_records},
         record_class => $info->{record_class},
         has_extra    => $info->{has_extra},
         extra_name   => $info->{extra_name},
         num_extra    => ( ref $info->{extra_name} eq 'ARRAY' )
                           ? scalar $info->{extra_name} : 0,
         filename     => $params->{filename},
         results_dir  => $self->results_dir,
         search_id    => $params->{search_id},
    );
    $out->print( Dumper( \%meta_info ) );
}


sub get_meta {
    my ( $self, $search_id ) = @_;
    $log ||= get_logger( LOG_APP );

    my $meta_filename = $self->build_meta_filename( $search_id );
    return {} unless ( -f $meta_filename );
    eval { open( META, $meta_filename ) || die "Cannot open ($meta_filename): $!" };
    if ( $@ ) {
        $log->error( "Error opening meta file. $@" );
        return {};
    }
    local $/ = undef;
    no strict 'vars';
    my $meta_info = eval <META>;
    close( META );
    $meta_info->{date} = scalar localtime( $meta_info->{time} );
    return $meta_info;
}


########################################
# RETRIEVE RESULTS
########################################

# Returns either ( \@classes, \@ids, $num_records ) or \@ids depending
# on context

sub retrieve {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $self->search_id ) {
        die "Cannot retrieve results without a search_id! Please ",
            "set at object initialization or as a property of the ",
            "object before running retrieve().\n";
    }

    # 'min' and 'max' can be properties or passed in

    $self->min( $p->{min} ) unless ( defined $self->min );
    $self->max( $p->{max} ) unless ( defined $self->max );

    # Clear out the number of records

    $self->num_records(0);

    $log->is_debug &&
        $log->debug( "Retrieving raw search results for ",
                     "ID '", $self->search_id, "'" );
    $self->assign_results_to_object( $self->retrieve_raw_results( $p ) );

    # If they asked for an iterator return it, but first clear out any
    # min/max values since they've already been preselected

    if ( $p->{return} eq 'iterator' ) {
        $self->min(0);
        $self->max(0);
        $p->{min} = $p->{max} = 0;
        return $self->retrieve_iterator( $p );
    }
    return $self;
}


# Note that this only works on saved SPOPS objects

sub retrieve_iterator {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    # 'min' and 'max' can be properties or passed in

    $self->min( $p->{min} ) unless ( defined $self->min );
    $self->max( $p->{max} ) unless ( defined $self->max );

    $log->is_debug &&
        $log->debug( "Retrieving search iterator for ID",
                     "'", $self->search_id, "'" );

    unless ( $self->result_list ) {
        $self->assign_results_to_object( $self->retrieve_raw_results( $p ) );
    }
    if ( $self->num_records <= 0 ) {
        return OpenInteract2::ResultsIterator->new({ results => $self });
    }

    unless ( $self->record_class ) {
        die "Cannot create iterator! Search results were not saved with ",
            "a classname. [Search ID: ", $self->search_id, "]\n";
    }
    if ( $self->record_class eq $MIXED_IDENTIFIER ) {
        $self->min(0);
        $self->max(0);
        return OpenInteract2::ResultsIterator->new({
                     results       => $self,
                     skip_security => $p->{skip_security} });
    }
    return $self->record_class->fetch_iterator({ id_list => $self->get_id_list });
}


# Take the result list internally and return a list of all IDs

sub get_id_list {
    my ( $self ) = @_;
    unless ( $self->result_list ) {
        die "Results not yet saved for this object!\n"
    }
    return [ map { $_->{id} } @{ $self->result_list } ];
}



# Returns a hashref of information about the results, including the ID
# list, the class, results save time. Pass in min/max in the hashref
# (second arg) to have the results be paged.

sub retrieve_raw_results {
    my ( $self, $p ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $self->search_id ) {
        oi_error "No search_id defined in object!";
    }

    my $meta_info = $self->get_meta({ search_id => $self->search_id });
    $log->is_debug &&
        $log->debug( "[Run on: $meta_info->{date}] ",
                     "[Saved: $meta_info->{num_records}] ",
                     "[Type: $meta_info->{record_class}]" );
    if ( $meta_info->{num_records} <= 0 ) {
        return $meta_info;
    }

    my $filename = $self->build_results_filename;
    eval { open( RESULTS, $filename ) || die "Cannot open '$filename' for reading: $!\n" };
    if ( $@ ) {
        $log->error( "Search result retrieval failure. $@" );
        return undef;
    }

    my $count = 1;
    my $min = ( defined $self->min ) ? $self->min : $p->{min};
    my $max = ( defined $self->max ) ? $self->max : $p->{max};
    while ( <RESULTS> ) {
        if ( $min and $count < $min ) { $count++; next; }
        if ( $max and $count > $max ) { last; }
        chomp;
        my ( $item_class, $item_value, @extra ) =
            split /$RECORD_SEP/, $_, 2 + $meta_info->{num_extra};
        my $result_info = { id => $item_value };
        if ( $meta_info->{record_class} eq $MIXED_IDENTIFIER ) {
            $result_info->{class} = $item_class;
        }

        # Set the extra information in the result -- note that it's
        # ALWAYS an arrayref, even if there's only one.

        $result_info->{extra} = \@extra if ( $meta_info->{num_extra} );
        push @{ $meta_info->{result_list} }, $result_info;
        $count++;
    }
    close( RESULTS );
    return $meta_info;
}


sub assign_results_to_object {
    my ( $self, $result_info ) = @_;
    for ( @FIELDS ) {
        $self->$_( $result_info->{ $_ } );
    }
    return $self;
}


#######################################
# FILENAME/DIRECTORY METHODS
########################################

sub build_results_filename {
    my ( $self, $p_search_id ) = @_;
    my $search_id = $self->search_id || $p_search_id;
    unless ( $search_id ) {
        die "Cannot build a results filename without a search_id ",
            "as property or parameter!\n";
    }
    unless ( $self->results_dir ) {
        $self->results_dir( $self->get_results_dir );
    }
    return File::Spec->catfile( $self->results_dir, $search_id );
}


sub build_meta_filename {
    my ( $self, $p_search_id ) = @_;
    my $search_id = $self->search_id || $p_search_id;
    unless ( $search_id ) {
        die "Cannot build a results filename without a search_id ",
            "as property or parameter!\n";
    }
    unless ( $self->results_dir ) {
        $self->results_dir( $self->get_results_dir );
    }
    return File::Spec->catfile( $self->results_dir, "$search_id.meta" );
}


sub build_lock_filename {
    my ( $self, $p_search_id ) = @_;
    my $search_id = $self->search_id || $p_search_id;
    unless ( $search_id ) {
        die "Cannot build a lock filename without a search_id ",
            "as property or parameter!\n";
    }
    unless ( $self->results_dir ) {
        $self->results_dir( $self->get_results_dir );
    }
    return File::Spec->catfile( $self->results_dir, "$search_id.$LOCK_EXT" );
}


sub get_all_result_filenames {
    my ( $self ) = @_;
    unless ( $self->results_dir ) {
        $self->results_dir( $self->get_results_dir );
    }
    opendir( RESULTS, $self->results_dir )
             || die "Cannot open results directory '", $self->results_dir, "': $!";
    my @results_files = grep ! /\./, grep { length $_ == FILENAME_WIDTH } readdir( RESULTS );
    closedir( RESULTS );
    return \@results_files;
}


# Clear out the results, including the lockfile. This is called if we
# encounter some sort of error in the middle of writing. Don't die
# during this method because if this is called we have bigger
# problems...

sub results_clear {
    my ( $self, $search_id ) = @_;
    eval { $self->results_unlock( $search_id ) };
    unlink( $self->build_results_filename( $search_id ) );
    unlink( $self->build_meta_filename( $search_id ) );
}


########################################
# SEARCH ID
########################################

# Don't save the 'search_id' parameter into the object yet, since
# this method only ensures that we *can* create a file with the
# search_id

sub generate_search_id {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_APP );

    unless ( $self->results_dir ) {
        $self->results_dir( $self->get_results_dir );
    }

    unless ( -d $self->results_dir ) {
        $log->error( "Search results directory '", $self->results_dir, "'",
                      "is not a directory" );
        die "Configuration option for writing search results ",
            "'", $self->results_dir, "' is not a directory";
    }
    unless ( -w $self->results_dir ) {
        $log->error( "Search results dir '", $self->results_dir, "' is not writeable" );
        die "Configuration option for writing search results ",
            "'", $self->results_dir, "' exists but is not writeable";
    }
    while ( 1 ) {
        my $search_id = SPOPS::Utility->generate_random_code( FILENAME_WIDTH );
        my $filename = $self->build_results_filename( $search_id );
        my $lockfile = $self->build_lock_filename( $search_id );
        next if ( -f $filename || -f $lockfile );
        $log->is_debug &&
            $log->debug( "Found non-existent search info for ",
                         "'$search_id' in '", $self->results_dir, "'" );
        return $search_id;
    }
}


########################################
# LOCKING
########################################

# Lock the results file using another file

sub results_lock {
    my ( $self, $search_id ) = @_;
    my $lock_file = $self->build_lock_filename( $search_id );
    open( LOCK, "> $lock_file" )
        || die "Cannot open lockfile '$lock_file' for writing: $!";
    print LOCK scalar localtime;
    close( LOCK );
}


# Unlock the results file by deleting the lockfile.

sub results_unlock {
    my ( $self, $search_id ) = @_;
    my $lock_file = $self->build_lock_filename( $search_id );
    return unless ( -f $lock_file );
    unlink( $lock_file )
          || die "Cannot remove lockfile '$lock_file': $!";
}

1;

__END__

=head1 NAME

OpenInteract2::ResultsManage - Save and retrieve generic search results

=head1 SYNOPSIS

 use OpenInteract2::ResultsManage;
 
 # Basic usage
 
 ... perform search ...
 
 my $results = OpenInteract2::ResultsManage->new();
 $results->save( \@id_list );
 $request->session->{this_search_id} = $results->{search_id};
 
 ... another request from this user ...
 
 my $results = OpenInteract2::ResultsManage->new({
                              search_id => $R->{session}{this_search_id} });
 my $result_list = $results->retrieve();
 
 # Use with paged results
 
 my $results = OpenInteract2::ResultsManage->new();
 $results->save( \@id_list );
 $request->session->{this_search_id} = $results->{search_id};
 my $page_num = $R->apache->param( 'pagenum' );
 my ( $min, $max ) = $results->find_page_boundaries( $page_num, $HITS_PER_PAGE );
 my ( $results, $total_count ) = $results->retrieve({ min => $min, max => $max } );
 my $total_pages = $results->find_total_page_count( $HITS_PER_PAGE );
 my $total_hits = $results->{num_records};
 
 # Can now print "Page $page_num of $total_pages" or you
 # can pass this information to the template and use the
 # 'page_count' component and pass it 'total_pages',
 # 'current_pagenum', and a 'url' to get back to this page:
 
 [%- PROCESS page_count( total_pages     = 5,
                         current_pagenum = 3,
                         url             = url ) -%]
 
 Displays:
 
 Page [<<] [1] [2] 3 [4] [5] [>>]
 
 (Where the items enclosed by '[]' are links.)

=head1 DESCRIPTION

This class has methods to enable you to easily create paged result
lists. This includes saving your results to disk, retrieving them
easily and some simple calculation functions for page number
determination.

=head1 PUBLIC METHODS

The following methods are public and available for OpenInteract
application developers.

B<save( $stuff_to_save, \%params )>

Saves a list of things to be retrieved later. The C<$stuff_to_save>
can be an arrayref of ID values (simple scalars), an arrayref of SPOPS
objects, or an L<SPOPS::Iterator|SPOPS::Iterator> implementation all
primed and ready to go. If objects are passed in via a list or an
iterator, we call C<-E<gt>id()> on each to get the ID value to save.

If objects are used, we also query each one for its class and save
that information in the search results. Whether you have a homogenous
resultset or not affects the return values. If it is a homogenous
resultset we note the class for all objects in the search results
metadata, which is saved in a separate file from the results
themselves. This enables us to create an iterator from the results if
needed.

Parameters:

=over 4

=item *

B<class> ($) (optional)

You can force all the IDs passed in to be of a particular class.

=item *

B<force_mixed> (bool) (optional)

Forces the resultset to be treated as heterogeneous (mixed) even if
all objects are of the same class.

=item *

B<extra> (\@) (optional)

Each item represents extra information to save along with each
result. Each item must be either a scalar (which saves one extra item)
or an arrayref (which saves a number of extra items).

=item *

B<extra_name> (\@)  (optional)

If you specify extra information you need to give each one a name.

=back

Returns: an ID you can use to retrieve the search results using
the C<retrieve()> or C<retrieve_iterator()> methods. If
you misplace the ID, you cannot get the search results back.

Side effects: the ID returned is also saved in the 'search_id' key of
the object itself.

Example:

 my $results = OpenInteract2::ResultsManage->new();
 my $search_id = $results->save({ \@results,
                                  { force_mixed => 1,
                                    extra       => \@extra_info,
                                    extra_name  => [ 'hit_count', 'weight' ] });

The following parameters are set in the object after a successful
results save:

 search_id
 num_records

Returns: the ID of the search just saved.

B<retrieve( $search_id, \%params )>

Retrieve previously saved search results using the parameter
'search_id' which should be set on initialization or before this
method is run.

Parameters:

=over 4

=item *

B<min>: Where we should start grabbing the results. Generally used if
you are using a paged results scheme, (page 1 is 1 - 25, page 2 26 -
50, etc.). (Can be set at object creation.)

=item *

B<max>: Where should we stop grabbing the results. See B<min>. (Can be
set at object creation.)

=back

Returns:

=over 4

=item *

B<In list context>: an array with the first element an arrayref of the
results (or IDs of the results), the second element an arrayref of the
classes used in the results, the third element being the total number
of items saved. (The total number of items can be helpful when
creating pagecounts.)

=item *

B<In scalar context>: an arrayref of the results.

=back

Note: The interface for this method may change, and we might split
apart the different return results into two methods (particularly
whether classes are involved).

Also sets the object parameters:

'num_records' - total number of results in the original search

'date' - date the search was run

'num_extra' - number of 'extra' records saved

'extra_name' (\@) - list of fields matching extra values saved

B<retrieve_iterator( $search_id, \%params )>

Retrieves an iterator to walk the results. You can use min/max to
pre-separate or you can simply grab all the results and screen them
out yourself.

Parameters: same as C<retrieve()>

B<find_total_page_count( $records_per_page, [ $num_records ] )>

If called as an object then use 'num_records' property of object. If
'num_records' is not in the object, or if you call this as a class
method, then we use the second parameter for the total number of
records.

Returns: Number of pages required to display C<$num_records> at
C<$records_per_page>.

Example:

 my $page_count = $class->find_total_page_count( 289, 25 );
 # $page_count = 11
 
 my $page_count = $class->find_total_page_count( 289, 75 );
 # $page_count = 4

B<find_page_boundaries( $page_number, $records_per_page )>

Returns: An array with the floor and ceiling values to display the
given page with $records_per_page on the page.

Example:

 my ( $min, $max ) = $class->find_page_boundaries( 3, 75 );
 # $min is 226, $max is 300

 my ( $min, $max ) = $class->find_page_boundaries( 12, 25 );
 # min is 301, $max is 325

=head1 INTERNAL METHODS

B<build_results_filename()>

B<generate_search_id()>

B<results_lock()>

B<results_unlock()>

B<results_clear()>

B<retrieve_raw_results()>

=head1 DATA FORMAT

Here is an example of a saved resultset. This one happens to be
generated by the L<OpenInteract2::FullText|OpenInteract2::FullText>
module.

 Thu Jul 12 17:19:05 2001-->3-->-->1-->fulltext_score
 -->3d5676e0af1f1cc6b539fb08a5ee67b7-->2
 -->c3d72c3c568d99a796b23e8efc75c00f-->1
 -->8f10f3a91c3f10c876805ab1d76e1b94-->1

Here are all the pieces:

B<First>, the separator is C<--E<gt>>. This is configurable in this
module.

B<Second>, the first line has:

=over 4

=item *

C<Thu Jul 12 17:19:05 2001>

The date the search was originally run.

=item *

C<3>

The number of items in the entire search resultset.

=item *

C<> (empty)

If it were filled it would be either a classname (e.g.,
'MySite::User') or the keyword 'MIXED' which tells this class that the
results are of multiple classes.

=item *

C<1>

The number of 'extra' fields.

=item *

C<fulltext_score>

The name of the first 'extra' field. If there wore than one extra
field they would be separated with commas.

=back

B<Third>, the second and remaining line have three pieces:

=over 4

=item *

C<> (empty)

The class name for this result. Since these IDs are not from a class,
there is no class name.

C<3d5676e0af1f1cc6b539fb08a5ee67b7>

The main value returned, also the ID of the object returned that, when
matched with the class name (first item) would be able to define an
object to be fetched.

C<2>

The first 'extra' value. Successive 'extra' values are separated by
'--E<gt>' like the other fields.

=back

=head1 BUGS

None known, although the API may change in the near future.

=head1 TO DO

B<Review API>

The API is currently unstable but should solidify quickly as we get
more use out of this module.

 - Keep 'mixed' stuff in there, or maybe always treat the resultset as
 potentially heterogeneous objects?

 - Test with saving different types of non-object data as well as
 objects and see if the usage holds up (including with the
 ResultsIterator).

B<Objectify?>

Think about creating a 'search_results' object that can access the
resultset along with metadata about the results (number of items, time
searched, etc.). This would likely prove easier to work with in the
future.

What would also be interesting is combine this with the interface for
L<SPOPS::Iterator|SPOPS::Iterator> and the currently impelemented
L<OpenInteract2::ResultsIterator|<OpenInteract2::ResultsIterator>, so
we could do something like:

 my $search = OpenInteract2::ResultsManage->new( $search_id );
 print "Search initially run: $search->{search_date}\n",
       "Number of results: $search->{num_records}\n";
 $search->set_min( 10 );
 $search->set_max( 25 );
 while ( my $obj = $search->get_next ) {
   print "Object retrieved is a ", ref $obj, " with ID ", $obj->id, "\n";
 }

=head1 COPYRIGHT

Copyright (c) 2001-2004 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
