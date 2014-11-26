use v5.10.1;
use Test::Roo;
use lib 't/lib';

with 'LogicMonitorTests';

test accounts => sub {
    my $self = shift;

    # TODO use Test::Deep
    my @expected_keys = sort
      qw/contactMethod createBy email firstName forcePasswordChange id lastLoginOn lastName
      note password phone priv roles smsEmailFormat smsemail status username viewMessageOn
      viewPermission/;

    ok my $accounts = $self->lm->get_accounts;
    isa_ok $accounts, 'ARRAY';

    my $account1 = shift @$accounts;
    isa_ok $account1, 'HASH';
    is_deeply [sort keys %$account1], \@expected_keys;
    is $account1->{id},       1;
    is $account1->{username}, 'admin';

    ok my $account = $self->lm->get_account_by_email('ioan.rogers@sophos.com');
    isa_ok $account, 'HASH';
    is_deeply [sort keys %$account], \@expected_keys;
    is $account->{id},       30;
    is $account->{username}, 'ioanrogers';
};

run_me;
done_testing;
