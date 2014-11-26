package LogicMonitorTests;

use v5.10.1;
use Test::Roo::Role;

sub BUILD {

    if (   !$ENV{LOGICMONITOR_USER}
        || !$ENV{LOGICMONITOR_PASS}
        || !$ENV{LOGICMONITOR_COMPANY})
    {
        plan skip_all =>
          'LOGICMONITOR_USER, LOGICMONITOR_PASS and LOGICMONITOR_COMPANY environment variables must be set';
    }

    return;
}

has lm => (is => 'lazy', clearer => 1);

sub _build_lm {
    my $self = shift;

    require_ok 'WebService::LogicMonitor';

    my $obj = new_ok 'WebService::LogicMonitor' => [
        lm_username => $ENV{LOGICMONITOR_USER},
        lm_password => $ENV{LOGICMONITOR_PASS},
        lm_company  => $ENV{LOGICMONITOR_COMPANY},
    ];

    return $obj;
}

after each_test => sub { shift->clear_lm };

1;
