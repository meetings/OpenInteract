package OpenInteract2::SQLInstall;

# $Id: SQLInstall.pm,v 1.12 2003/07/12 21:11:20 lachoy Exp $

use strict;
use base qw( Class::Accessor );
use Log::Log4perl            qw( get_logger );
use DateTime;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use SPOPS::Import;

$OpenInteract2::SQLInstall::VERSION  = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( package );
OpenInteract2::SQLInstall->mk_accessors( @FIELDS );

my $STRUCT_DIR = 'struct';
my $DATA_DIR   = 'data';

sub new_from_package {
    my ( $class, $package ) = @_;
    my $log = get_logger( LOG_INIT );

    unless ( UNIVERSAL::isa( $package, 'OpenInteract2::Package' ) ) {
        oi_error "Cannot create SQL installer from item that is not a package";
    }
    my $install_class = $package->config->sql_installer;
    unless ( $install_class ) {
        $log->warn( "No SQL installer specified in config for ",
                    $package->name );
        return undef;
    }
    eval "require $install_class";
    if ( $@ ) {
        oi_error "Failed to include SQL install class [$install_class] ",
                 "specified in package ", $package->full_name;
    }
    return $install_class->new({ package => $package });
}

sub new {
    my ( $class, $params ) = @_;
    my $self = bless( { _status    => {},
                        _error     => {},
                        _statement => {},
                      }, $class );
    for ( @FIELDS ) {
        $self->$_( $params->{ $_ } ) if ( $params->{ $_ } );
    }
    $self->init( $params );
    return $self;
}

sub init {}

########################################
# GET/SET ITEM STATE TRACKING

sub get_status {
    my ( $self, $file ) = @_;
    if ( $file ) {
        return $self->{_status}{ $file };
    }
    my @status = ();
    foreach my $status_file ( sort keys %{ $self->{_status} } ) {
        if ( $self->{_status}{ $status_file } ) {
            push @status, { is_ok    => 'yes',
                            filename => $status_file };
        }
        else {
            push @status, { is_ok    => 'no',
                            filename => $status_file,
                            message  => $self->get_error( $status_file ) };
        }
    }
    return @status;
}

sub get_error {
    my ( $self, $file ) = @_;
    return $self->{_error}{ $file };
}

sub get_statement {
    my ( $self, $file ) = @_;
    return ( $self->{_statement}{ $file } )
             ? $self->{_statement}{ $file } : 'n/a';
}

sub get_datasource {
    my ( $self, $file ) = @_;
    return ( $self->{_datasource}{ $file } )
             ? $self->{_datasource}{ $file } : 'n/a';
}


# These are private

sub _set_status {
    my ( $self, $file, $status ) = @_;
    $self->{_status}{ $file } = $status;
}

sub _set_error {
    my ( $self, $file, $error ) = @_;
    $self->{_error}{ $file } = $error;
}

sub _set_statement {
    my ( $self, $file, $statement ) = @_;
    $self->{_statement}{ $file } = $statement;
}

sub _set_datasource {
    my ( $self, $file, $ds ) = @_;
    $self->{_datasource}{ $file } = $ds;
}

# Set most everything at once (normally done with errors)

sub _set_state {
    my ( $self, $file, $status, $error, $statement ) = @_;
    $self->{_status}{ $file }    = $status;
    $self->{_error}{ $file }     = $error;
    $self->{_statement}{ $file } = $statement;
}


########################################
# SUBCLASSES OVERRIDE

sub get_structure_set  { return undef }
sub get_structure_file { return undef }
sub get_data_file      { return undef }
sub get_security_file  { return undef }



########################################
# INSTALL

sub install_all {
    my ( $self ) = @_;
    unless ( ref $self->package eq 'OpenInteract2::Package' ) {
        oi_error 'Cannot install without first setting package';
    }
    $self->install_structure;
    $self->install_data;
    $self->install_security;
}


########################################
# INSTALL STRUCTURE

sub install_structure {
    my ( $self ) = @_;
    my $pkg = $self->package;
    unless ( ref $pkg eq 'OpenInteract2::Package' ) {
        oi_error 'Cannot install structure without first setting package';
    }

    # Note: We can't have the importer send the SQL directly to the
    # database since we may create tables that don't correspond to
    # SPOPS objects.

    my $importer = SPOPS::Import->new( 'table' );
    $importer->return_only(1);
    $importer->transforms( [ \&_transform_usertype,
                             \&_transform_grouptype ] );

    my @sets = $self->_massage_arrayref( $self->get_structure_set );

STRUCTURE:
    foreach my $structure_set ( @sets ) {
        my ( $ds_name, $ds_info, $ds );
        eval {
            if ( $structure_set eq 'system' ) {
                $ds_name = CTX->lookup_system_datasource_name;
            }
            elsif ( $structure_set =~ /^datasource:\s*(\w+)\s*$/ ) {
                $ds_name = $1;
            }
            else {
                unless ( exists CTX->spops_config->{ $structure_set } ) {
                    die "Set '$structure_set' is not a valid SPOPS key.\n";
                }
                $ds_name = CTX->spops_config->{ $structure_set }{datasource};
            }
            $ds_info = CTX->datasource_manager->get_datasource_info( $ds_name );
            $ds = CTX->datasource( $ds_name );
        };
        if ( $@ ) {
            $self->_set_state( "Set: $structure_set",
                               undef,
                               "Error creating datasource: $@",
                               undef );
            next STRUCTURE;
        }
        my $driver_name = $ds_info->{sql_install}
                          || $ds_info->{driver_name};
        my @files = $self->_massage_arrayref(
                              $self->get_structure_file( $structure_set,
                                                         $driver_name ) );
        foreach my $structure_file ( @files ) {
            $self->_set_datasource( $structure_file, $ds_name );

            # XXX: Need to use File::Spec here?
            my ( $table_sql );
            eval {
                $table_sql = $pkg->read_file(
                                   "$STRUCT_DIR/$structure_file" );
            };
            if ( $@ or ! $table_sql ) {
                my $error = $@ ||  "File cannot be found or it is empty";
                $self->_set_state( $structure_file,
                                   undef, $error, undef );
                next STRUCTURE;
            }

            $importer->database_type( $driver_name );
            $importer->data( $table_sql );
            my $full_table_sql = $importer->run;
            $self->_set_statement( $structure_file, $full_table_sql );
            eval { $ds->do( $full_table_sql ) };
            if ( $@ ) {
                $self->_set_status( $structure_file, undef );
                $self->_set_error( $structure_file, $@ );
            }
            else {
                $self->_set_status( $structure_file, 1 );
                $self->_set_error( $structure_file, undef );
            }
        }
    }
    return $self;
}


sub _transform_usertype {
    my ( $self, $sql ) = @_;
    my $type = CTX->server_config->{id}{user_type} || 'int';
    if ( $type eq 'char' ) {
        my $size = CTX->server_config->{id}{user_size} || 25;
        $$sql =~ s/%%USERID_TYPE%%/VARCHAR($size)/g;
    }
    elsif ( $type eq 'int' ) {
        $$sql =~ s/%%USERID_TYPE%%/INT/g;
    }
    else {
        oi_error "Given user type '$type' invalid. Only available ",
                 "types are 'int' and 'char'.";
    }
}


sub _transform_grouptype {
    my ( $self, $sql ) = @_;
    my $type = CTX->server_config->{id}{group_type} || 'int';
    if ( $type eq 'char' ) {
        my $size = CTX->server_config->{id}{group_size} || 25;
        $$sql =~ s/%%GROUPID_TYPE%%/VARCHAR($size)/g;
    }
    elsif ( $type eq 'int' ) {
        $$sql =~ s/%%GROUPID_TYPE%%/INT/g;
    }
    else {
        oi_error "Given group type '$type' invalid. Only available ",
                 "types are 'int' and 'char'.";
    }
}


########################################
# INSTALL DATA/SECURITY


sub install_data {
    my ( $self ) = @_;
    unless ( ref $self->package eq 'OpenInteract2::Package' ) {
        oi_error 'Cannot install data without first setting package';
    }
    my @files = $self->_massage_arrayref( $self->get_data_file );
    return unless ( scalar @files );
    $self->process_data_file( @files );
}


sub install_security {
    my ( $self ) = @_;
    unless ( ref $self->package eq 'OpenInteract2::Package' ) {
        oi_error 'Cannot install data without first setting package';
    }
    my @files = $self->_massage_arrayref( $self->get_security_file );
    return unless ( scalar @files );
    $self->process_data_file( @files );
}


sub process_data_file {
    my ( $self, @files ) = @_;
    my $pkg = $self->package;

DATAFILE:
    foreach my $data_file ( @files ) {
        my $data_text = $pkg->read_file(
                                   "$DATA_DIR/$data_file" );
        my ( $data_struct );
        {
            no strict 'vars';
            $data_struct = eval $data_text;
            if ( $@ ) {
                $self->_set_state( $data_file,
                                   undef,
                                   "Invalid Perl data structure: $@",
                                   undef );
                next DATAFILE;
            }
        }

        my $import_type = $data_struct->[0]->{import_type};
        unless ( $import_type ) {
            $self->_set_state( $data_file,
                               undef,
                               "No 'import_type' specified, cannot process",
                               undef );
            next DATAFILE;
        }
        my ( $importer );
        eval {
            $importer = SPOPS::Import->new( $import_type )
                                     ->assign_raw_data( $data_struct );
        };
        if ( $@ ) {
            $self->_set_state( $data_file,
                               undef,
                               "Failed to create importer: $@",
                               undef );
            next DATAFILE;
        }

        # XXX: Need to modify this to handle Import::DBI::Data
        # format. Allow packager to specify into which datasource we
        # should stick the data (e.g., 'system', 'datasource: foo' or
        # an spops-key)

        my ( $ds_name );
        if ( $import_type eq 'object' ) {
            my $spops_class = $data_struct->[0]->{spops_class};
            $ds_name = $spops_class->CONFIG->{datasource};
        }
        elsif ( $import_type eq 'dbdata' ) {
            my $ds_lookup = $data_struct->[0]->{datasource_pointer};
            if ( $ds_lookup eq 'system' ) {
                $ds_name = CTX->lookup_system_datasource_name;
            }
            elsif ( $ds_lookup =~ /^datasource:\s*(\w+)\s*$/ ) {
                $ds_name = $1;
            }
            else {
                unless ( exists CTX->spops_config->{ $ds_lookup } ) {
                    $self->_set_state( undef,
                                       "Cannot find datasource for pointer '$ds_lookup'",
                                       undef );
                    next DATAFILE;
                }
                $ds_name = CTX->spops_config->{ $ds_lookup }{datasource};
            }

            # Now that we have the datasource name, get the actual
            # datasource

            $importer->db( CTX->datasource( $ds_name ) );
        }

        $self->_set_datasource( $data_file, $ds_name );
        $self->transform_data( $importer );
        my $file_status = $importer->run;

        my $file_ok = 1;
        my @errors = ();
        my @ok     = ();
        foreach my $status ( @{ $file_status } ) {
            if ( $status->[0] and ref $status->[1] ne 'ARRAY') {
                push @ok, $status->[1]->id;
            }
            elsif ( $status->[0] ) {
                push @ok, $status->[1][0]; # assume the first item is an ID...
            }
            else {
                $file_ok = 0;
                push @errors, $status->[2];
            }
        }
        my $insert_ok = join( ', ', @ok );
        if ( $file_ok ) {
            $self->_set_state( $data_file,
                               1, undef, "Inserted: $insert_ok" );
        }
        else {
            $self->_set_state( $data_file,
                               undef,
                               join( "\n", @errors ),
                               "Inserted: $insert_ok" );
        }
    }
}


sub transform_data {
    my ( $self, $importer ) = @_;
    my $metadata = $importer->extra_metadata;
    my $field_ord = $importer->fields_as_hashref;
    foreach my $data ( @{ $importer->data } ) {
        if ( $metadata->{transform_default} ) {
            for ( @{ $metadata->{transform_default} } ) {
                my $idx = $field_ord->{ $_ };
                $data->[ $idx ] =
                        $self->_transform_default( $data->[ $idx ] );
            }
        }
        if ( $metadata->{transform_now} ) {
            for ( @{ $metadata->{transform_now} } ) {
                my $idx = $field_ord->{ $_ };
                $data->[ $idx ] =
                        $self->_transform_now( $data->[ $idx ] );
            }
        }
    }
}


sub _transform_default {
    my ( $self, $value ) = @_;
    my $defaults = CTX->server_config->{default_objects};
    return ( $defaults->{ $value } )
             ? $defaults->{ $value } : $value;
}


sub _transform_now {
    my ( $self ) = @_;
    return DateTime->now->strftime( '%Y-%m-%d %T' );
}


########################################
# UTILS

sub _massage_arrayref {
    my ( $self, $files ) = @_;
    return () unless ( $files );
    return ( ref $files eq 'ARRAY' ) ? @{ $files } : ( $files );
}

1;

__END__

=head1 NAME

OpenInteract2::SQLInstall -- Dispatcher for installing various SQL data from packages to database

=head1 SYNOPSIS

 # PACKAGE AUTHORS
 # Define a SQLInstaller for your package
 
 package OpenInteract2::SQLInstall::MyPackage;
 
 use strict;
 use base qw( OpenInteract2::SQLInstall );
 
 my %TABLES = (
    sybase  => [ 'myobj_sybase.sql' ],
    oracle  => [ 'myobj_oracle.sql', 'myobj_sequence.sql' ],
    default => [ 'myobj.sql' ],
 );
 
 # We only define one object in this package
 sub get_structure_set {
     return 'myobj';
 }
 
 # Since we only have one set we can ignore it
 sub get_structure_file {
     my ( $self, $set, $type ) = @_;
     return 'myobj_sybase.sql'                           if ( $type eq 'Sybase' );
     return [ 'myobj_oracle.sql', 'myobj_sequence.sql' ] if ( $type eq 'Oracle' );
     return 'myobj.sql';
 }
 
 # INSTALLER USERS
 # Use this class in a separate program
 use OpenInteract2::Context qw( CTX );
 use OpenInteract2::SQLInstall;
 
 my $package = CTX->repository->fetch_package( 'mypackage' );;
 my $installer = OpenInteract2::SQLInstall->new_from_package( $package );
 
 # Do one at a time
 $installer->install_structure;
 $installer->install_data;
 $installer->install_security;
 
 # ... or all at once
 $installer->install_all;

=head1 DESCRIPTION

One of the difficulties with developing an application that can
potentially work with so many different databases is that it needs to
work with so many different databases. Many of the differences among
databases are dealt with by the amazing L<DBI|DBI> module, but enough
remain to warrant some thought.

This module serves two audiences:

=over 4

=item 1.

The user of OpenInteract who wants to get packages, run a few commands
and have them simply work.

=item 2.

The developer of OpenInteract packages who wants to develop for as
many databases as possible without too much of a hassle.

=back

This module provides tools for both. The first group (users) does not
need to concern itself with how this module works -- running the
various C<oi2_manage> commands should be sufficient.

However, OpenInteract developers need a keen understanding of how
things work. This whole endeavor is a work-in-progress -- things work,
but there will certainly be new challenges brought on by the wide
variety of applications for which OpenInteract can be used.

=head1 USERS: HOW TO MAKE IT HAPPEN

Every package has a module that has a handful of procedures specified
in such a way that OpenInteract knows what to call and for which
database. Generally, all you need to deal with is the wrapper provided
by the C<oi2_manage> program. For instance:

 oi2_manage install_sql --website_dir=/home/httpd/myOI --package=mypackage

This will install all of the structures, data and security objects
necessary for the package 'mypackage' to function. You can also
install the pieces individually:

 oi2_manage install_sql_structure --website_dir=/home/httpd/myOI --package=mypackage
 oi2_manage install_sql_data --website_dir=/home/httpd/myOI --package=mypackage
 oi2_manage install_sql_security --website_dir=/home/httpd/myOI --package=mypackage

As long as you have specified your databsources properly in your
C<conf/server.ini> file and enabled any custom associations between
the datasources and SPOPS objects, everything should flow smooth as
silk.

=head1 DEVELOPERS: CODING

The SQL installation program of OpenInteract is a kind of mini
framework -- you have the freedom to do anything you like in the
handlers for your package. But OpenInteract provides a number of tools
for you as well.

=head2 Subclassing: Methods to override

First, the basics. Here's the scoop on what you can override:

B<init( \%params )>

Called from C<new()> just before returning the object. All items in
C<\%params> that are object fields have already been set in the
object, the other entries remain untouched.

If there's a problem you should C<die> with a useful error message.

Returns: nothing.

B<install_structure()>

If you have needs that declaration cannot fill, you can install the
structures yourself. You have access to the full
L<OpenInteract2::Context|OpenInteract2::Context> object so you can get
datasources, lookup SPOPS object information, etc. (See more in
section on customization below.)

B<get_structure_set()>

Returns a set of keys used for matching up structure files with
datasources. (A structure file normally delineates a single table but
can also describe other objects, like sequences, generators or even
indices.) The return value is either a simple scalar or an
arrayref. Each member must be:

=over 4

=item B<'system'>

For structures to be installed to the OI system database.

=item B<'datasource: NAME'>

For structures to be installed to a particular datasource 'NAME'. This
is useful for tables that can be configured for a particular
datasource but aren't an SPOPS object. The method should lookup the
proper datasource from the server configuration or some other
resource.

=item B<spops-key>

For structures to be installed in the datasource used by C<spops-key>.

=back

So if you have two objects defined in your package you might have
something like:

 sub get_structure_set {
     return [ 'objectA', 'objectB' ];
 }

Where 'objectA' and 'objectB' are SPOPS keys.

And in C<get_structure_file()> you may have:

 sub get_structure_file {
     my ( $self, $set, $driver ) = @_;
     if ( $set eq 'objectA' ) {
         return [ 'objectA.sql', 'objectALookup.sql' ];
     }
     elsif ( $set eq 'objectB' ) {
         if ( $driver eq 'Oracle' ) {
             return [ 'objectB-oracle', 'objectB-sequence' ];
         }
         return 'objectB.sql';
     }
     else {
         oi_error "Set '$set' not defined by this package.";
     }
 }

Note that you could also force the user to install all objects to the
same database, which makes sense for tables that use JOINs or whatnot:

 sub get_structure_set {
     return 'objectA';
 }
 
 # Now we don't care what the value of $set is...
 
 sub get_structure_file {
     my ( $self, $set, $driver ) = @_;
     my @base = ( 'objectA.sql', 'objectALookup.sql' );
     if ( $driver eq 'Oracle' ) {
         return [ @base, 'objectB-oracle', 'objectB-sequence' ];
     }
     return [ @base, 'objectB.sql' ];
 }

B<get_structure_file( $set_name, $driver_type )>

Return an arrayref of filenames based on the given C<$set_name> and
C<$driver_type>. This should include any tables and supporting
objects, like sequences for PostgreSQL/Oracle or generators for
FirebirdSQL/InterBase. See examples above.

B<install_data()>

If you have needs that declaration cannot fill, you can install data
yourself. You have access to the full
L<OpenInteract2::Context|OpenInteract2::Context> object so you can get
datasources, lookup SPOPS object information, etc. (See more in
section on customization below.)

B<get_data_file()>

Returns an arrayref of filenames with data to import. See discussion
below on importing data for more information on what these files can
contain.

B<install_security()>

If you have needs that declaration cannot fill, you can install
security objects yourself. You have access to the full
L<OpenInteract2::Context|OpenInteract2::Context> object so you can get
datasources, lookup SPOPS object information, etc. (See more in
section on customization below.)

B<get_security_file()>

Returns an arrayref of filenames with security data to import.

B<transform_data( $importer )>

This is B<optional> and called by the process behind C<install_data()>
and C<install_security()>. By default OI will change fields marked
under 'transform_default' and 'transform_now' as discussed in the data
import documentation below. But if you have other install-time
transformations you'd like to accomplish you can do them here.

The C<$importer> is a L<SPOPS::Import|SPOPS::Import> object. You can
get the field order and modify the data in-place:

 my $install_time = time;
 my $field_order = $importer->fields_as_hashref;
 foreach my $data ( @{ $importer->data } ) {
     my $idx = $field_order->{myfield};
     $data->[ $idx ] = ( $install_time % 2 == 0 ) ? 'even' : 'odd';
 }

So here's an example of a subclass that puts a number of the above
items together:

 package OpenInteract2::MyPackage::SQLInstall;
 
 use strict;
 use base qw( OpenInteract2::SQLInstall );
 use OpenInteract2::Context qw( CTX );
 
 # Lookup in the server configuration the name of the field to
 # transform. (This is not actually there, just an example.)
 
 sub init {
     my ( $self ) = @_;
     $self->{_my_transform_field} = CTX->server_config->{mypackage}{transform};
 }
 
 sub get_structure_set {
     return 'objectA';
 }
 
 # We don't care what the value of $set is since there's only one
 # possible value
 
 sub get_structure_file {
     my ( $self, $set, $driver ) = @_;
     my @base = ( 'objectA.sql', 'objectALookup.sql' );
     if ( $driver eq 'Oracle' ) {
         return [ @base, 'objectB-oracle', 'objectB-sequence' ];
     }
     return [ @base, 'objectB.sql' ];
 }
 
 sub transform_data {
     my ( $self, $importer ) = @_;
     my $install_time = time;
     my $field_order = $importer->fields_as_hashref;
     my $idx = $field_order->{ $self->{_my_transform_field} };
     return unless ( $idx );
     foreach my $data ( @{ $importer->data } ) {
         $data->[ $idx ] = ( $install_time % 2 == 0 ) ? 'even' : 'odd';
     }
     # Remember to call the main method!
     $self->SUPER::transform_data( $importer );
 }

=head1 DEVELOPERS: IMPORTING DATA

We need to be able to pass data from one database to another and be
very flexible as to how we do it. The various data file formats have
taken care of everything I could think of -- hopefully you will think
up some more.

To begin, there are two elements to a data file. The first element
tells the installer what type of data follows -- should we create
objects from them? Should we just plug the values into an SQL
statement and execute it against a particular table?

The second element is the actual data, which is in an order determined
by the first element.

There are several different ways to process a data file. Both are
described in detail below:

B<Object Processing>

Object processing allows you to just specify the field order and the
class, then let SPOPS do the dirty work. This is the preferred way of
transferring data, but it is not always feasible. An example where it
is not feasible include linking tables that SPOPS uses but does not
model.

B<SQL Processing>

SQL processing allows you to present elements of a SQL statement and
plug in values as many times as necessary. This can be used most
anywhere and for anything.

=head2 Object Processing

The first item in the list describes the class you want to use to
create objects and the order the fields that follow are in. Here is a
simple example of the data file used to install initial groups:

  $data_group = [ { import_type => 'object',
                    spops_class => 'OpenInteract2::Group',
                    field_order => [ qw/ group_id name / ] },
                  [ 1, 'admin' ],
                  [ 2, 'public' ],
                  [ 3, 'site admin' ],
  ];

Here is a slightly abbreviated form of what steps would look like if
they were done in code:

 my $object_class = 'OpenInteract2::Group';
 my %field_num = { group_id => 0, name => 1 };
 foreach my $row ( @{ $data_rows } ) {
   my $object = $object_class->new();
   $object->{group_id} = $row->[ $field_num{group_id} ];
   $object->{name}     = $row->[ $field_num{name} ];
   $object->save({ is_add => 1, skip_security => 1,
                   skip_log => 1, skip_cache => 1 });
 }

Easy!

You can also specify operations to perform on the data before they are
saved with the object. The most common operation of this is in
security data:

  $security = [
                { import_type       => 'object',
                  spops_class       => 'OpenInteract2::Security',
                  field_order       => [ qw/ class object_id scope scope_id security_level / ],
                  transform_default => [ 'scope_id' ] },
                [ 'OpenInteract2::Group',         1, 'w', 'world', 1 ],
                [ 'OpenInteract2::Group',         2, 'w', 'world', 4 ],
                [ 'OpenInteract2::Group',         2, 'g', 'site_admin_group', 8 ],
                [ 'OpenInteract2::Group',         3, 'w', 'world', 4 ],
                [ 'OpenInteract2::Group',         3, 'g', 'site_admin_group', 8 ],
                [ 'OpenInteract2::Action::Group', 0, 'w', 'world', 4 ],
                [ 'OpenInteract2::Action::Group', 0, 'g', 'site_admin_group', 8 ]
  ];

So these steps would look like:

 my $object_class = 'OpenInteract2::Security';
 my %field_num = { class => 0, object_id => 1, scope => 2,
                   scope_id => 3, security_level => 4 };
 my $defaults = CTX->server_config->{default_objects};
 foreach my $row ( @{ $data_rows } ) {
   my $object = $object_class->new();
   $object->{class}     = $row->[ $field_num{class} ];
   $object->{object_id} = $row->[ $field_num{object_id} ];
   $object->{scope}     = $row->[ $field_num{scope} ];
   my $scope_id         = $row->[ $field_num{scope_id} ];
   $object->{scope_id}  = $defaults->{ $scope_id } || $scope_id;
   $object->{level}     = $row->[ $field_num{security_level} ];
   $object->save({ is_add   => 1, skip_security => 1,
                   skip_log => 1, skip_cache    => 1 });
 }

There are currently just a few behaviors you can set to transform the
data before it gets saved (see C<transform_data()> above), but the
interface is there to do just about anything you can imagine.

=head2 SQL Processing

The actions performed when you just want to insert data into tables is
similar to those performed when you are inserting objects. The only
difference is that you need to specify a little more. Here is an
example:

  $data_link = [ { import_type => 'dbdata',
                   sql_table   => 'sys_group_user',
                   field_order => [ qw/ group_id user_id / ] },
                 [ 1, 1 ]
  ];

So we specify the import type ('dbdata'), the table to operate on
('sys_group_user'), the order of fields in the data rows
('field_order', just like with processing objects) and then list the
data.

You are also able to specify the data types. Most of the time this
should not be necessary: if the database driver (e.g.,
L<DBD::mysql|DBD::mysql>) supports it, the
L<SPOPS::SQLInterface|SPOPS::SQLInterface> file has routines to
discover data types in a table and do the right thing with regards to
quoting values.

However, if you do find it necessary you can use the following simple
type -E<gt> DBI type mappings:

 'int'   -> DBI::SQL_INTEGER(),
 'num'   -> DBI::SQL_NUMERIC(),
 'float' -> DBI::SQL_FLOAT(),
 'char'  -> DBI::SQL_VARCHAR(),
 'date'  -> DBI::SQL_DATE(),

Here is a sample usage:

  $data_link = [ { import_type => 'dbdata',
                   sql_table   => 'sys_group_user',
                   field_order => [ qw/ group_id user_id link_date priority_level / ],
                   field_type  => { group_id       => 'int',
                                    user_id        => 'int',
                                    link_date      => 'date',
                                    priority_level => 'char' },
                  },
                 [ 1, 1, '2000-02-14', 'high' ]
  ];

Additionally you can create Perl code to do this for you.

=head1 DEVELOPERS: CUSTOM BEHAVIOR

(Or: "The Declaration Is Not Enough")

As mentioned above, you can override any of the C<install_*> methods
for the ultimate flexibility. For instance, in the C<base_user>
package we create a 'superuser' object with a password generated at
runtime.

You can do anything you like in the C<install_structure>,
C<install_data> or C<install_security> methods. You have the full
L<OpenInteract2::Context|OpenInteract2::Context> available to you,
including the configuration for the SPOPS objects, datasources, and
full server configuration.

=head2 Responsibilities

When you implement custom behavior you have certain
responsibilities. The contract with programs using this object says
that every 'file' is associated with a status and, if it failed, an
error message. (It may also be associated with a statement and
datasource name.) Once the actions are completed the user can query
this object to see what was done along with the status of the actions
and any errors that were encountered.

The word B<file> is in quotes because it should really be something
more abstract like 'distinct action'. But because most of the time
actions are file-based and everyone understands files, that's the way
it is. But you're not constrained by this. So in the example above
where we create the superuser object I could give that action a name
of 'create administrator' and everyone would know what I meant.

For example, here's what such an implementation might look like:

 sub install_data {
     my ( $self ) = @_;
     my $action_name = 'create administrator';
     my $server_config = CTX->server_config;
     my $email = $server_config->{mail}{admin_email};
     my $id    = $server_config->{default_objects}{superuser};
     my $user = CTX->lookup_object( 'user' )
                   ->new({ email      => $email,
                           login_name => 'superuser',
                           first_name => 'Super',
                           last_name  => 'User',
                           user_id    => $id });
     my $password = SPOPS::Utility->generate_random_code(8);
     if ( $server_config->{login}{crypt_password} ) {
         $user->{password} = SPOPS::Utility->crypt_it( $password );
     }
     eval { $user->save({ is_add        => 1,
                          skip_security => 1,
                          skip_cache    => 1,
                          skip_log      => 1 }) };
     if ( $@ ) {
         $log->error( "Failed to create superuser: $@" );
         $self->_set_state( $action_name,
                            undef,
                            "Failed to create admin user: $@",
                            undef );
     }
     else {
         my $msg_ok = join( '', 'Created administrator ok. ',
                                '**WRITE THIS PASSWORD DOWN!** ',
                                "Password: $password" );
         $self->_set_state( $action_name, 1, $msg_ok, undef );
     }

     # If we needed to process any data files in addition to the
     # above, we could do:
     # $self->SUPER::install_data();
 }

=head2 Custom Methods to Use

B<process_data_file( @files )>

Implemented by this class to process and install data from the given
data files. If you're generating your own files it may prove useful.

B<_set_status( $file, 0|1 )>

B<_set_error( $file, $error )>

B<_set_statement( $file, $statement )>

B<_set_datasource( $file, $datasource_name )>

B<_set_state( $file, 0|1, $error, $statement )>

=head1 BUGS

None known.

=head1 TO DO

B<Dumping data for transfer>

It would be nice if you could do something like:

 oi2_manage dump_sql --website_dir=/home/httpd/myOI --package=mypkg

And get in your C<data/dump> directory a series of files that can be
read in by another OpenInteract website for installation. This is
the pie in the sky -- developing something like this would be really
cool.

And we can, but only for SPOPS objects. It is quite simple for us to
read data from a flat file, build objects from the data and save them
into a random database -- SPOPS was built for this!

However, structures are a problem with this. Data that are not held in
objects are a problem. And dealing with dependencies is an even bigger
problem.

B<Single-action process>

Creating a script that allowed you to do:

 oi_sql_process --database=Sybase \
                --apply=create_structure < table.sql > sybase_table.sql

would be pretty nifty.

=head1 SEE ALSO

L<SPOPS::Manual::ImportExport|SPOPS::Manual::ImportExport>

L<SPOPS::Import|SPOPS::Import>

L<OpenInteract2::Package|OpenInteract2::Package>

L<DBI|DBI>

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
