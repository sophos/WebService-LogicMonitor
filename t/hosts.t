use v5.10.1;
use Test::Roo;
use lib 't/lib';

use Test::Fatal;

with 'LogicMonitorTests';

has expected_keys => (
    is      => 'ro',
    default => sub {
        [
            qw/agentDescription agentId alertEnable autoPropsAssignedOn autoPropsUpdatedOn
              createdOn description deviceType displayedAs effectiveAlertEnabled enableNetflow
              fullPathInIds hostName id inSDT isActive lastdatatime lastrawdatatime link name
              netflowAgentId properties scanConfigId status type updatedOn/
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

run_me;
done_testing;
