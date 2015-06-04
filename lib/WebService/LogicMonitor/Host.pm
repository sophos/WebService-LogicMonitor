package WebService::LogicMonitor::Host;

# ABSTRACT: A LogicMonitor Host/Device object

use v5.16.3;
use DateTime;
use Log::Any '$log';
use Moo;

extends 'WebService::LogicMonitor::Entity';

with 'WebService::LogicMonitor::Object';

sub BUILDARGS {
    my ($class, $args) = @_;

    my %transform = (
        agentDescription      => 'agent_description',
        agentId               => 'agent_id',
        alertEnable           => 'alert_enable',
        effectiveAlertEnabled => 'effective_alert_enabled',
        deviceType            => 'device_type',
        hostName              => 'host_name',
        inSDT                 => 'in_sdt',
        isActive              => 'is_active',
        enableNetflow         => 'enable_netflow',
        netflowAgentId        => 'netflow_agent_id',
        relatedDeviceId       => 'related_device_id',
        scanConfigId          => 'scan_config_id',
        displayedAs           => 'displayed_as',
        updatedOn             => 'updated_on',
        createdOn             => 'created_on',
        fullPathInIds         => 'full_path_in_ids',
        autoPropsAssignedOn   => 'auto_props_assigned_on',
    );

    _transform_incoming_keys(\%transform, $args);
    _clean_empty_keys([qw/description link/], $args);

    return $args;
}

# host_name is the ip_address/DNS name
has [qw/host_name displayed_as/] => (is => 'rw', required  => 1);    # str
has [qw/agent_description/]      => (is => 'rw', predicate => 1);    # str

has device_type => (is => 'ro');                                     # str
has agent_id => (is => 'rw', required => 1);                         # int

has link => (is => 'rw', predicate => 1);    # str - url

has status => (is => 'ro');                  # enum dead|

has [qw/lastdatatime lastrawdatatime/] => (is => 'ro');
has enable_netflow => (is => 'rw', predicate => 1);    # bool
has [qw/netflow_agent_id related_device_id scan_config_id/] => (is => 'ro')
  ;                                                    # int
has [qw/effective_alert_enabled is_active /] => (is => 'ro');    # bool

has [qw/updated_on auto_props_assigned_on/] => (
    is     => 'ro',
    coerce => sub {
        DateTime->from_epoch(epoch => $_[0]);
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

=attr C<datasource_instances>

A cache of any datasource instances that are retrieved.

=cut

has datasource_instances => (is => 'ro', lazy => 1, default => sub {{}});

=method C<update>

Commit this host to LogicMonitor.

L<http://help.logicmonitor.com/developers-guide/manage-hosts/#update>

=cut

sub update {
    my $self = shift;

    if (!$self->has_id) {
        die
          'This host does not have an id - you cannot update an object that has not been created';
    }

    # first, get the required params
    my $params = {
        id            => $self->id,
        opType        => 'refresh',
        hostName      => $self->host_name,
        displayedAs   => $self->displayed_as,
        agentId       => $self->agent_id,
        alertEnable   => $self->alert_enable,
        enableNetflow => $self->enable_netflow,
    };

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
        my $hg = $self->_lm->get_groups(id => $hg_id);
        next if $hg->[0]->{appliesTo};
        push @hostgroup_ids, $hg_id;
    }

    $params->{hostGroupIds} = join ',', @hostgroup_ids;

    $self->_lm->_send_data('updateHost', $params);
    return;
}

=method C<get_data_source_instances(Str datasource_name)>

Return an array of instances of a datasource on this host. The array will also
be cached in L</datasource_instances>.

LogicMonitor's API does not list the datasources which actually apply to a host,
or even which datasources are available on your account, so you must know in
advance which datasource you want to retrieve.

L<http://help.logicmonitor.com/developers-guide/manage-hosts/#instances>

=cut

sub get_datasource_instances {
    my ($self, $ds_name) = @_;
    require WebService::LogicMonitor::DataSourceInstance;
    die 'Missing datasource name' unless $ds_name;

    $log->debug("Fetching datasource instances for $ds_name");
    my $data = $self->_lm->_get_data(
        'getDataSourceInstances',
        hostId     => $self->id,
        dataSource => $ds_name,
    );

    die 'Found datasource but no items were returned' unless scalar @$data;

    my @ds_instances;
    for (@$data) {
        $_->{_lm}       = $self->_lm;
        $_->{host_name} = $self->name;
        push @ds_instances,
          WebService::LogicMonitor::DataSourceInstance->new($_);
    }

    $self->datasource_instances->{$ds_name} = \@ds_instances;
    return \@ds_instances;
}

sub get_alerts {
    my $self = shift;
    return $self->_lm->get_alerts(
        host_id => $self->id,
        @_,
    );
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
