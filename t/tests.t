use v5.10.1;
use Test::Roo;

sub BUILD {

    if (!$ENV{LOGICMONITOR_USERNAME} || !$ENV{LOGICMONITOR_PASSWORD}) {
        plan skip_all => 'Set LOGICMONITOR_USERNAME and LOGICMONITOR_PASSWORD';
    }

}

has lm => (is => 'lazy', clearer => 1);

sub _build_lm {
    my $self = shift;

    require_ok 'WebService::LogicMonitor';

    my $obj = new_ok 'WebService::LogicMonitor' => [
        lm_username => $ENV{LOGICMONITOR_USERNAME},
        lm_password => $ENV{LOGICMONITOR_PASSWORD},
    ];

    return $obj;
}

after each_test => sub { shift->clear_lm };

test accounts => sub {
    my $self = shift;

    # TODO use Test::Deep
    my $expected_keys = [
        qw/contactMethod createBy email forcePasswordChange id lastLoginOn
          note password phone priv roles smsEmailFormat smsemail status username viewMessageOn
          viewPermission/
    ];

    ok my $accounts = $self->lm->get_accounts;
    isa_ok $accounts, 'ARRAY';

    my $account1 = shift @$accounts;
    isa_ok $account1, 'HASH';
    is_deeply [sort keys %$account1], $expected_keys;
    is $account1->{id},       1;
    is $account1->{username}, 'admin';

    ok my $account = $self->lm->get_account_by_email('ioan.rogers@sophos.com');
    isa_ok $account, 'HASH';
    is_deeply [sort keys %$account], $expected_keys;
    is $account->{id},       30;
    is $account->{username}, 'ioanrogers';
};

test 'escalation chains' => sub {
    my $self = shift;

    my $expected_keys = [
        qw/ccdestination description destination enableThrottling id
          inAlerting name throttlingAlerts throttlingPeriod/
    ];

    ok my $chains = $self->lm->get_escalation_chains;
    isa_ok $chains, 'ARRAY';
    my $chain1 = shift @$chains;
    isa_ok $chain1, 'HASH';
    is_deeply [sort keys %$chain1], $expected_keys;

    ok my $chain = $self->lm->get_escalation_chain_by_name('ioan-test-chain');
    isa_ok $chain, 'HASH';
    is_deeply [sort keys %$chain], $expected_keys;
    is $chain->{name}, 'ioan-test-chain';

    my $cur_time = time;
    $chain->{description} = "API Testing [$cur_time]";
    $self->lm->update_escalation_chain($chain);

    ok my $chain2 = $self->lm->get_escalation_chain_by_name('ioan-test-chain');
    is $chain2->{description}, "API Testing [$cur_time]";

};

run_me;
done_testing;
