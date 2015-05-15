use v5.10.1;
use Test::Roo;
use lib 't/lib';

use Test::Fatal;
use Test::Deep;

with 'LogicMonitorTests';

has group_basic_keys => (
    is      => 'ro',
    default => sub {
        [
            sort
              qw/alertEnable appliesTo createdOn description fullPath groupType id name parentId/
        ];
    },
);

has group_detailed_keys => (
    is      => 'ro',
    default => sub {
        [
            sort
              qw/effectiveAlertEnabled inNSP inSDT numOfHosts signaled status type/,
            @{$_[0]->group_basic_keys}];
    },
);

test 'get all host groups' => sub {
    my $self = shift;

    my $hosts;
    is(
        exception { $hosts = $self->lm->get_host_groups; },
        undef, 'Retrieved host groups',
    );

    isa_ok $hosts, 'ARRAY';
    is_deeply [sort keys %{$hosts->[0]}], $self->group_basic_keys;
    my $num_hosts = scalar @$hosts;

    is(
        exception { $hosts = $self->lm->get_host_groups('name', 'Testing'); },
        undef,
        'Retrieved host groups',
    );

    isa_ok $hosts, 'ARRAY';
    ok scalar @$hosts < $num_hosts,
      'The filtered array is smaller than all hosts';
    is_deeply [sort keys %{$hosts->[0]}], $self->group_basic_keys;
};

test 'get child host groups' => sub {
    my $self = shift;

    like(
        exception { $self->lm->get_host_group_children; },
        qr/Missing hostgroupid/,
        'Failed without hostgroupid',
    );

    my $hosts;
    is(
        exception { $hosts = $self->lm->get_host_group_children(2); },
        undef, 'Retrieved host group children',
    );

    isa_ok $hosts, 'ARRAY';
    is_deeply [sort keys %{$hosts->[0]}], $self->group_detailed_keys;

    $hosts = undef;

    my $group;
    is(
        exception { ($hosts, $group) = $self->lm->get_host_group_children(2); }
        ,
        undef,
        'Retrieved host group children',
    );

    isa_ok $hosts, 'ARRAY';
    is_deeply [sort keys %{$hosts->[0]}], $self->group_detailed_keys;

    isa_ok $group, 'HASH';
    is_deeply [sort keys %$group], $self->group_detailed_keys;

};

test 'get host group details' => sub {
    my $self = shift;

    like(
        exception { $self->lm->get_host_group; },
        qr/Missing hostgroupid/,
        'Fails without a hostgroupid',
    );

    my $host_group;
    is(
        exception { $host_group = $self->lm->get_host_group(10) },
        undef, 'Retrieved host group details',
    );

    isa_ok $host_group, 'HASH';
    my @expected_keys = @{$self->group_basic_keys};
    push @expected_keys, 'properties';
    is_deeply [sort keys %$host_group], \@expected_keys;
};

test 'update host group' => sub {
    my $self = shift;

    like(
        exception { $self->lm->update_host_group; },
        qr/Missing hostgroupid/,
        'Fails without a hostgroupid',
    );

    my ($groups, $group);
    is(
        exception { $groups = $self->lm->get_host_groups('Testing'); },
        undef, 'Retrieved host groups',
    );

    like(
        exception { $self->lm->update_host_group($groups->[0]->{id}) },
        qr/Missing name/,
        'Fails without a name',
    );

    is(
        exception { $group = $self->lm->get_host_group($groups->[0]->{id}) },
        undef, 'Retrieved host group details',
    );

    ok !exists $group->{properties}->{testproperty},
      'testproperty does not exist';

    my $updated_group;
    is(
        exception {
            $updated_group = $self->lm->update_host_group(
                $group->{id},
                opType      => 'add',
                name        => $group->{name},
                description => $group->{description},
                alertEnable => $group->{alertEnable},
                properties  => {testproperty => 'blah'},
            );
        },
        undef,
        'Updated host group',
    );

    is(
        exception {
            $updated_group = $self->lm->get_host_group($groups->[0]->{id})
        },
        undef,
        'Retrieved host group details',
    );

    ok !eq_deeply($group, $updated_group),
      'Old group and new group do not match';

    # remove a property
    my $properties = $updated_group->{properties};
    delete $properties->{testproperty};

    is(
        exception {
            $updated_group = $self->lm->update_host_group(
                $group->{id},
                name        => $group->{name},
                description => $group->{description},
                alertEnable => $group->{alertEnable},
                properties  => $properties,
            );
        },
        undef,
        'Refreshed properties',
    );

    is(
        exception {
            $updated_group = $self->lm->get_host_group($groups->[0]->{id})
        },
        undef,
        'Retrieved host group details',
    );

    cmp_deeply $group, $updated_group, 'Old group and new group match';
};

run_me;
done_testing;
