package WebService::LogicMonitor::Host;

# ABSTRACT: A LogicMonitor Host/Device object

use v5.16.3;
use DateTime;
use Log::Any '$log';
use Moo;

with 'WebService::LogicMonitor::Object';

sub BUILDARGS {
    my ($class, $args) = @_;

    my %transform = (
        agentDescription      => 'agent_description',
        agentId               => 'agent_id',
        alertEnable           => 'alert_enable',
        effectiveAlertEnabled => 'effective_alert_enabled',
        hostName              => 'host_name',
        inSDT                 => 'in_sdt',
        isActive              => 'is_active',
        enableNetflow         => 'enable_netflow',
        displayedAs           => 'displayed_as',
        updatedOn             => 'updated_on',
        createdOn             => 'created_on',
        fullPathInIds         => 'full_path_in_ids',
        autoPropsAssignedOn   => 'auto_props_assigned_on',
    );

    for my $key (keys %transform) {
        $args->{$transform{$key}} = delete $args->{$key} if $args->{$key};
    }

    for my $k (qw/description link/) {
        if (exists $args->{$k} && !$args->{$k}) {
            delete $args->{$k};
        }
    }

    return $args;
}

has id => (is => 'ro', predicate => 1);    # int

# host_name is the ip_address/DNS name
has [qw/host_name displayed_as/] => (is => 'rw', required => 1);    # str
has [qw/agent_description description name/] => (is => 'rw', predicate => 1)
  ;                                                                 # str

has agent_id => (is => 'rw', required => 1);                        # int

has link => (is => 'rw', predicate => 1);                           # str - url

has status => (is => 'ro');    # enum dead|
has type   => (is => 'ro');    # enum HOST|

has [qw/alert_enable enable_netflow/] => (is => 'rw', predicate => 1);   # bool

has [qw/effective_alert_enabled in_sdt is_active /] => (is => 'ro');     # bool

has [qw/updated_on created_on auto_props_assigned_on/] => (
    is     => 'ro',
    coerce => sub {
        DateTime->from_epoch(epoch => $_[0]);
    },
);

has properties => (
    is  => 'rw',
    isa => sub {
        unless (ref $_[0] && ref $_[0] eq 'HASH') {
            die 'properties should be specified as a hashref';
        }
    },
);

has full_path_in_ids => (
    is  => 'rw',
    isa => sub {
        unless (ref $_[0] && ref $_[0] eq 'ARRAY') {
            die 'full_path_in_ids should be specified as a arrayref';
        }
    },
);

=method C<update_host(Int host_id)>

Update a host identified by C<$host_id>.

L<http://help.logicmonitor.com/developers-guide/manage-hosts/#update>

=cut

# hostName
# displayedAs
# id
# agentId

# description
# alertEnable
# link
# enableNetflow
# netflowAgentId  string  Required if Netflow is enabled
# opType  String  (Optional) add|replace|refresh (default)

# hostGroupIds

sub update {
    my $self = shift;

    if (!$self->has_id) {
        die
          'This host does not have an id - you cannot update an object that has not been created';
    }

    # first, get the required params
    my $params = {
        id          => $self->id,
        opType      => 'refresh',
        hostName    => $self->host_name,
        displayedAs => $self->displayed_as,
        agentId     => $self->agent_id,
    };

    my @optional_params = qw/description alert_enable link enable_netflow/;
    for my $param (@optional_params) {
        my $meth = "has_$param";
        if (!$self->$meth) {
            $log->warning("Missing param [$param] may be reset to defaults");
        } else {
            $params->{$param} = $self->$param;
        }

    }

    my %transform = (
        alert_enable   => 'alertEnable',
        enable_netflow => 'enableNetflow',
    );

    for my $k (keys %transform) {
        $params->{$transform{$k}} = delete $params->{$k} if $params->{$k};
    }

    # then get properties because they need to be formatted
    my $properties = $self->properties;

    if ($properties) {
        my $i = 0;
        while (my ($k, $v) = each %$properties) {
            $params->{"propName$i"}  = $k;
            $params->{"propValue$i"} = $v;
            $i++;
        }
    }

    # convert fullPathInIds to hostGroupIds
    # TODO allow user to set hostGroupIds

    my @hostgroup_ids;

    # TODO pinch from properties.system.groups?
    foreach my $full_path (@{$self->full_path_in_ids}) {
        my $hg_id = $full_path->[-1];

        # filter out any autogroups
        my $hg = $self->_lm->get_host_group($hg_id);
        next if $hg->{appliesTo};
        push @hostgroup_ids, $hg_id;
    }

    $params->{hostGroupIds} = join ',', @hostgroup_ids;

    use Data::Printer;
    p $params;

    return $self->_lm->_send_data('updateHost', $params);
}

#     autoPropsAssignedOn     0,
#     autoPropsUpdatedOn      1432687969,
#     deviceType              0,
#     enableNetflow           JSON::PP::Boolean  {
#         public methods (0)
#         private methods (1) : __ANON__
#         internals: 0
#     },
#     fullPathInIds           [
#         [0] [
#             [0] 12
#         ]
#     ],
#     lastdatatime            0,
#     lastrawdatatime         0,
#     link                    "",
#     netflowAgentId          0,
#     properties              {
#         esx.pass                "********",
#         esx.user                "root",
#         jdbc.mysql.pass         "********",
#         jdbc.mysql.user         "logicmonitor",
#         snmp.community          "********",
#         snmp.version            "v2c",
#         system.categories       "snmp,snmpTCPUDP,Netsnmp,snmpHR",
#         system.db.db2           "",
#         system.db.mssql         "",
#         system.db.mysql         "",
#         system.db.oracle        "",
#         system.description      "",
#         system.devicetype       0,
#         system.displayname      "mx-spam1",
#         system.enablenetflow    "false",
#         system.groups           "Vancouver",
#         system.hostname         "mx-spam1",
#         system.ips              "10.99.159.111",
#         system.sysinfo          "Linux mx-spam1 3.10.17-gentoo #1 SMP Tue Nov 5 00:19:02 UTC 2013 x86_64",
#         system.sysoid           "1.3.6.1.4.1.8072.3.2.10",
#         system.virtualization   ""
#     },
#     relatedDeviceId         -1,
#     scanConfigId            0,

1;
