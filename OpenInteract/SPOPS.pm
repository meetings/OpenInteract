package OpenInteract::SPOPS;

# $Id: SPOPS.pm,v 1.5 2001/06/01 01:19:54 lachoy Exp $

use strict;
use Data::Dumper qw( Dumper );
use HTML::Entities  ();

@OpenInteract::SPOPS::ISA     = ();
$OpenInteract::SPOPS::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);


# Just a wrapper for log_action_enter, although we make sure that the
# action is allowed before doing it.

sub log_action {
  my ( $self, $action, $id ) = @_;
  return 1   unless ( $self->CONFIG->{track}->{ $action } );
  return $self->log_action_enter( $action, $id );
}

# Log the object, the action (create, update, remove), who did 
# the action and when it was done.
#
# Note that you can pass the uid in directly to override the current user

sub log_action_enter {
  my ( $self, $action, $id, $uid ) = @_;
  my $R = OpenInteract::Request->instance;
  $uid ||= ( ref $R->{auth}->{user} ) ? $R->{auth}->{user}->{user_id} : 0;
  my $now = SPOPS::Utility->now;
  my $class = ref $self || $self;
  my $log_msg = $R->apache->param( '_log_message' );
  $R->DEBUG && $R->scrib( 1, "Entering action $action to $class ($id) by $uid on $now" );
  eval { $self->db_insert( { db    => $R->db, 
                             table => 'object_track', 
                             field => [ qw/ class object_id action action_by action_on notes / ],
                             value => [ $class, $id, $action, $uid, $now, $log_msg ] } ); };
  if ( $@ ) {
    $R->scrib( 0, "Log entry failed: $SPOPS::Error::system_msg" );
    OpenInteract::Error->set( SPOPS::Error->get ); 
    $OpenInteract::Error::user_msg = "Cannot log object action: $action";
    $OpenInteract::Error::notes    = "Object: $class ($id) by $uid on $now";
    $R->throw({ code => 302 });
    return undef;
  }
  return 1;
}


# Retrieve the users who have 'creator' rights on a particular
# object.

sub fetch_creator {
  my ( $self ) = @_;

  # Bail if it's not an already-existing object
  return undef  unless ( ref $self and $self->id );
  my $R = OpenInteract::Request->instance;
  my $data = eval { $self->db_select({ 
                               db     => $R->db, 
                               select => [ 'action_by' ],
                               from   => [ 'object_track' ],
                               where  => 'class = ? AND object_id = ? and action = ?',
                               value  => [ ref $self, $self->id, 'create' ],
                               return => 'single-list' }) };
  if ( $@ ) {
    $OpenInteract::Error::user_msg = 'Cannot retrieve object creator(s)';
    $OpenInteract::Error::extra    = { class     => ref $self, 
                                       object_id => $self->id };
    $R->throw( { code => 306 } );
    return undef;
  }
  my $user_class = $R->user;
  return [ map { $user_class->fetch( $_ ) } @{ $data } ];
}


# Return 1 if the user represented by $uid is a creator
# of an object (or the superuser), undef if not

sub is_creator {
  my ( $self, $uid ) = @_;
  my $R = OpenInteract::Request->instance;
  $uid ||= $R->{auth}->{user}->{user_id};
  return undef unless ( $uid );
  return 1     if ( $uid == 1 ); # the great and powerful superuser sees all
  my $creator_list = eval { $self->fetch_creator } || [];
  foreach my $creator ( @{ $creator_list } ) {
    return 1 if ( $uid eq $creator->{user_id} );
  }
  return undef;
}


# Retrieve an arrayref of arrayrefs where item 0 is the uid 
# of the user who last did the update and item 1 is the 
# date of the update

sub fetch_updates {
  my ( $self, $opt ) = @_;
  
  # Bail if it's not an already-saved object

  return []  unless ( ref $self and $self->id );
  my $return = ( $opt eq 'last' ) ? 'single' : 'list';
  my $R = OpenInteract::Request->instance;
  my $data = eval { $self->db_select({ 
                               db     => $R->db, 
                               select => [ qw/ action_by  action_on  notes / ],
                               from   => [ 'object_track' ], 
                               where  => 'class = ? AND object_id = ? and ( action = ? OR action  = ? )',
                               value  => [ ref $self, $self->id, 'create', 'update' ],
                               order  => 'action_on DESC', return => $return } ); };
  if ( $@ ) {
    $OpenInteract::Error::user_msg = 'Cannot retrieve object updates';
    $OpenInteract::Error::extra    = { class     => ref $self, 
                                       object_id => $self->id };
    $R->throw( { code => 306 } );
    return undef;
  }
  if ( my $num = int( $opt ) ) {
    my @updates = splice( @{ $data }, 0, $num );
    my $num_removed = scalar @{ $data };
    push @updates, [ 'system', "... $num_removed additional updates ... " ]  if ( $num_removed );
    $data = \@updates;
  }
  $R->DEBUG && $R->scrib( 2, "Data from updates:\n", Dumper( $data ) );
  return $data;
}
 

# Send an email with one or more objects as the body.

sub notify {
  my ( $item, $p ) = @_;
  my $R = OpenInteract::Request->instance;
  $p->{object} ||= [];

  # If we weren't given any objects and we were called by 
  # a class instead of an object

  return undef unless ( ref $item or scalar @{ $p->{object} } );

  # If we were just called by an object, make it our message 

  push @{ $p->{object} }, $item  unless ( scalar @{ $p->{object} } );
  my $num_objects = scalar @{ $p->{object} };
  my $subject = $p->{subject} || "Object notification: $num_objects objects in mail";
  my $separator = '=' x 25;
  my $msg = ( $p->{notes} ) ? join( "\n", 'Notes', "$separator$p->{notes}", $separator, "\n" ) : '';
  foreach my $obj ( @{ $p->{object} } ) {
    my $info = $obj->object_description;
    my $object_url = join( '', 'http://', $R->{server_name}, $info->{url} );
    $msg .= "Begin $p->{type} object\n$separator\n" .
            $obj->as_string . "\n" .
            "View this object at: $object_url\n" .
            "\n$separator\nEnd $p->{type} object\n\n\n";
  }
  eval { OpenInteract::Utility->send_email({ 
                                    to      => $p->{email},
                                    from    => $R->CONFIG->{admin_email},
                                    subject => $subject,
                                    message => $msg }) };
  if ( $@ ) {   
    $R->throw({ code => 203 });
    return undef;
  }
  return 1;
}

# Use this to translate from
# <font size="-1"...
#   to
# &lt;font size=&quot;-1&quot...
# Params: 0: class; 1: text

sub html_encode { return HTML::Entities::encode( $_[1] ); }

# Use this to translate from
# &lt;font size=&quot;-1&quot...
#   to
# <font size="-1"...
# Params: 0: class; 1: text

sub html_decode { return HTML::Entities::decode( $_[1] ); }

# These are used so that subclasses (and other classes in the
# inheritance hierarchy, particularly within SPOPS) are able to have
# access to the various objects and resources

sub global_cache          { return OpenInteract::Request->instance->cache;  }
sub global_config         { return OpenInteract::Request->instance->config; }
sub global_db_handle      { return OpenInteract::Request->instance->db;     }
sub global_secure_class   { return OpenInteract::Request->secure;           }
sub global_security_object_class { return OpenInteract::Request->security;  }
sub global_user_class     { return OpenInteract::Request->user;             }
sub global_group_class    { return OpenInteract::Request->group;            }
sub global_user_current   { return OpenInteract::Request->instance->{auth}->{user} }
sub global_group_current  { return OpenInteract::Request->instance->{auth}->{group} }

1;

__END__

=pod

=head1 NAME

OpenInteract::SPOPS - Define common behaviors for all SPOPS objects in the OpenInteract Framework

=head1 SYNOPSIS

 # In configuration file
 'myobj' => {
    'isa'   => [ qw/ ... OpenInteract::SPOPS ... / ],
 }

=head1 DESCRIPTION

Here we provide some common operations within OpenInteract that are
not implmented within the data abstraction layer itself. Since we want
to continue using both separately we cannot embed ideas like a
configuration object or a particular cache implementation within
SPOPS. Think of this class as a bridge between the two.

=head1 METHODS

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

B<notify()>

Either call from an object or from a class passing an arrayref of
objects to send to a user. Calls the I<as_string()> method of the
object, which (if you look in the SPOPS docs), defaults to being a
simple property -> value listing. You can override this with
information in your class configuration which specifies the fields you
want to use in the listing along with associated labels.

B<html_encode( $text )>

Parameters:

=over 4

=item *

B<text> ($)

Text to encode.

=back

B<Returns>: escaped version of $text (e.g., the character '"' will be
replaced by &quot;)

B<html_decode( $text )>

Parameters:

=over 4

=item *

B<text> ($)

Text to decode.

=back

Returns: unescaped version of $text (e.g., the entity &quot; will be
replaced by the character '"')

It may seem silly to have these html_ methods which currently just
call the method of an external module, but we might wish to do more in
the future (for example, screen out javascript>. This way, we have a
central place to change it.

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
