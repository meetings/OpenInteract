package OpenInteract2::Config::Initializer;

# $Id: Initializer.pm,v 1.5 2003/09/05 02:23:33 lachoy Exp $

use base qw( Class::Observable );
use strict;
use Carp                     qw( croak );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Config::Initializer::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub new {
    my ( $class ) = @_;
    return bless( {}, $class );
}

sub read_observers {
    my ( $class ) = @_;
    my $log = get_logger( LOG_INIT );

    my @conf_watchers = ();

    # ...from the server
    my $config_watcher = CTX->server_config->{config_watcher};
    if ( ref $config_watcher eq 'HASH' and
         ref $config_watcher->{class} eq 'ARRAY' ) {
        push @conf_watchers, @{ $config_watcher->{class} };
    }

    # ...from packages
    my $packages = CTX->packages || [];
    foreach my $package ( @{ $packages } ) {
        next unless ( $package );
        my $config = $package->config;
        next unless ( $config );
        my $config_watcher = $config->config_watcher;
        next unless ( $config_watcher );
        push @conf_watchers, @{ $config_watcher };
    }

    foreach my $watcher_class ( @conf_watchers ) {
        __PACKAGE__->add_observer( $watcher_class );
        $log->info( "Adding custom config observer [$watcher_class]" );
    }

}

########################################
# SPOPS INITIALIZATION BEHAVIORS

sub _spops_normalize_params {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'spops' );
    my $log = get_logger( LOG_INIT );
    $log->info( "Normalizing parameters for SPOPS '$config->{key}'" );

    my @list_params = qw( isa rules_from fulltext_field );
    _normalize_list( $config, \@list_params );

    my @hash_params = qw();
    _normalize_hash( $config, \@hash_params );
}

sub _spops_security {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'spops' );
    return unless ( $config->{is_secure} and $config->{is_secure} eq 'yes' );
    my $log = get_logger( LOG_INIT );
    $log->info( "Adding security to [$config->{key}: $config->{class}]" );
    unshift @{ $config->{isa} }, 'SPOPS::Secure';
}

sub _spops_creation_security {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'spops' );
    return unless ( ref $config->{creation_security} eq 'HASH' );

    my $log = get_logger( LOG_INIT );
    $log->info( "Checking 'creation_security' rules for ",
                "[$config->{key}: $config->{class}]" );
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
                $log->is_debug &&
                    $log->debug( "Group ID [$gid] not a #, changing" );
                $gid = $default_objects->{ $gid };
            }
            $groups{ $gid } = $gl;
        }
    }
    $create{g} = \%groups;
    $config->{creation_security} = \%create;
    $log->is_debug &&
        $log->debug( "Final security: ",
                     CTX->dump( $config->{creation_security} ) );
}

sub _spops_date_conversion {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'spops' );
    my $log = get_logger( LOG_INIT );

    my $DFK = 'convert_date_field';
    $config->{ $DFK } ||= [];
    unless ( ref $config->{ $DFK } eq 'ARRAY' ) {
        $config->{ $DFK } = [ $config->{ $DFK } ];
    }

    # First check to see if we have any date fields

    return unless ( scalar @{ $config->{ $DFK } } > 0 );

    $log->info( "Setting up [$config->{class}] to autoconvert ",
                "its date fields: ", join( ', ', @{ $config->{ $DFK } } ) );

    $config->{convert_date_class} = 'DateTime';
    my %existing_rules = map { $_ => 1 } @{ $config->{rules_from} };
    unless ( $existing_rules{ 'SPOPS::Tool::DateConvert' } ) {
        $log->is_debug &&
            $log->debug( "Adding date conversion tool to rules" );
        push @{ $config->{rules_from} }, 'SPOPS::Tool::DateConvert';
    }

    # TODO: Be able to set a default format for all databases

    unless ( $config->{convert_date_format} ) {
        my $default_format = '%Y-%m-%d %H:%M:%S';
        $log->warn( "SPOPS object [$config->{key}: $config->{class}] does ",
                    "not have a conversion date format set. This is ",
                    "STRONGLY encouraged -- please look at ",
                    "'OpenInteract2::Manual::SPOPS' under 'DATE ",
                    "CONVERSION' for more information. (Using default ",
                    "'$default_format')" );
        $config->{convert_date_format} = $default_format;
    }
}

sub _spops_fulltext {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'spops' );
    my $log = get_logger( LOG_INIT );
    if ( defined $config->{is_searchable} and $config->{is_searchable} eq 'yes' ) {
        if ( defined $config->{fulltext_field} ) {
            $log->is_debug &&
                $log->debug( "Adding fulltext indexing for ",
                             "[$config->{key}: $config->{class}]" );
            unshift @{ $config->{isa} }, 'OpenInteract2::FullText';
        }
        else {
            $log->warn( "You set 'is_searchable' for [$config->{key}: ",
                        "$config->{class}] but you didn't list any ",
                        "fields in 'fulltext_field' so nothing will ",
                        "be indexed." );
        }
    }
}

# NOTE: This requires that the action table is already read in. The
# process defined in OI2::Context/Setup ensures this, but if you're
# doing initialization some other way: YOU'VE BEEN WARNED.

sub _spops_display_info {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'spops' );
    my $display_info = $config->{display};
    return unless ( ref $display_info eq 'HASH' );
    my $log = get_logger( LOG_INIT );
    $log->info( "Translating correct URL for 'display' in '$config->{key}'" );
    if ( $display_info->{url} ) {
        $display_info->{url} =
            OpenInteract2::URL->create( $display_info->{url} );
    }
    elsif ( $display_info->{ACTION} ) {
        $display_info->{url} =
            OpenInteract2::URL->create_from_action( $display_info->{ACTION},
                                                    $display_info->{TASK} );
        delete $display_info->{TASK};
        if ( $display_info->{TASK_EDIT} ) {
            $display_info->{url_edit} =
                OpenInteract2::URL->create_from_action( $display_info->{ACTION},
                                                        $display_info->{TASK_EDIT} );
            delete $display_info->{TASK_EDIT};
        }
        delete $display_info->{ACTION};
    }
}

# DBI-only

sub _config_is_dbi {
    my ( $config ) = @_;
    my $ds_info = CTX->lookup_datasource_config( $config->{datasource} );
    return ( $ds_info->{type} eq 'DBI' );
}

sub _spops_discover_field {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'spops' );
    return unless ( _config_is_dbi( $config ) );
    my $log = get_logger( LOG_INIT );
    $log->info( "Adding field discovery for '$config->{key}'" );

    if ( $config->{field_discover} eq 'yes' ) {
        push @{ $config->{rules_from} }, 'SPOPS::Tool::DBI::DiscoverField';
    }
}

sub _spops_set_dbi {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'spops' );
    return unless ( _config_is_dbi( $config ) );
    my $ds_info = CTX->lookup_datasource_config( $config->{datasource} );
    my $spops_class = $ds_info->{spops};

    my $log = get_logger( LOG_INIT );
    $log->info( "Setting '$spops_class' and standards in 'isa' ",
                "for '$config->{key}'" );

    push @{ $config->{isa} }, ( $spops_class, 'SPOPS::DBI' );
    unshift @{ $config->{isa} }, 'OpenInteract2::SPOPS::DBI';
}

# LDAP-only

sub _spops_set_ldap {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'spops' );

    my $ds_info = CTX->lookup_datasource_config( $config->{datasource} );
    return unless ( $ds_info->{type} eq 'LDAP' );

    unshift @{ $config->{isa} }, 'OpenInteract2::SPOPS::LDAP';
    push @{ $config->{isa} }, 'SPOPS::LDAP';
}


__PACKAGE__->add_observer( \&_spops_normalize_params );
__PACKAGE__->add_observer( \&_spops_security );
__PACKAGE__->add_observer( \&_spops_creation_security );
__PACKAGE__->add_observer( \&_spops_date_conversion );
__PACKAGE__->add_observer( \&_spops_fulltext );
__PACKAGE__->add_observer( \&_spops_display_info );
__PACKAGE__->add_observer( \&_spops_set_dbi );
__PACKAGE__->add_observer( \&_spops_discover_field );
__PACKAGE__->add_observer( \&_spops_set_ldap );


########################################
# ACTION INITIALIZATION BEHAVIORS

sub _action_normalize_params {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'action' );

    my $log = get_logger( LOG_INIT );
    $log->info( "Normalizing params for action '$config->{name}'" );

    my @list_params = qw( url_alt task_valid task_invalid );
    _normalize_list( $config, \@list_params );

    my @hash_params = qw( template_source cache_expire );
    _normalize_hash( $config, \@hash_params );
}

sub _action_assign_defaults {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'action' );

    my $log = get_logger( LOG_INIT );
    $log->info( "Assigning action defaults to '$config->{name}'" );
    my $global_defaults = CTX->lookup_default_action_info;
    while ( my ( $action_item, $action_value ) =
                              each %{ $global_defaults } ) {
        next if ( exists $config->{ $action_item } );
        $config->{ $action_item } = $action_value;
    }
}

sub _action_security_level {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'action' );
    return unless ( ref $config->{security} eq 'HASH' );

    my $log = get_logger( LOG_INIT );
    $log->info( "Modifying verbose security for action '$config->{name}'" );
    foreach my $task ( keys %{ $config->{security} } ) {
        my $task_security = uc $config->{security}{ $task };
        if ( $task_security =~ /^(NONE|SUMMARY|READ|WRITE)$/i ) {
            $task_security =
                OpenInteract2::Util->verbose_to_level( uc $task_security );
        }
        $config->{security}{ $task } = int( $task_security );
    }
}


sub _action_cache_params {
    my ( $init, $type, $config ) = @_;
    return unless ( $type eq 'action' );
    return unless ( ref $config->{cache_param} eq 'HASH' );

    my $log = get_logger( LOG_INIT );
    $log->info( "Modifying cache params for action '$config->{name}'" );
    foreach my $task ( keys %{ $config->{cache_param} } ) {
        if ( ref $config->{cache_param}->{ $task } ne 'ARRAY' ) {
            $config->{cache_param}->{ $task } =
                ( $config->{cache_param}->{ $task } )
                  ? [ $config->{cache_param}->{ $task } ] : [];
        }

        # Task parameters are always in the same order...
        $config->{cache_param}->{ $task } =
            [ sort @{ $config->{cache_param}->{ $task } } ];
    }
}


__PACKAGE__->add_observer( \&_action_normalize_params );
__PACKAGE__->add_observer( \&_action_assign_defaults );
__PACKAGE__->add_observer( \&_action_security_level );
__PACKAGE__->add_observer( \&_action_cache_params );


########################################
# GENERIC STUFF

sub _normalize_list {
    my ( $config, $list_params ) = @_;
    foreach my $param ( @{ $list_params } ) {
        if ( ! $config->{ $param } ) {
            $config->{ $param } = [];
        }
        elsif ( ref $config->{ $param } ne 'ARRAY' ) {
            $config->{ $param } = [ $config->{ $param } ];
        }
    }
}

sub _normalize_hash {
    my ( $config, $hash_params ) = @_;
    foreach my $param ( @{ $hash_params } ) {
        if ( ! defined $config->{ $param } ) {
            $config->{ $param } = {};
        }
    }
}

1;

__END__

=head1 NAME

OpenInteract2::Config::Initializer - Observable configuration initialization events

=head1 SYNOPSIS

 # Add an initializer in your package.conf
 
 name    mypackage
 version 1.10
 ...
 config_watcher OpenInteract::MyInitializerSpops
 config_watcher OpenInteract::MyInitializerAction
 
 # And the code in our package -- we'll dynamically add a rule from
 # 'My::Googlable' to a class where 'is_googlable' is set to 'yes'
 
 package OpenInteract::MyInitializerSpops;
 
 use strict;
 
 sub update {
     my ( $class, $type, $config ) = @_;
     return unless ( $type eq 'spops' );

     if ( $config->{is_googlable} eq 'yes' ) {
         push @{ $config->{rules_from} }, 'My::Googable';
     }
 }
 
 # Here's we'll dynamically add a filter to an action where
 # 'is_googlable' is 'yes'
 
 package OpenInteract::MyInitializerAction;
 
 use strict;
 use OpenInteract2::Context qw( CTX );
 
 sub update {
     my ( $class, $type, $config ) = @_;
     return unless ( $type eq 'action' );

     if ( $config->{is_googlable} eq 'yes' ) {
         OpenInteract2::Filter->add_filter_to_action(
                              'google', $config->{class} );
     }
 }

=head1 DESCRIPTION

=head2 How it works

This class provides a hook for observers to react to individual
configuration events at server startup. The pseudocode for processing
action and SPOPS configurations looks like this:

 foreach package
    foreach config from package
        set core data
        do basic sanity checking
        trigger event

The event code can do whatever you like. This can be additional (but
boring) checks on the data, such as ensuring that certain parameters
are always arrayrefs, or always sorted in the same manner. This allows
your implementation code to assume that everything will always be
setup properly

More interesting you can provide concise hooks in your configuration
that get expanded at runtime to something more complex.

=head2 Built-in examples

For example, if you've read
L<OpenInteract2::Manual::SPOPS|OpenInteract2::Manual::SPOPS> you know
that OpenInteract 2.x allows you to declare security for an SPOPS
object with:

 is_secure = yes

In 1.x you had to add a class to the ISA.

Or to enable fulltext searching of your object you can just add to
your SPOPS configuration:

 is_searchable = yes

and list the fields you'd like indexed. These are both implemented
using this same event-based scheme.

What happens in the first case is that for every object that's tagged
with 'is_secure' we simply add L<SPOPS::Secure|SPOPS::Secure> to the
object's 'isa' field. And in the second case we add
L<OpenInteract2::FullText|OpenInteract2::FullText> to the 'isa'.

=head2 Why?

Everything (or nearly everything) you can do in the event can be done
in the configuration, so why bother? The primary reason is that it
makes for much more concise configuration files. More concise
configuration means you're less likely to mess it up and that you'll
hopefully be more willing to modify it when necessary rather than
throwing up your hands and hacking an ugly solution.

This is also done for the same reason that you create accessors
instead of allowing direct access to your object's data
structures. For instance, we may modify the full text indexing
implementation to require only an SPOPS ruleset rather than full
inheritance.

With the simple declaration we don't have to change B<any> of our
SPOPS configurations with the change. If we added the class directly
to the 'isa' people would have to change the configuration manually,
or we'd have to add a runtime hook to modify the 'isa' anyway.

=head1 OBSERVERS

This class also contains the default SPOPS and action configuration
observers.

=head2 SPOPS

These are the initialization handlers for SPOPS events.

=over 4

=item B<Security>

Configurations with 'is_secure' set to 'yes' get
L<SPOPS::Secure|SPOPS::Secure> added to the 'isa' key.

=item B<Creation Security>

Configurations with the 'creation_security' key set to hashref have
the 'group' key rewritten to accommodate the modifications from
C<CREATION SECURITY_CONVERSION> in
L<OpenInteract2::Manual::SPOPS|OpenInteract2::Manual::SPOPS>.

=item B<Date Conversion>

Configurations with one or more 'convert_date_field' entries get
L<SPOPS::Tool::DateConvert|SPOPS::Tool::DateConvert> added to the
'rules_from' key. Also issues a warning if 'convert_date_format' not
defined

=item B<Fulltext Searching>

Configurations with 'is_searchable' set get
L<OpenInteract2::FullText|OpenInteract2::FullText> added to 'isa' as
long as at least one field is listed in 'fulltext_field'.

=item B<Display Munging>

Configurations defining 'display' with 'ACTION' and 'TASK' keys get a
'url' key with the properly rewritten URL; those with both 'ACTION'
and 'TASK_EDIT' keys get a 'url_edit' key as well.

=item B<Field Discovery>

Configurations with 'field_discover' set to 'yes' get
L<SPOPS::Tool::DBI::DiscoverField|SPOPS::Tool::DBI::DiscoverField>
added to the 'rules_from' key.

=item B<DBI Class>

Configurations using a DBI datasource get L<SPOPS::DBI|SPOPS::DBI> and
the database-specific class (e.g.,
L<SPOPS::DBI::Sybase|SPOPS::DBI::Sybase>) added to 'isa'.

=item B<LDAP Class>

Configurations using a LDAP datasource get L<SPOPS::LDAP|SPOPS::LDAP>
added to 'isa'.

=back

=head2 Action

These are the handlers for action configuration events:

=over 4

=item B<Assign Action Defaults>

Read the hashref data from the 'action_info.default' server
configuration key and assign it to the configuration where the
configuration doesn't already have data defined.

=item B<Security Level Codes>

In the action configuration you can use verbose descriptions of
security levels like 'READ' and 'WRITE'. These get translated to the
codes exported by L<SPOPS::Secure|SPOPS::Secure>.

=item B<Caching Parameters>

If the 'cache_param' key is defined ensure that the internal
representation is an arrayref and the parameter names are always in
the same order.

=item B<Normalized Parameters>

This just ensures parameters that can have zero or more values are set
to empty arrayrefs (if none defined) or an arrayref with only one
value (if one defined). The parameters are: 'url_alt'

=back

=head1 METHODS

You should never be using this class directly. But just in case...

B<new()>

Creates a new object. (Doesn't hold anything right now.)

B<read_observers()>

Class method to read the configuration observers from the server
configuration and ask each package for its observers. These are
collected and added to the observer list for this class.

=head1 COPYRIGHT

Copyright (c) 2003 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
