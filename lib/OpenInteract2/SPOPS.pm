package OpenInteract2::SPOPS;

# $Id: SPOPS.pm,v 1.13 2003/06/10 17:01:25 lachoy Exp $

use strict;
use Data::Dumper             qw( Dumper );
use Digest::MD5              qw( md5_hex );
use OpenInteract2::Context   qw( CTX DEBUG LOG );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Util;
use SPOPS::ClassFactory      qw( OK NOTIFY );

$OpenInteract2::SPOPS::VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

# TODO:
#   - move object key stuff to a separate class

use constant OBJECT_KEY_TABLE => 'object_keys';

########################################
# STARTUP MODIFY CONFIGURATION

# This should be called BEFORE the children make their modifications,
# so each child should call a SUPER::modify_spops_config( $config )...

sub modify_spops_config {
    my ( $class, $config ) = @_;

    # Ensure 'isa' and 'rules_from' are arrayrefs...

    $config->{isa} ||= [];
    unless ( ref $config->{isa} eq 'ARRAY' ) {
        $config->{isa} = ( defined $config->{isa} )
                           ? [ $config->{isa} ] : [];
    }

    $config->{rules_from} ||= [];
    unless ( ref $config->{rules_from} eq 'ARRAY' ) {
        $config->{rules_from} = ( defined $config->{rules_from} )
                                  ? [ $config->{rules_from} ] : [];
    }

    _config_security( $config );
    _config_creation_security( $config );
    _config_date_conversion( $config );
    _config_display_info( $config );
}

sub _config_security {
    my ( $config ) = @_;
    if ( defined $config->{is_secure} and $config->{is_secure} eq 'yes' ) {
        DEBUG && LOG( LDEBUG, "Adding security to [$config->{class}]" );
        unshift @{ $config->{isa} }, 'SPOPS::Secure';
    }
}

sub _config_creation_security {
    my ( $config ) = @_;
    unless ( ref $config->{creation_security} eq 'HASH' ) {
        return;
    }
    DEBUG && LOG( LDEBUG, "Checking 'creation_security' rules for ",
                          "class $config->{class}" );
    my %create = ( u => $config->{creation_security}{user},
                   w => $config->{creation_security}{world} );

    my $default_objects = CTX->server_config->{default_objects};
    my %groups = ();
    if ( my $group_levels = $config->{creation_security}{group} ) {
        my @all_group_levels = ( ref $group_levels eq 'ARRAY' ) 
                                 ? @{ $group_levels } : ( $group_levels );
        foreach my $group_pair ( @all_group_levels ) {
            my ( $gid, $gl ) = split /\s*:\s*/, $group_pair, 2;
            if ( $gid =~ /\D/ ) {
                DEBUG && LOG( LDEBUG, "Group ID [$gid] not a #, changing" );
                $gid = $default_objects->{ $gid };
            }
            $groups{ $gid } = $gl;
        }
    }
    $create{g} = \%groups;
    $config->{creation_security} = \%create;
    DEBUG && LOG( LDEBUG, "Final security: ", Dumper( $config->{creation_security} ) );
}

sub _config_date_conversion {
    my ( $config ) = @_;
    my $DFK = 'convert_date_field';
    $config->{ $DFK } ||= [];
    unless ( ref $config->{ $DFK } eq 'ARRAY' ) {
        $config->{ $DFK } = [ $config->{ $DFK } ];
    }

    # First check to see if we have any date fields

    unless ( scalar @{ $config->{ $DFK } } > 0 ) {
        DEBUG && LOG( LDEBUG, "No date fields in [$config->{class}]" );
        return;
    }

    DEBUG && LOG( LINFO, "Setting up [$config->{class}] to autoconvert ",
                  "its date fields: ", join( ', ', @{ $config->{ $DFK } } ) );

    $config->{convert_date_class} = 'DateTime';
    my %existing_rules = map { $_ => 1 } @{ $config->{rules_from} };
    unless ( $existing_rules{ 'SPOPS::Tool::DateConvert' } ) {
        DEBUG && LOG( LDEBUG, "Adding date conversion tool to rules" );
        push @{ $config->{rules_from} }, 'SPOPS::Tool::DateConvert';
    }

    # TODO: Be able to set a default format for all databases

    unless ( $config->{convert_date_format} ) {
        my $default_format = '%Y-%m-%d %H:%M:%S';
        LOG( LWARN, "Class [$config->{class}] does not have a conversion ",
                    "date format set. This is STRONGLY encouraged -- ",
                    "please look at OpenInteract2::Manual::SPOPS under ",
                    "'DATE CONVERSION' for more information. ",
                    "(Using default '$default_format')" );
        $config->{convert_date_format} = $default_format;
    }
}

# NOTE: This requires that the action table is already read in. The
# process defined in OI2::Context/Setup ensures this, but if you're
# doing initialization some other way: YOU'VE BEEN WARNED.

sub _config_display_info {
    my ( $config ) = @_;
    my $display_info = $config->{display};
    unless ( ref $display_info eq 'HASH' ) {
        return;
    }
    if ( $display_info->{url} ) {
        $display_info->{url} =
            OpenInteract2::URL->create( $display_info->{url} );
    }
    elsif ( $display_info->{ACTION} ) {
        $display_info->{url} =
            OpenInteract2::URL->create_from_action( $display_info->{ACTION},
                                                    $display_info->{TASK} );
        delete $display_info->{ACTION};
        delete $display_info->{TASK};
    }
}




########################################
# RULESET FACTORY BEHAVIOR
########################################

# TODO: Make this optional? Are we even using object keys anymore?

sub ruleset_factory {
    my ( $class, $rs_table ) = @_;
    push @{ $rs_table->{post_save_action} }, \&save_object_key;
    return __PACKAGE__;
}


# Use the object class and ID to update the object key table

sub save_object_key {
    my ( $self, $p ) = @_;

    # Don't create an object key if we're explicitly told not to
    return 1 if ( $self->CONFIG->{skip_object_key} || $p->{skip_object_key} );

    $p ||= {};
    my $obj_key = $self->fetch_object_key;
    unless ( $obj_key ) {
        $obj_key = $self->generate_object_key;
        eval { $self->db_insert({ %{ $p }, table => OBJECT_KEY_TABLE,
                                  field => [ qw/ object_key class object_id / ],
                                  value => [ $obj_key, ref( $self ), $self->id ] }) };
        if ( $@ ) {
            LOG( LALL, "Cannot save object key: $@" );
            return undef;
        }
    }
    return $self->{tmp_object_key} = $obj_key;
}


########################################
# OBJECT KEY

# Create a unique key based on the class and ID

sub generate_object_key {
    my ( $self ) = @_;
    return md5_hex( ref( $self ) . $self->id );
}


# Retrieve the object key based on the class and ID

sub fetch_object_key {
    my ( $self, $p ) = @_;
    $p ||= {};
    my $row = $self->db_select({ %{ $p },
                                 from   => OBJECT_KEY_TABLE,
                                 select => [ 'object_key' ],
                                 where  => 'class = ? AND object_id = ?',
                                 value  => [ ref $self, $self->id ],
                                 return => 'single' });
    return $row->[0] if ( $row );
    return undef;
}


# Retrieve the object class and ID given an object_key

sub fetch_object_info_by_key {
    my ( $class, $key, $p ) = @_;
    $p ||= {};
    $p->{db} ||= $class->global_datasource_handle;
    die "Cannot retrieve object info without key!" unless ( $key );
    my $row = SPOPS::SQLInterface->db_select({
                              %{ $p },
                              from   => OBJECT_KEY_TABLE,
                              select => [ 'class', 'object_id' ],
                              where  => 'object_key = ?',
                              value  => [ $key ],
                              return => 'single' });
    return ( $row->[0], $row->[1] ) if ( $row );
    return undef;
}


# Retrieve an object given an object_key

sub fetch_object_by_key {
    my ( $class, $key, $p ) = @_;
    my ( $object_class, $object_id ) =
               $class->fetch_object_info_by_key( $key, $p );
    if ( $object_class and $object_id ) {
        return $object_class->fetch( $object_id, $p );
    }
    return undef;
}


########################################
# OBJECT TRACK METHODS

# Just a wrapper for log_action_enter, although we make sure that the
# action is allowed before doing it.

sub log_action {
    my ( $self, $action, $id ) = @_;
    return 1   unless ( $self->CONFIG->{track}{ $action } );
    return $self->log_action_enter( $action, $id );
}


# Log the object, the action (create, update, remove), who did
# the action and when it was done.
#
# Note that you can pass the uid in directly to override the current user

sub log_action_enter {
    my ( $self, $action, $id, $uid ) = @_;
    my $req = CTX->request;
    my $log_msg = 'no log message';
    if ( UNIVERSAL::isa( $req, 'OpenInteract2::Request' ) )  {
        $uid ||= $req->auth_user_id;
        $log_msg = $req->param( '_log_message' );
    }
    else {
        $uid ||= CTX->server_config->{default_objects}{superuser};
    }
    my $now = DateTime->now;
    my $class = ref $self || $self;
    DEBUG && LOG( LDEBUG, "Log [$action] [$class] [$id] by [$uid] [$now]" );
    my $object_action = eval { CTX->lookup_object( 'object_action' )
                                  ->new({ class     => $class,
                                          object_id => $id,
                                          action    => $action,
                                          action_by => $uid,
                                          action_on => $now,
                                          notes     => $log_msg })
                                  ->save() };
    if ( $@ ) {
        LOG( LERROR, "Log entry failed: $@" );
        return undef;
    }
    return 1;
}


# Retrieve the user who created a particular object

sub fetch_creator {
    my ( $self ) = @_;

    # Bail if it's not an already-existing object
    return undef  unless ( ref $self and $self->id );
    my $track = eval {
        CTX->lookup_object( 'object_action' )
           ->fetch_object_creation( $self )
    };
    if ( $@ ) {
        LOG( LERROR, "Failed to retrieve object creator(s): $@" );
        return undef;
    }
    my $creator = eval { $track->action_by_user };
    if ( $@ ) {
        LOG( LERROR, "Error fetching creator: $@" );
    }
    return $creator;
}


# Return 1 if the user represented by $uid is a creator
# of an object (or the superuser), undef if not

sub is_creator {
    my ( $self, $uid ) = @_;
    my $req = CTX->request;
    $uid ||= $req->auth_user_id;
    return undef unless ( $uid );

    # the great and powerful superuser sees all

    return 1 if ( $uid eq CTX->server_config->{default_objects}{superuser} );
    my $creator = $self->fetch_creator;
    return ( $creator->id eq $uid );
}

# TODO: Update this to just return the object...
#
# Retrieve an arrayref of arrayrefs where item 0 is the uid
# of the user who last did the update and item 1 is the
# date of the update

sub fetch_updates {
    my ( $self, $opt ) = @_;

    # Bail if it's not an already-saved object

    return []  unless ( ref $self and $self->id );
    my $limit = ( $opt eq 'last' ) ? '1' : int( $opt );
    my $updates = eval {
        CTX->lookup_object( 'object_action' )
           ->fetch_actions( $self,
                            { limit        => $limit,
                              column_group => 'base' } )
    };
    if ( $@ ) {
        LOG( LERROR, "Cannot retrieve object updates: $@" );
        return undef;
    }
    DEBUG && LOG( LDEBUG, "Data from updates:\n", Dumper( $updates ) );
    return [ map { [ $_->{action_by}, $_->{action_on} ] } @{ $updates } ];
}


########################################
# SECURITY

# Override method in SPOPS::Secure since we already know the
# user/group information from $R

sub get_security_scopes {
    my ( $self, $p ) = @_;
    my $req = CTX->request;
    return ( $req->auth_user, $req->auth_group );
}



# Let SPOPS::Secure know what the IDs are for the superuser and
# supergroup

sub get_superuser_id  {
    return CTX->server_config
              ->{default_objects}{superuser}
}

sub get_supergroup_id  {
    return CTX->server_config
              ->{default_objects}{supergroup}
}

########################################
# DATASOURCE

sub global_datasource_handle {
    my ( $self, $connect_key ) = @_;
    $connect_key ||= $self->CONFIG->{datasource};
    return CTX->datasource( $connect_key );
}


########################################
# GLOBAL OBJECTS/CLASSES

# These are used so that subclasses (and other classes in the
# inheritance hierarchy, particularly within SPOPS) are able to have
# access to the various objects and resources

sub global_cache                 { return CTX->cache           }
sub global_config                { return CTX->server_config          }
# Is this right? Is this needed?
sub global_secure_class          { return CTX->lookup_object( 'secure' ) }
sub global_security_object_class { return CTX->lookup_object( 'security' ) }
sub global_user_class            { return CTX->lookup_object( 'user' ) }
sub global_group_class           { return CTX->lookup_object( 'group' ) }

sub global_user_current {
    my $req = CTX->request;
    return ( $req ) ? CTX->request->auth_user : undef;
}

sub global_group_current {
    my $req = CTX->request;
    return ( $req ) ? CTX->request->auth_group : [];
}


########################################
# OTHER METHODS

# Send an email with one or more objects as the body.

sub notify {
    my ( $item, $p ) = @_;
    my $req = CTX->request;
    $p->{object} ||= [];

    # If we weren't given any objects and we were called by
    # a class instead of an object

    return undef unless ( ref $item or scalar @{ $p->{object} } );

    # If we were just called by an object, make it our message

    push @{ $p->{object} }, $item  unless ( scalar @{ $p->{object} } );
    my $num_objects = scalar @{ $p->{object} };
    my $subject = $p->{subject} || "Object notification: $num_objects objects in mail";
    my $separator = '=' x 25;
    my $msg = ( $p->{notes} ) ?
                join( "\n", 'Notes', "$separator$p->{notes}", $separator, "\n" ) : '';
    foreach my $obj ( @{ $p->{object} } ) {
        my $info = $obj->object_description;
        my $object_url = join( '', 'http://', $req->server_name, $info->{url} );
        $msg .= <<OBJECT;
Begin $info->{name} object
$separator
@{[ $obj->as_string ]}

View this object at: $object_url
$separator
End $p->{name} object

OBJECT
    }
    my $from_email = $p->{email_from} ||
                     CTX->server_config->{mail}{admin_email};
    eval {
        OpenInteract2::Util->send_email({ to      => $p->{email},
                                          from    => $from_email,
                                          subject => $subject,
                                          message => $msg });
    };
    if ( $@ ) {
        LOG( LERROR, "Failed to send email: $@" );
        return undef;
    }
    return 1;
}


1;

__END__

=head1 NAME

OpenInteract2::SPOPS - Define common behaviors for all SPOPS objects in the OpenInteract Framework

=head1 SYNOPSIS

 # In configuration file
 'myobj' => {
    'isa'   => [ qw/ ... OpenInteract2::SPOPS::DBI ... / ],
 }

=head1 DESCRIPTION

Here we provide some common operations within OpenInteract that are
not implmented within the data abstraction layer itself. Since we want
to continue using both separately we cannot embed ideas like a
configuration object or a particular cache implementation within
SPOPS. Think of this class as a bridge between the two.

Note that while most of the functionality is in this class, you will
always want to use one of the implementations-specific child classes
-- see L<OpenInteract2::SPOPS::DBI> and L<OpenInteract2::SPOPS::LDAP>.

=head1 OBJECT TRACKING METHODS

There are a number of methods for dealing with object tracking -- when
a create/update/remove action is taken on an object and by whom.

B<log_action( $action, $id )>

Wrapper for the I<log_action_enter> method below, decides whether it
gets called. (Wrapper exists so subclasses can call log_action_enter
directly and not deal with this step.)

Parameters:

=over 4

=item *

B<action> ($)

Should be 'create', 'update', 'remove'.

B<id> ($)

ID of the object.

=back

B<Returns> undef on failure, true value on success.

B<log_action_enter( $action, $id )>

Makes an entry into the 'object_track' table, which logs all object
creations, updates and deletions. We do not note the content that
changes, but we do note who did the action and when it was done.

Parameters:

=over 4

=item *

B<action> ($)

Should be 'create', 'update', 'remove'.

B<id> ($)

ID of the object.

=back

B<Returns> undef on failure, true value on success.

B<fetch_creator()>

Retrieve an arrayref of all user objects who have 'creator' rights
to a particular object.

B<is_creator( $uid )>

Parameters:

=over 4

=item *

B<uid> ($)

User ID to check and see if that user created this object.

=back

B<Returns> 1 if the object was created by $uid, undef if not.

B<fetch_updates()>

B<Returns> an arrayref of arrayrefs, each formatted:

 [ uid of updater, date of update ]

=head1 OBJECT KEY METHODS

We use a object key to uniquely identify each object in the
system. (Generally the object key is a digest formed from the class
and object ID.)

B<generate_object_key()>

Creates a unique key based on the class and ID. (Currently using
L<Digest::MD5>.)

B<save_object_key( \%params )>

Checks to see if an object key already exists for this class and ID
and if not, creates a new key and saves it to the lookup table.

Returns: the object key retrieved or saved

B<fetch_object_key()>

Retreives an object key based on the class and ID of an object.

Returns: the object key associated with the class and ID, or undef if
none found.

B<fetch_object_info_by_key( $key, \%params )>

Given an object key, lookup the object class and ID associated with it.

Returns: If matching information found, a two-element list -- the
first element is the object class, the second is the object ID. If no
matching information is found, undef.  matching information found, re

B<fetch_object_by_key( $key, \%params )>

Given an object key, fetch the object associated with it.

Returns: If key matches class and ID in lookup table, the object with
the class and ID. If no match found, return undef.

=head1 RULESET METHODS

We create one rule in the ruleset of each object. In the
B<post_save_action> step we ensure that this object has an entry in
the object key table. (See description of C<save_object_key()> for
information about the implementation.)

=head1 METHODS

B<notify()>

Either call from an object or from a class passing an arrayref of
objects to send to a user. Calls the I<as_string()> method of the
object, which (if you look in the SPOPS docs), defaults to being a
simple property -E<gt> value listing. You can override this with
information in your class configuration which specifies the fields you
want to use in the listing along with associated labels.

Parameters:

=over 4

=item *

B<email> ($)

Address to which we should send the notification.

=item *

B<email_from> ($) (optional)

Address from which the email should be sent. If not specified this
defaults to the 'admin_email' setting in your server configuration
(under 'mail').

=item *

B<subject> ($) (optional)

Subject of email. If not specified the subject will be 'Object
notification # objects in mail'.

=item *

B<object> (\@) (optional if called from an object)

If not called from an object, this should be an arrayref of objects to
notify someone about.

=item *

B<notes> ($) (optional)

Notes that lead off an email.

=back

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2002-2003 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
