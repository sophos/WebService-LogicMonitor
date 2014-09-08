package LogicMonitorTests;

use v5.10.1;
use Test::Roo::Role;

sub BUILD {

    if (!$ENV{LOGICMONITOR_USERNAME} || !$ENV{LOGICMONITOR_PASSWORD}) {
        plan skip_all => 'Set LOGICMONITOR_USERNAME and LOGICMONITOR_PASSWORD';
    }

    return;
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

1;
