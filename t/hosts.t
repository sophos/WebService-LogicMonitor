use v5.10.1;
use Test::Roo;
use lib 't/lib';

use Test::Fatal;
use Test::Deep;

with 'LogicMonitorTests';

has expected_keys => (
    is      => 'ro',
    default => sub {
        [
            qw/agentDescription agentId alertEnable autoPropsAssignedOn autoPropsUpdatedOn
              createdOn description deviceType displayedAs effectiveAlertEnabled enableNetflow
              fullPathInIds hostName id inSDT isActive lastdatatime lastrawdatatime link name
              netflowAgentId properties relatedDeviceId scanConfigId status type updatedOn/
        ];
    },
);

has instance_keys => (
    is      => 'ro',
    default => sub {
        [
            sort
              qw/alertEnable dataSourceDisplayedAs dataSourceId description discoveryInstanceId enabled hasAlert hasGraph hasUnConfirmedAlert hostDataSourceId hostId id name wildalias wildvalue wildvalue2/
        ];
    },
);

test 'one host' => sub {
    my $self = shift;

    like(
        exception { $self->lm->get_host; },
        qr/Missing displayname/,
        'Fails without a displayname',
    );

    my $host;
    is(
        exception { $host = $self->lm->get_host('mx-spam1'); },
        undef, 'Retrieved host',
    );

    isa_ok $host, 'HASH';
    is_deeply [sort keys %$host], $self->expected_keys;

};

test 'multiple hosts by group' => sub {
    my $self = shift;

    like(
        exception { $self->lm->get_hosts; },
        qr/Missing hostgroupid/,
        'Fails without a hostgroupid',
    );

    my $hosts;
    is(
        exception { $hosts = $self->lm->get_hosts(12); },
        undef, 'Retrieved host list',
    );

    isa_ok $hosts, 'ARRAY';

    my $hostgroup;
    is(
        exception { ($hosts, $hostgroup) = $self->lm->get_hosts(12); },
        undef, 'Retrieved host list',
    );

    isa_ok $hosts,     'ARRAY';
    isa_ok $hostgroup, 'HASH';
};

# XXX this takes a really long time
# test 'all hosts' => sub {
#     my $self = shift;

#     my $hosts;
#     is(
#         exception { $hosts = $self->lm->get_all_hosts; },
#         undef, 'Retrieved host list',
#     );

#     isa_ok $hosts, 'ARRAY';
# };

test 'get data source instances' => sub {
    my $self = shift;

    like(
        exception { $self->lm->get_data_source_instances; },
        qr/Missing host_id/,
        'Fails without a host_id',
    );

    like(
        exception { $self->lm->get_data_source_instances(12); },
        qr/Missing data_source_name/,
        'Fails without a data_source_name',
    );

    my $instances;
    is(
        exception {
            $instances = $self->lm->get_data_source_instances(12, 'Ping');
        },
        undef,
        'Retrieved instance list',
    );

    isa_ok $instances, 'ARRAY';
    is_deeply [sort keys %{$instances->[0]}], $self->instance_keys;
};

test 'update a host' => sub {
    my $self = shift;

    my $host;
    is(
        exception { $host = $self->lm->get_host('test1'); },
        undef, 'Retrieved host',
    );

    like(
        exception { $self->lm->update_host; },
        qr/Missing host_id/,
        'Fails without a host_id',
    );

    my $host2;
    is(
        exception {
            $host2 = $self->lm->update_host(
                $host->{id},
                opType        => 'replace',
                hostName      => $host->{hostName},
                displayedAs   => $host->{displayedAs},
                agentId       => $host->{agentId},
                fullPathInIds => $host->{fullPathInIds},

                #properties => { 'system.virtualization' => 'LXC' },
                properties => {'system.categories' => 'channelserver'},
            );
        },
        undef,
        'Updated hosts',
    );

    is(
        exception { $host2 = $self->lm->get_host('test1'); },
        undef, 'Retrieved host',
    );

    cmp_deeply $host, $host2, 'Old host and new host match';
};

run_me;
done_testing;
