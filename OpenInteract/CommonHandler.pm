package OpenInteract::CommonHandler;

# $Id: CommonHandler.pm,v 1.24 2001/10/14 20:56:30 lachoy Exp $

use strict;
use Data::Dumper    qw( Dumper );
use OpenInteract::Handler::GenericDispatcher;
use SPOPS::Secure   qw( :level );
require Exporter;

@OpenInteract::CommonHandler::ISA       = qw( OpenInteract::Handler::GenericDispatcher );
$OpenInteract::CommonHandler::VERSION   = sprintf("%d.%02d", q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/);
@OpenInteract::CommonHandler::EXPORT_OK = qw( OK ERROR );

use constant OK    => '1';
use constant ERROR => '4';


########################################
# SEARCH FORM
########################################

# Common handler method for a search form (easy)

sub search_form {
    my ( $class, $p ) = @_;
    unless ( $class->MY_ALLOW_SEARCH_FORM ) {
        return '<h1>Error</h1><p>Objects of this type cannot be searched.</p>';
    }
    $p ||= {};

    my $R = OpenInteract::Request->instance;
    my %params = %{ $p };
    $R->{page}{title} = $class->MY_SEARCH_FORM_TITLE;

    $class->_search_form_customize( \%params );
    my $template_name = $class->_template_name(
                                   \%params,
                                   $class->MY_SEARCH_FORM_TEMPLATE( \%params ) );
    return $R->template->handler( {}, \%params, { name => $template_name } );
}


########################################
# SEARCH
########################################

# Common handler method for a search

sub search {
    my ( $class, $p ) = @_;
    unless ( $class->MY_ALLOW_SEARCH ) {
        return '<h1>Error</h1><p>Objects of this type cannot be searched.</p>';
    }
    $p ||= {};

    my $R   = OpenInteract::Request->instance;
    my $apr = $R->apache;

    my %params = %{ $p };

    if ( $class->MY_SEARCH_RESULTS_PAGED ) {
        require OpenInteract::ResultsManage;
        my $search_id = $class->_search_get_id;
        my $results = OpenInteract::ResultsManage->new();

        # If the search has been run before, just set the ID

        if ( $search_id ) {
            $R->DEBUG && $R->scrib( 1, "Retrieving search for ID ($search_id)" );
            $results->{search_id} = $search_id;
        }

        # Otherwise, run the search and get an iterator back, then
        # pass the iterator to ResultsManage so we can reuse the
        # results

        else {
            $R->DEBUG && $R->scrib( 1, "Running search for the first time" );
            my $iterator = $class->_search_build_and_run({ is_paged => 1 });
            $results->save( $iterator );
            $R->DEBUG && $R->scrib( 1, "Search ID ($results->{search_id})" );
            $class->_search_save_id( $results->{search_id} );
        }

        $params{page_number_field} =  $class->MY_SEARCH_RESULTS_PAGE_FIELD;
        $params{current_page} = $apr->param( $params{page_number_field} ) || 1;
        my $hits_per_page     = $class->MY_SEARCH_RESULTS_PAGE_SIZE;
        my ( $min, $max )     = $results->find_page_boundaries(
                                           $params{current_page}, $hits_per_page );
        $params{iterator}     = $results->retrieve({ min => $min, max => $max,
                                                     return => 'iterator' });
        $params{total_pages}  = $results->find_total_page_count( $hits_per_page );
        $params{total_hits}   = $results->{num_records};
        $params{search_id}    = $results->{search_id};
        $params{search_results_key} = $class->MY_SEARCH_RESULTS_KEY;
        $R->DEBUG && $R->scrib( 1, "Search info: min: ($min); max: ($max)",
                                   "records ($results->{num_records})" );
    }

    # If we're not using paged results, then just run the normal
    # search and get back an iterator

    else {
        $params{iterator} = $class->_search_build_and_run;
    }

    $R->{page}{title} = $class->MY_SEARCH_RESULTS_TITLE;

    $class->_search_customize( \%params );
    my $template_name = $class->_template_name(
                                   \%params,
                                   $class->MY_SEARCH_RESULTS_TEMPLATE( \%params ) );
    return $R->template->handler( {}, \%params, { name => $template_name } );
}


sub _search_get_id {
    my ( $class ) = @_;
    my $R = OpenInteract::Request->instance;
    my $search_key = $class->MY_SEARCH_RESULTS_KEY;
    return $R->apache->param( $search_key );
}


# If the handler wants to save the search ID elsewhere (session,
# etc.), override this

sub _search_save_id { return $_[1] }


# Build the search and run it, returning an iterator

sub _search_build_and_run {
    my ( $class, $p ) = @_;
    my $R = OpenInteract::Request->instance;

    # Grab the criteria and customize if necessary

    my $criteria = $class->_search_build_criteria;

    my ( $tables, $where, $values ) =
                    $class->_search_build_where_clause( $criteria );

    my ( $limit );
    if ( $p->{min} or $p->{max} ) {
        if ( $p->{min} and $p->{max} ) { $limit = "$p->{min},$p->{max}" }
        elsif ( $p->{max} )            { $limit = $p->{max} }
    }

    my $object_class = $class->MY_OBJECT_CLASS;
    $R->DEBUG && $R->scrib( 1, "RUN SEARCH (before): ", scalar localtime );

    # If the results are paged, only retrieve the ID field of our
    # object, and add any fields specified in the ORDER clause as
    # well. Otherwise just select all fields

    my ( @field_list );
    my $order = $class->MY_SEARCH_RESULTS_ORDER;
    if ( $p->{is_paged} ) {
        @field_list = ( $object_class->id_field );
        if ( $order ) {
            my @order_items = split( /\s*,\s*/, $order );
            push @field_list, grep ! /^(ASC|DESC)$/, @order_items;
        }
    }
    else {
        @field_list = @{ $object_class->field_list };
    }
    my $iter = eval { $object_class->fetch_iterator({
					                     field_list => \@field_list,
                                         from       => $tables,  where => $where,
                                         value      => $values,  limit => $limit,
                                         order      => $order }) };
    $R->DEBUG && $R->scrib( 1, "RUN SEARCH (after): ", scalar localtime );

    return $iter unless ( $@ );

    $R->scrib( 0, "Search failed: $@ ($SPOPS::Error::system_msg)\nClass: $class\n",
                  "FROM:", join( ',', @{ $tables } ), "\n",
                  "WHERE: $where\n",
                  "VALUES: ", join( ',', @{ $values } ) );
}


# Grab the specified fields and values out of the form
# submitted. Fields with multiple values are saved as arrayrefs.

sub _search_build_criteria {
    my ( $class ) = @_;
    my $R = OpenInteract::Request->instance;
    my $apr = $R->apache;
    my $object_class = $class->MY_OBJECT_CLASS;
    my $object_table = $object_class->base_table;
    my ( %search_params );

    # Go through each search field and assign a value. If the search
    # field is a simple one (no table.field), then prepend the object
    # table to the fieldname

    foreach my $field ( $class->MY_SEARCH_FIELDS ) {
        my @value = $apr->param( $field );
        next unless ( defined $value[0] and $value[0] ne '' );
        my $full_field = ( $field =~ /\./ )
                           ? $field : "$object_table.$field";
        $search_params{ $full_field } = ( scalar @value > 1 )
                                          ? \@value : $value[0];
    }
    $R->DEBUG && $R->scrib( 1, "($class) Found search parameters:\n",
                               Dumper( \%search_params ) );
    return $class->_search_criteria_customize( \%search_params );
}


# Build a WHERE clause -- parameters with multiple values are 'OR',
# everything else is 'AND'. Example:
#
#  ( table.last_name LIKE '%win%' OR table.last_name LIKE '%smi%' )
#  AND ( table.first_name LIKE '%john%' )

sub _search_build_where_clause {
    my ( $class, $search_criteria ) = @_;
    my $R = OpenInteract::Request->instance;

    # Find all our configured information

    my $object_class = $class->MY_OBJECT_CLASS;
    my $object_table = $object_class->base_table;
    my %from_tables  = ( $object_table => 1 );
    my %exact_match        = map { $_ => 1 } $class->MY_SEARCH_FIELDS_EXACT;
    my %left_exact_match   = map { $_ => 1 } $class->MY_SEARCH_FIELDS_LEFT_EXACT;
    my %right_exact_match  = map { $_ => 1 } $class->MY_SEARCH_FIELDS_RIGHT_EXACT;

    # Go through each of the criteria set -- note that each one must
    # be a fully-qualified (table.field) fieldname or it is discarded.

    my ( @where, @value ) = ();
    foreach my $field_name ( keys %{ $search_criteria } ) {
        $R->DEBUG && $R->scrib( 2, "Testing ($field_name) with ",
                                   "($search_criteria->{ $field_name })" );
        next unless ( defined $search_criteria->{ $field_name } );

        # Discard non-qualified fieldnames. Note that this regex will
        # greedily swallow everything to the last '.' to accommodate
        # systems that use a 'db.table' syntax to refer to a table.

        my ( $table ) = $field_name =~ /^([\w\.]*)\./;
        next unless ( $table );

        # Track the table used

        $from_tables{ $table }++;

        # See if we're using one or multiple values

        my $value_list = ( ref $search_criteria->{ $field_name } )
                           ? $search_criteria->{ $field_name }
                           : [ $search_criteria->{ $field_name } ];

        # Hold the items for this particular criterion, which will be
        # join'd with an 'OR'

        my @where_param = ();
        foreach my $value ( @{ $value_list } ) {

            # Value must be defined to be set

            next unless ( defined $value and $value ne '' );

            # Default is a LIKE match (see POD)

            my $oper         = ( $exact_match{ $field_name } ) ? '=' : 'LIKE';
            push @where_param, " $field_name $oper ? ";
            my ( $search_value );
            if ( $exact_match{ $field_name } ) {
                $search_value = $search_criteria->{ $field_name };
            }
            elsif ( $left_exact_match{ $field_name } ) {
                $search_value = "$search_criteria->{ $field_name }%";
            }
            elsif ( $right_exact_match{ $field_name } ) {
                $search_value = "%$search_criteria->{ $field_name }";
            }
            else {
                $search_value = "%$search_criteria->{ $field_name }%";
            }
            push @value, $search_value;
            $R->DEBUG && $R->scrib( 1, "Set ($field_name) $oper ($search_value)" );
        }
        push @where, '( ' . join( ' OR ', @where_param ) . ' )';
    }

    # Generate any statements needed to link tables for searching.

    # DO NOT replace '@tables_used' in the foreach with 'keys
    # %from_tables' since we may add items to %from_tables during the
    # loop. Also don't do an 'each %table_links' and then check to see
    # if the table is in %from_tables for the same reason.

    my %table_links = $class->MY_SEARCH_TABLE_LINKS;
    my @tables_used = keys %from_tables;
    foreach my $link_table ( @tables_used ) {
        my $id_link = $table_links{ $link_table };
        next unless ( $id_link );

        # See POD for what the values in MY_SEARCH_TABLE_LINKS mean

        if ( ref $id_link eq 'ARRAY' ) {
            my $num_linking_fields = scalar @{ $id_link };
            if ( $num_linking_fields == 2 ) {
                my ( $object_field, $link_field ) = @{ $id_link };
                $R->DEBUG && $R->scrib( 1, "Linking ($link_table) with my field ",
                                           "($object_field) to ($link_field)" );
                push @where, join( ' = ', "$object_table.$object_field",
                                          "$link_table.$link_field" );
            }

            # Remember to add the linking table to our FROM list!

            elsif ( $num_linking_fields == 3 ) {
                my ( $base_id_field, $middle_table, $link_id_field ) = @{ $id_link };
                $R->DEBUG && $R->scrib( 1, "Linking to ($link_table) through ",
                                           "($middle_table)" );
                push @where, join( ' = ', "$object_table.$base_id_field",
                                          "$middle_table.$base_id_field" );
                push @where, join( ' = ', "$middle_table.$link_id_field",
                                          "$link_table.$link_id_field" );
                $from_tables{ $middle_table }++;
            }
            else {
                $R->scrib( 0, "Cannot generate a link clause for ",
                              "($link_table) from ($class)" );
                die "Cannot generate linking clauses for ($link_table) from ",
                    "($class): if value of hash is an array reference it ",
                    "must have either two or three elements.\n";
            }
        }
        else {
            $R->DEBUG && $R->scrib( 1, "Straight link to ($link_table) with",
                                       "($id_link)" );
            push @where, join( ' = ', "$object_table.$id_link",
                                      "$link_table.$id_link" );
        }
    }

    my @tables = keys %from_tables;
    $class->_search_build_where_customize( \@tables, \@where, \@value );

    my $clause = join( " AND ", @where );
    $R->DEBUG && $R->scrib( 1, "($class) Built WHERE clause\n",
                                "FROM:", join( ', ', @tables ), "\n",
                                "WHERE: $clause\n",
                                "VALUES:", join( ', ', @value ) );
    return ( \@tables, $clause, \@value );
}




########################################
# DISPLAY
########################################

sub show {
    my ( $class, $p ) = @_;
    unless ( $class->MY_ALLOW_SHOW ) {
        return '<h1>Error</h1><p>Objects of this type cannot be viewed.</p>';
    }
    $p ||= {};

    my $R = OpenInteract::Request->instance;
    my %params = %{ $p };

    # Assumption: Only users with SEC_LEVEL_WRITE can edit. Maybe
    # create configuration for: object_update_level,
    # object_create_level so we can have different security levels for
    # create and modify?

    $params{do_edit} = ( $R->apache->param( 'edit' ) and
                         $p->{level} >= SEC_LEVEL_WRITE );

    # Setup our default info

    my $object_type  = $class->MY_OBJECT_TYPE;
    my $object_class = $class->MY_OBJECT_CLASS;
    my $id_field     = $object_class->id_field;
    my $object = $p->{ $object_type } ||
                 eval { $class->fetch_object( $p->{ $id_field }, $id_field ) };
    return $class->search_form({ error_msg => $@ }) if ( $@ );

    # Ensure the object can be edited

    unless ( $params{do_edit} or $object->is_saved ) {
        my $error_msg = 'Sorry, did not specify an object to display nor did ' .
                        'you request to edit an object. (Try: "?edit=1" at the ' .
                        'end of your URL.)';
        return $class->search_form({ error_msg => $error_msg });
    }

    # Set both 'object' and the object type equal to the object so the
    # template can use either.

    $params{object} = $params{ $object_type } = $object;
    $R->{page}{title} = $class->MY_OBJECT_FORM_TITLE;

    $class->_show_customize( \%params );
    my $template_name = $class->_template_name(
                                   \%params,
                                   $class->MY_OBJECT_FORM_TEMPLATE( \%params ) );
    return $R->template->handler( {}, \%params, { name => $template_name } );
}



########################################
# MODIFY
########################################

sub edit {
    my ( $class, $p ) = @_;
    unless ( $class->MY_ALLOW_EDIT ) {
        my $error_msg = 'Objects of this type cannot be edited. No action done.';
        return $class->search_form({ error_msg => $error_msg });
    }

    my $R = OpenInteract::Request->instance;
    $R->{page}{return_url} = $class->MY_EDIT_RETURN_URL;

    # Setup default info

    my $object_type  = $class->MY_OBJECT_TYPE;
    my $object_class = $class->MY_OBJECT_CLASS;
    my $id_field     = $object_class->id_field;
    my $object       = eval { $class->fetch_object( $p->{ $id_field }, $id_field ) };

    # If we cannot fetch the object for editing, there's clearly a bad
    # error and we should go back to the search form rather than the
    # display form

    return $class->search_form({ error_msg => $@ }) if ( $@ );

    # Assumption: SEC_LEVEL_WRITE is necessary. (Probably ok.)

    my $is_new       = ( ! $object->is_saved );
    my $object_level = ( $is_new ) ? SEC_LEVEL_WRITE : $object->{tmp_security_level};
    if ( $object_level < SEC_LEVEL_WRITE ) {
        my $error_msg = 'Sorry, you do not have access to modify this ' .
                        'object. No modifications made.';
        return $class->search_form({ error_msg => $error_msg });
    }

    my $old_data = $object->as_data_only;

    # Assign values from the form (specified by MY_EDIT_FIELDS,
    # MY_EDIT_FIELDS_DATE, MY_EDIT_FIELDS_TOGGLED, ...)

    $class->_edit_assign_fields( $object );

    # If after customizing/inspecting the object you want to bail and
    # go somewhere else, return the status 'ERROR' and fill \%opts
    # with information on what you want to do. (Overriding this is
    # quite common -- see POD.)

    my ( $status, $opts ) = $class->_edit_customize( $object, $old_data );
    if ( $status == ERROR ) {
        $opts->{object} = $opts->{ $object_type } = $object;
        return $class->_execute_options( $opts );
    }

    my %show_params = ();
    eval { $object->save };
    if ( $@ ) {
        my $ei = OpenInteract::Error->set( SPOPS::Error->get );
        $R->scrib( 0, "Object ($object_type) save failed: $@ ($ei->{system_msg})" );
        $R->throw({ code => 407 });
        $show_params{error_msg} = "Object modification failed. Error found: $ei->{system_msg}";
    }
    else {
        $show_params{status_msg} = ( $is_new )
                                     ? 'Object created properly.'
                                     : 'Object saved properly with changes.';
    }
    $show_params{ $object_type } = $object;
    my $method = $class->MY_EDIT_DISPLAY_TASK;
    return $class->$method( \%show_params );
}


# Assign values from GET/POST to the object

sub _edit_assign_fields {
    my ( $class, $object ) = @_;
    my $R = OpenInteract::Request->instance;
    my $apr = $R->apache;
    my $object_type = $class->MY_OBJECT_TYPE;

    # Go through normal fields

    foreach my $field ( $class->MY_EDIT_FIELDS ) {
        my $value = $class->_read_field( $apr, $field );
        $R->DEBUG && $R->scrib( 1, "Object edit: ($object_type) ($field) ($value)" );
        $object->{ $field } = $value;
    }

    # Go through toggled (yes/no) fields

    foreach my $field ( $class->MY_EDIT_FIELDS_TOGGLED ) {
        my $value = $class->_read_field_toggled( $apr, $field );
        $R->DEBUG && $R->scrib( 1, "Object edit toggle: ($object_type) ($field) ($value)" );
        $object->{ $field } = $value;
    }

    # Go through date fields

    foreach my $field ( $class->MY_EDIT_FIELDS_DATE ) {
        my $value = $class->_read_field_date( $apr, $field );
        $R->DEBUG && $R->scrib( 1, "Object edit date: ($object_type) ($field) ($value)" );
        $object->{ $field } = $value;
    }
    return ( OK, undef );
}


########################################
# READ FIELDS
########################################

# Just return the value

sub _read_field {
    my ( $class, $apr, $field ) = @_;
    return $apr->param( $field );
}


# If any value, return 'yes', otherwise 'no'

sub _read_field_toggled {
    my ( $class, $apr, $field ) = @_;
    return ( $apr->param( $field ) ) ? 'yes' : 'no';
}


# Default is to interpret YYYYMMDD into YYYY-MM-DD

sub _read_field_date {
    my ( $class, $apr, $field ) = @_;
    my $date_value = $apr->param( $field );
    $date_value =~ s/\D//g;
    my ( $y, $m, $d ) = $date_value =~ /^(\d\d\d\d)(\d\d)(\d\d)$/;
    return undef unless ( $y and $m and $d );
    return join( '-', $y, $m, $d );
}



########################################
# REMOVE
########################################

sub remove {
    my ( $class, $p ) = @_;
    unless ( $class->MY_ALLOW_REMOVE ) {
        my $error_msg = 'Objects of this type cannot be removed from the ' .
                        'database. No modification made.';
        return $class->search_form({ error_msg => $error_msg });
    }

    my $R = OpenInteract::Request->instance;
    my $apr = $R->apache;

    my $object_type  = $class->MY_OBJECT_TYPE;
    my $object_class = $class->MY_OBJECT_CLASS;
    my $id_field     = $class->id_field;
    my $object = eval { $class->fetch_object( $p->{ $id_field }, $id_field ) };

    return $class->search_form({ error_msg => $@ }) if ( $@ );
    unless ( $object->is_saved ) {
        my $error_msg = 'Cannot fetch object for removal. No modifications made.';
        return $class->search_form({ error_msg => $error_msg });
    }


    # Assumption: SEC_LEVEL_WRITE is necessary to remove. (Probably ok.)

    if ( $object->{tmp_security_level} < SEC_LEVEL_WRITE ) {
        my $error_msg = 'Sorry, you do not have access to remove this ' .
                        'object. No modifications made.';
        return $class->search_form({ error_msg => $error_msg });
    }

    my %show_params = ();

    $class->_remove_customize( $object );
    eval { $object->remove };
    if ( $@ ) {
        my $ei = OpenInteract::Error->set( SPOPS::Error->get );
        $R->scrib( 0, "Cannot remove object ($object_type) ($@) ($ei->{system_msg})" );
        $R->throw({ code => 405 });
        $show_params{error_msg} = "Cannot remove object! See error log.";
    }
    else {
        $show_params{status_msg} = 'Object successfully removed.';
    }
    return $class->search_form( \%show_params );
}


########################################
# WIZARD
########################################

# Wizard stuff is pretty simple -- a lot of the difficult stuff is done
# via javascript.


# Start the wizard (simple search form, usually)

sub wizard {
    my ( $class, $p ) = @_;
    unless ( $class->MY_ALLOW_WIZARD ) {
        return '<h1>Error</h1><p>The wizard is not enabled for these objects.</p>';
    }
    $p ||= {};

    my $R = OpenInteract::Request->instance;
    my %params = %{ $p };

    $R->{page}{title} = $class->MY_WIZARD_FORM_TITLE;
    $R->{page}{_simple_}++;

    $class->_wizard_form_customize( \%params );
    my $template_name = $class->_template_name(
                                   \%params,
                                   $class->MY_WIZARD_FORM_TEMPLATE( \%params ) );
    return $R->template->handler( {}, \%params, { name => $template_name } );
}


# Run the search and present results; note that we truncate the
# iterator results with a max of 50, so we don't have any issues with
# paged results or with the user typing 'a' for a last name and
# getting back 100000 items...

sub wizard_search {
    my ( $class, $p ) = @_;
    unless ( $class->MY_ALLOW_WIZARD ) {
        return '<h1>Error</h1><p>The wizard is not enabled for these objects.</p>';
    }
    $p ||= {};

    my $R = OpenInteract::Request->instance;
    my %params = %{ $p };
    $params{iterator} = $class->_search_build_and_run({ max => 50 });

    $R->{page}{title} = $class->MY_WIZARD_RESULTS_TITLE;
    $R->{page}{_simple_}++;

    $class->_wizard_search_customize( \%params );
    my $template_name = $class->_template_name(
                                   \%params,
                                   $class->MY_WIZARD_RESULTS_TEMPLATE( \%params ) );
    return $R->template->handler( {}, \%params, { name => $template_name } );
}



########################################
# TASK FLOW MANIPULATION
########################################

# Find relevant information in \%opts to execute. Potential information:
#  - class, method --> what to execute; if 'method' specified but not
#  'class', we use our own class
#  - action --> Lookup the action and pass in $opts
#  - error_msg: error message to pass around
#  - status_msg: status message to pass around
#  ... Whatever else is passed along

# Currently only used in edit()

sub _execute_options {
    my ( $class, $opts ) = @_;
    my $R = OpenInteract::Request->instance;
    if ( my $method = $opts->{method} ) {
        my $execute_class = $opts->{class} || $class;
        $R->DEBUG && $R->scrib( 1, "Executing ($execute_class) ($method) after bail." );
        return $execute_class->$method( $opts );
    }

    if ( $opts->{action} ) {
        my ( $execute_class, $method ) = $R->lookup_action( $opts->{action} );
        if ( $execute_class and $method ) {
            $R->DEBUG && $R->scrib( 1, "Executing ($execute_class) ($method) ",
                                       "from ($opts->{action} after bail." );
            return $execute_class->$method( $opts );
        }
    }
    return "Cannot find next execute operation.";
}



########################################
# GENERIC OBJECT FETCH
########################################

# ALWAYS RETURNS OBJECT OR DIES

# Retrieve a record: if no $id then return a new one; if $id throw a
# error and die if we cannot fetch; if object with $id not found,
# return a new one. You can always tell if the returned object is new
# by the '->is_saved()' flag (false if new, true if existing)

sub fetch_object {
    my ( $class, $id, @id_field_list ) = @_;
    my $R = OpenInteract::Request->instance;

    unless ( $id ) {
        my $apr = $R->apache;
        foreach my $id_field ( @id_field_list ) {
            $id = $apr->param( $id_field );
            last if ( $id );
        }
    }

    my $object_class = $class->MY_OBJECT_CLASS;

    return $object_class->new  unless ( $id );

    my $object = eval { $object_class->fetch( $id ) };
    unless ( $@ ) {
        $object ||= $object_class->new;
        $class->_fetch_object_customize( $object );
        return $object;
    }

    my $ei = OpenInteract::Error->set( SPOPS::Error->get );
    my $error_msg = undef;
    if ( $ei->{type} eq 'security' ) {
        $error_msg = "Permission denied: you do not have access to view " .
                     "the requested object. ";
    }
    else {
        $R->throw({ code => 404 });
        $error_msg = "Error encountered trying to retrieve object. The " .
                     "error has been logged. "
    }
    die "$error_msg\n";
}


########################################
# OTHER
########################################

# Common template name specification

sub _template_name {
    my ( $class, $p, $default_name ) = @_;
    return $p->{template_name} if ( $p->{template_name} );
    my $package  = $class->MY_PACKAGE;
    my $template = $default_name;
    return join( '::', $package, $template );
}


########################################
# MANDATORY CONFIGURATION
########################################

sub MY_PACKAGE {
    die "Please define class method MY_PACKAGE() in $_[0]\n";
}
sub MY_OBJECT_TYPE {
    die "Please define class method MY_OBJECT_TYPE() in $_[0]\n";
}
sub MY_SEARCH_FIELDS {
    die "Please define class method MY_SEARCH_FIELDS() in $_[0]\n";
}
sub MY_EDIT_FIELDS {
    die "Please define class method MY_EDIT_FIELDS() in $_[0]\n";
}


########################################
# DEFAULT CONFIGURATION
########################################

sub MY_HANDLER_PATH            { return '/' . $_[0]->MY_OBJECT_TYPE }
sub MY_OBJECT_CLASS {
    my $object_type = $_[0]->MY_OBJECT_TYPE;
    return OpenInteract::Request->instance->$object_type();
}

sub MY_ALLOW_SEARCH_FORM         { return 1 }
sub MY_SEARCH_FORM_TITLE         { return 'Search Form' }
sub MY_SEARCH_FORM_TEMPLATE      { return 'search_form' }

sub MY_ALLOW_SEARCH              { return 1 }
sub MY_SEARCH_FIELDS_EXACT       { return () }
sub MY_SEARCH_FIELDS_LEFT_EXACT  { return () }
sub MY_SEARCH_FIELDS_RIGHT_EXACT { return () }
sub MY_SEARCH_TABLE_LINKS        { return () }
sub MY_SEARCH_RESULTS_ORDER      { return undef }
sub MY_SEARCH_RESULTS_PAGED      { return undef }
sub MY_SEARCH_RESULTS_KEY        { return $_[0]->MY_OBJECT_TYPE . '_search_id' }
sub MY_SEARCH_RESULTS_PAGE_SIZE  { return 50 }
sub MY_SEARCH_RESULTS_PAGE_FIELD { return 'pagenum' }
sub MY_SEARCH_RESULTS_TITLE      { return 'Search Results' }
sub MY_SEARCH_RESULTS_TEMPLATE   { return 'search_results' }

sub MY_ALLOW_SHOW                { return 1 }
sub MY_OBJECT_FORM_TITLE         { return 'Object Detail' }
sub MY_OBJECT_FORM_TEMPLATE      { return 'object_form' }

sub MY_ALLOW_EDIT                { return undef }
sub MY_EDIT_RETURN_URL           { return $_[0]->MY_HANDLER_PATH . '/' }
sub MY_EDIT_FIELDS_TOGGLED       { return () }
sub MY_EDIT_FIELDS_DATE          { return () }
sub MY_EDIT_DISPLAY_TASK         { return 'show' }

sub MY_ALLOW_REMOVE              { return undef }

sub MY_ALLOW_WIZARD              { return undef }
sub MY_WIZARD_FORM_TITLE         { return 'Wizard: Search' }
sub MY_WIZARD_FORM_TEMPLATE      { return 'wizard_form' }
sub MY_WIZARD_RESULTS_TITLE      { return 'Wizard: Results' }
sub MY_WIZARD_RESULTS_TEMPLATE   { return 'wizard_results' }


########################################
# CUSTOMIZATION INTERFACE
########################################

# Template param modifications
sub _search_form_customize        { return 1 }
sub _search_customize             { return 1 }
sub _show_customize               { return 1 }
sub _wizard_form_customize        { return 1 }
sub _wizard_search_customize      { return 1 }

# Criteria/Object modifications
sub _search_criteria_customize    { return $_[1] }
sub _search_build_where_customize { return 1 }
sub _fetch_object_customize       { return $_[1] }
sub _edit_customize               { return ( OK, undef ) }



1;

__END__

=pod

=head1 NAME

OpenInteract::CommonHander - Base class that with a few configuration items takes care of many common operations

=head1 SYNOPSIS

 package MySite::Handler::MyTask;

 use strict;
 use OpenInteract::CommonHandler;

 @MySite::Handler::MyTask::ISA = qw( OpenInteract::CommonHandler );

 sub MY_PACKAGE                 { return 'mytask' }
 sub MY_HANDLER_PATH            { return '/MyTask' }
 sub MY_OBJECT_TYPE             { return 'myobject' }
 sub MY_OBJECT_CLASS            {
     return OpenInteract::Request->instance->myobject
 }
 sub MY_SEARCH_FIELDS {
     return qw( name type quantity purpose_in_life that_other.object_name )
 }
 sub MY_SEARCH_TABLE_LINKS      { return ( that_other => 'myobject_id' ) }
 sub MY_SEARCH_FORM_TITLE       { return 'Search for Thingies' }
 sub MY_SEARCH_FORM_TEMPLATE    { return 'search_form' }
 sub MY_SEARCH_RESULTS_TITLE    { return 'Thingy Search Results' }
 sub MY_SEARCH_RESULTS_TEMPLATE { return 'search_results' }
 sub MY_OBJECT_FORM_TITLE       { return 'Thingy Detail' }
 sub MY_OBJECT_FORM_TEMPLATE    { return 'form' }
 sub MY_EDIT_RETURN_URL         { return '/Thingy/search_form/' }
 sub MY_EDIT_FIELDS             {
     return qw( myobject_id name type quantity purpose_in_life )
 }
 sub MY_EDIT_FIELDS_TOGGLED     { return qw( is_indoctrinated ) }
 sub MY_EDIT_FIELDS_DATE        { return qw( birth_date ) }
 sub MY_ALLOW_SEARCH_FORM       { return 1 }
 sub MY_ALLOW_SEARCH            { return 1 }
 sub MY_ALLOW_SHOW              { return 1 }
 sub MY_ALLOW_EDIT              { return 1 }
 sub MY_ALLOW_REMOVE            { return undef }
 sub MY_ALLOW_WIZARD            { return undef }

 # We present dates to the user in three separate fields

 sub _read_field_date {
     my ( $class, $apr, $field ) = @_;
     return join( '-', $apr->param( $field . '_year' ),
                       $apr->param( $field . '_month' ),
                       $apr->param( $field . '_day' ) );
 }

 1;

=head1 DESCRIPTION

This class implements most of the common functionality required for
finding and displaying multiple objects, viewing a particular object,
making changes to it and removing it. And you just need to modify a
few configuration methods so that it knows what to save, where to save
it and what type of things you are doing.

This class is meant for the bread-and-butter of many web applications
-- enable a user to find, view and edit a particular object. Why keep
writing these parts again and again? And if you have more extensive
needs, it is very easy to still let this class do most of the work and
you can concentrate on the differences, making more maintainable code
and more sane programmers.

=head1 TASK METHODS

This class supplies the following methods for direct use as
actions. If you override one, you need to supply content. You can, of
course, add your own methods (e.g., a 'summary()' method which
displays the object information in static detail along with related
objects).

B<search_form()>

Display a search form.

B<search()>

Execute a search and display results.

B<show()>

Display a single record.

B<edit()>

Modify a single record.

B<remove()>

Remove a single record.

B<wizard()>

Start the search wizard (generally display a search criteria page).

B<wizard_search()>

Run the search wizard and display the results.

=head1 CUSTOM BEHAVIOR

Every task allows you to customize an object, means for finding
objects or the parameters passed to the template. Each of these
methods take two arguments -- the first argument is always the class,
and the second is either the information (object, search criteria) to
be modified or a hashref of template parameters.

=head2 Template Customizations

These methods allow you to step in and modify any template parameters
that you like.

You can modify the template that any of these will use by setting the
parameter 'template_name'.

B<_search_form_customize( \%template_params )>

Typically there are no parameters to set/manipulate except possibly
'error_msg' or 'status_msg' if called from other methods.

B<_search_customize( \%template_params )>

If you are not using paged results there is only the parameter
'iterator' set. If you use paged results, then there is 'iterator' as
well as:

=over 4

=item *

C<page_number_field>

=item *

C<current_page>

=item *

C<total_pages>

=item *

C<total_hits>

=item *

C<search_id>

=item *

C<search_results_key>

=back

B<_show_customize( \%template_params )>

Typically there are only the parameters 'object' and C<MY_OBJECT_TYPE>
set to the same value.

=head2 Data Customization

B<_search_criteria_customize( \%search_criteria )>

Modify the items in C<\%search_criteria> as necessary. The format is
simple: a key is a fully-qualified (table.field) fieldname, and its
value is either a scalar or arrayref depending on whether multiple
values were passed.

Returns: hashref of search criteria.

For instance, say we wanted to restrict searches to all objects with
an 'active' property of 'yes':

 sub _search_criteria_customize {
    my ( $class, $criteria ) = @_;
    $criteria->{'mytable.active'} = 'yes';
    return $criteria;
 }

Easy! Other possibilities include selecting objects based on qualities
of the user -- say certain objects should only be included in a search
if the user is a member of a particular group. Since C<$R> is
available to you, it is simple to check whether the user is a member
of a group and make necessary modifications.

Note that you must use the fully-qualified 'table.field' format for
the criteria key, or the criterion will be discarded.

The method should always return the hashref of criteria. Failure to do
so will likely retrieve all objects in the database, which is
frequently a Bad Thing.

B<_search_build_where_customize( \@tables, \@where, \@values )>

Allows you to hand-modify the WHERE clause that will be used for
searching. If you override this method, you will be passed three
arguments:

=over 4

=item 1.

An arrayref of tables that are used in the WHERE clause -- they become
the FROM clause of our search SELECT. If you add a JOIN or other
clause that depends on a separate table then be sure to add it here --
otherwise the search will fail mightily.

=item 2.

An arrayref of operations that will be joined together with 'AND'
before being passed to the C<search()> method.

=item 3.

An arrayref of values that will be plugged into the operations.

=back

This might seem a little confusing, but as usual it is easier to show
than tell. For example, we want to allow the user to select a date in
a search form and find all items one week after and one week before
that date.

 sub _search_build_where_customize {
     my ( $class, $table, $where, $value ) = @_;
     my $R = OpenInteract::Request->instance;
     my $search_date = $class->_read_field_date( 'pivot_date' );
     push @{ $where },
       "( TO_DAYS( ? ) BETWEEN ( TO_DAYS( pivot_date ) + 7 ) " .
       "AND ( TO_DAYS( pivot_date ) - 7 ) )";
     push @{ $value }, $search_date;
 }

B<_fetch_object_customize( $object )>

Called just before an object is returned via C<fetch_object()>. You
have the option of looking at C<$object> and making any necessary
modifications.

Note that C<fetch_object()> is not called when returning objects from
a search, only when manipulating a single object with C<show()>,
C<edit()> or C<remove()>.

B<_edit_customize( $object, \%old_data )>

Called just before an object is saved to the datastore. This is most
useful to perform any custom data retrieval, data manipulation or
validation. Data present in the object before any modifications is
passed as a hashref in the second argument.

Return value is a two-element list: the first is the status -- either
'OK' or 'ERROR' as exported by this module. The second is only used if
the status is 'ERROR' -- it should be a hashref of options for
executing the next step on an error.

For instance, if you want to do data validation you might do something
like:

 package My::Handler::MyHander;

 use OpenInteract::CommonHandler qw( OK ERROR );

 my @required_field = qw( name quest favorite_color );
 my %required_label = ( name => 'Name', quest => 'Quest',
                        favorite_color => 'Favorite Color' );

 # ... Override the various configuration routines ...

 sub _edit_customize {
     my ( $class, $object, $old_data ) = @_;
     my @msg = ();
     foreach my $field ( @required_field ) {
        unless ( $object->{ $field } ) {
            push @msg, "$required_label{ $field } is a required field. " .
                       "Please enter data for it.";
        }
     }
     return ( OK, undef ) unless ( scalar @msg );
     return ( ERROR, { error_msg => join( "<br>\n", @msg ),
                       method    => 'show' } );
 }

So if any of the required fields are not filled in, the method returns
'ERROR' and a hashref with the method to execute on error, in this
case 'show' to redisplay the same object along with the error message
to display.

You can specify an action to execute in one of three ways:

=over 4

=item *

B<method>: Calls C<$method()> in the current class.

=item *

B<class>, B<method>: Calls C<$class-E<gt>$method()>.

=item *

B<action>: Calls the method and class specified by C<$action>.

=back

B<_remove_customize( $object )>

Called just before an object is removed from the datastore.

=head2 Wizards

This class contains some simple support for search wizards. With such
a wizard you can use OpenInteract in conjunction with JavaScript to
implement a 'Find...' widget so you can link one object to another
easily.

#TODO: Add more here as this gets completed.

=head1 INTERNAL BEHAVIOR

B<_search_build_criteria()>

Scans the GET/POST for relevant (as specified by C<MY_SEARCH_FIELDS>)
search criteria and puts them into a hashref. Multiple values are put
into an arrayref, single values into a scalar.

Returns: Hashref of search fields and values entered.

Depends on:

C<MY_SEARCH_FIELDS>

We call C<_search_criteria_customize()> on the criteria just before
they are passed back to the caller.

B<_search_build_where_clause( \%search_criteria )>

Builds a WHERE clause suitable for a SQL SELECT statement. It can
handle table links (with some help by you).

Returns: Three-value array: the first value is an arrayref of tables
used in the search, including the object table itself; the second
value is the actual WHERE clause, the third value is an arrayref of
the values used in the WHERE clause.

Depends on:

C<MY_OBJECT_CLASS>

C<MY_SEARCH_FIELDS_EXACT>

C<MY_SEARCH_TABLE_LINKS>

We call C<_search_build_where_customize()> with various information
just before returning it.

B<_edit_assign_fields( $object )>

If you override this method you will have to read all the information
from the GET/POST to the object. See below C<FIELD VALUE BEHAVIOR> for
useful methods in doing this.

=head1 OBJECT BEHAVIOR

B<fetch_object( $id, [ $id_field, $id_field, ... ] )>

This method is slightly different than the rest. It retrieves a
particular object for you, given either the ID value in C<$id> or
given the ID value found in the first one of C<$id_field> that is
defined in the GET/POST.

Returns: This method B<always> returns an object. If it does not
return an object it will C<die()>. If an object is not retrieved due
to an ID value not being found or a matching object not being found, a
B<new> (empty) object is returned.

Depends on:

C<MY_OBJECT_CLASS>

=head1 FIELD VALUE BEHAVIOR

B<_read_field( $apache_request, $field_name )>

Just returns the value of C<$field_name> as read from the GET/POST.

B<_read_field_toggled( $apache_request, $field_name )>

If C<$field_name> is set to a true value, returns 'yes', otherwise
returns 'no'.

B<_read_field_date( $apache_request, $field_name )>

By default, reads in the value of C<$field_name> which it assumes to
be in the format 'YYYYMMDD' and puts it into 'YYYY-MM-DD' format,
which it returns. This is probably the method you will most often
override, depending on how you present dates to your users.

=head1 CONFIGURATION METHODS

B<MY_PACKAGE()> ($)

Mandatory. Returns package name.

B<MY_OBJECT_TYPE()> ($)

Mandatory. Returns object type (e.g., 'user', 'news', etc.)

B<MY_SEARCH_FIELDS()> (@)

Mandatory. Returns fields used to build search.

B<MY_EDIT_FIELDS()> (@)

Mandatory. Returns fields used to edit.

B<MY_HANDLER_PATH()> ($)

Optional. Returns path of handler.

Default: '/' . MY_OBJECT_TYPE

B<MY_OBJECT_CLASS()> ($)

Optional. Returns object class.

Default: Gets object class from C<$R> using C<MY_OBJECT_TYPE>.

B<MY_SEARCH_FIELDS_EXACT> (@)

Optional. Returns fields from C<MY_SEARCH_FIELDS> that must be an
exact match.

This is used in C<_search_build_where_clause()>. If the field being
searched is an exact match, we use '=' as a search test.

Otherwise we use 'LIKE' and, if the field is not in
C<MY_SEARCH_FIELDS_LEFT_EXACT> or C<MY_SEARCH_FIELDS_RIGHT_EXACT>,
wrap the value in '%'.

If you need other custom behavior, do not include the field in
C<MY_SEARCH_FIELDS> and use C<_search_build_where_customize()> to set.

No default.

B<MY_SEARCH_FIELDS_LEFT_EXACT> (@)

Optional. Returns fields from C<MY_SEARCH_FIELDS> that must match
exactly on the left-hand side. This basically sets up:

 $fieldname LIKE "$fieldvalue%"

No default.

B<MY_SEARCH_FIELDS_RIGHT_EXACT> (@)

Optional. Returns fields from C<MY_SEARCH_FIELDS> that must match
exactly on the right-hand side. This sets up:

 $fieldname LIKE "%$fieldvalue"

No default.

B<MY_SEARCH_TABLE_LINKS> (%)

Optional. Returns table name => ID field mapping used to build WHERE
clauses that JOIN multiple tables when executing a search.

A key is a table name, and the value enables us to build a join clause
to link table specified in the key to the table containing the object
being searched. The value is either a scalar or an arrayref.

If a scalar, the value is just the ID field in the destination table
that the ID value in the object maps to:

  sub MY_SEARCH_TABLE_LINKS {
      return ( address => 'user_id' ) }

This means that the table 'address' contains the field 'user_id' which
the ID of our object matches.

If the value is an arrayref that means one of two things, depending on
the number of elements in the arrayref.

First, a two-element arrayref. This means we are have a non-key field
in our object which matches up with a key field in another object.

The elements are:

 0: Fieldname in the object
 1: Fieldname in the other table

(Frequently these are the same, but they do not have to be.)

For instance, say we have a table of people records and a table of
phone log records. Each phone log record has a 'person_id' field, but
we want to find all the phone log records generated by people who have
a last name with 'mith' in it.

 sub MY_SEARCH_TABLE_LINKS {
     return ( person => [ 'person_id', 'person_id' ] ) }

Which will generate a WHERE clause like:

  WHERE person.last_name LIKE '%mith%'
    AND phonelog.person_id = person.person_id

Second, a three-element arrayref. This means we are using a linking
table to do the join. The values of the arrayref are:

 0: ID field matching the object ID field on the linking table
 1: Name of the linking table
 2: Name of the ID field on the destination table

So you could have the setup:

  user (user_id) <--> user_group (user_id, group_id) <--> group (group_id)

and:

  sub MY_SEARCH_TABLE_LINKS { 
      return ( group => [ 'user_id', 'user_group', 'group_id' ] ) }

And searching for a user by a group name with 'admin' would give:

  WHERE group.name LIKE '%admin%'
    AND group.group_id = user_group.group_id
    AND user_group.user_id = user.user_id

No default.

B<MY_SEARCH_RESULTS_PAGED> (bool)

Optional. Set to a true value to enable paged results, meaning that
search results will come back in groups of
B<MY_SEARCH_RESULTS_PAGE_SIZE>. We use the methods in 'results_manage'
to accomplish this.

Default: false.

B<MY_SEARCH_RESULTS_PAGE_SIZE> ($)

Optional. If B<MY_SEARCH_RESULTS_PAGED> is set to a true value we
output pages of this size.

Default: 50

B<MY_SEARCH_RESULTS_PAGED> (bool)

Optional. Set to a true value to enable paged results, meaning that
search results will come back in groups of
B<MY_SEARCH_RESULTS_PAGE_SIZE>. We use the methods in 'results_manage'
to accomplish this.

Default: false.

B<MY_SEARCH_RESULTS_KEY> ($)

Optional. If B<MY_SEARCH_RESULTS_PAGED> is true this routine will
generate a key under which you will save the ID to get your persisted
search results. We make the search ID accessible in the template
parameters under this name as well as 'search_id'.

Default: C<MY_OBJECT_CLASS> . '_search_id'

B<MY_SEARCH_RESULTS_PAGE_SIZE> ($)

Optional. If B<MY_SEARCH_RESULTS_PAGED> is true we output pages of
this size.

Default: 50

B<MY_SEARCH_RESULTS_PAGE_FIELD> ($)

Optional. If B<MY_SEARCH_RESULTS_PAGED> is true this is the parameter
we will check to see what page number of the results the user is
requesting.

Default: 'pagenum'.

B<MY_SEARCH_FORM_TITLE> ($)

Optional. Title of search form.

Default: 'Search Form'

B<MY_SEARCH_FORM_TEMPLATE()> ($)

Optional. Search form template name.

Default: 'search_form'

B<MY_SEARCH_RESULTS_TITLE()> ($)

Optional. Title of search results page.

Default: 'Search Results'

B<MY_SEARCH_RESULTS_TEMPLATE()> ($)

Optional. Search results template name.

Default: 'search_results'

B<MY_OBJECT_FORM_TITLE()> ($)

Optional. Title of object editing page.

Default: 'Object Detail'

B<MY_OBJECT_FORM_TEMPLATE()> ($)

Optional. Object form template name.

Default: 'object_form'

B<MY_EDIT_RETURN_URL()> ($)

Optional. URL to use as return when displaying the 'edit' page. (If
you do not define this weird things can happen if users logout from
the editing page.)

Default: MY_HANDLER_PATH . '/'

B<MY_EDIT_FIELDS_TOGGLED()> (@)

Optional. List of fields that are either 'yes' or 'no'.

No default

B<MY_EDIT_FIELDS_DATE()> (@)

Optional. List of fields that are dates. If users are editing raw
dates and the field value does not need to be manipulated before
entering the database, then just keep such fields in C<MY_EDIT_FIELDS>
since they do not need to be treated differently.

No default

B<MY_EDIT_DISPLAY_TASK()> ($)

Optional. Task we should execute after we have edited the record.

Default 'show' (re-displays the form you just edited with a status
message)

B<MY_ALLOW_SEARCH_FORM()> (bool)

Optional. Should the search form be viewed?

Default: true

B<MY_ALLOW_SEARCH()> (bool)

Optional. Should searches be allowed?

Default: true

B<MY_ALLOW_SHOW()> (bool)

Optional. Should object display be allowed?

Default: true

B<MY_ALLOW_EDIT()> (bool)

Optional. Should edits be allowed?

Default: false

B<MY_ALLOW_REMOVE()> (bool)

Optional. Should removals be allowed?

Default: false

=head1 BUGS

None known.

=head1 TO DO

B<Finish documenting>

Document customization methods and give examples.

B<Add simple listing>

Add an optional 'listing' method which allows you to just list all
objects of a particular type.

B<GenericDispatcher items available thru methods>

Modify the GenericDispatcher so that things like security information,
forbidden methods, etc. are available through class methods we can
override. We might hold off on this until we implement the
ActionDispatcher -- no reason to modify something we will
remove/modify soon anyway...

=head1 SEE ALSO

L<OpenInteract::Handler::GenericDispatcher|OpenInteract::Handler::GenericDispatcher>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
